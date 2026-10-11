//
//  ApplyService.swift
//  Scope
//
//  Generate -> validate -> write atomically -> ensure startup hook.
//  See "Apply configuration" in Design/04_UX_Flows.md. Nothing is written
//  unless validation passes.
//

import Foundation
import OSLog

nonisolated struct ConfigurationPreview: Equatable, Sendable {
    /// The text that would be written. Nil if the configuration could not be generated.
    var text: String?
    /// Why `text` is nil, or why the configuration can't be applied.
    var blockers: [String] = []
    var syntax: SyntaxCheckResult?
    /// True when `text` differs from the generated file currently on disk.
    var hasPendingChanges = false
    var hookState: StartupHook.State?

    var canApply: Bool { text != nil && blockers.isEmpty && syntax == .valid }
}

nonisolated struct ApplyOutcome: Equatable, Sendable {
    /// False when the generated file already had this exact content.
    var wroteGeneratedFile: Bool
    /// Set when the startup file was changed (and it existed, so it was backed up).
    var installedHook: Bool
    var hookBackup: BackupRecord?
}

nonisolated enum ApplyError: Error, Equatable {
    case blocked([String])
    case syntaxInvalid([SyntaxDiagnostic])
    case validatorUnavailable(String)
    /// The generated file was written but the startup file could not be updated.
    case hookFailed(String)
}

nonisolated struct ApplyService: Sendable {
    var fileSystem: any FileSystem
    var paths: ScopePaths
    var validator: ShellSyntaxValidator
    var hookManager: StartupHookManager

    private static let logger = Logger(subsystem: "com.scope.Scope", category: "Apply")

    init(fileSystem: any FileSystem, paths: ScopePaths, processRunner: any ProcessRunner) {
        self.fileSystem = fileSystem
        self.paths = paths
        self.validator = ShellSyntaxValidator(fileSystem: fileSystem, processRunner: processRunner)
        self.hookManager = StartupHookManager(fileSystem: fileSystem, paths: paths)
    }

    func preview(_ config: EffectiveConfiguration) async -> ConfigurationPreview {
        var preview = ConfigurationPreview()
        preview.hookState = try? hookManager.state(of: paths.zshrc)

        let errors = config.issues.filter { $0.severity == .error }.map(\.message)
        do {
            let text = try ZshGenerator.generate(config)
            preview.text = text
            preview.hasPendingChanges = (try? fileSystem.read(paths.generatedFile)) != Data(text.utf8)
            if errors.isEmpty {
                preview.syntax = try? await validator.validate(text)
            }
        } catch {
            preview.blockers.append(String(localized: "Some values can't be written safely: \(error.localizedDescription)"))
        }
        preview.blockers += errors
        return preview
    }

    @discardableResult
    func apply(_ config: EffectiveConfiguration) async throws -> ApplyOutcome {
        let errors = config.issues.filter { $0.severity == .error }.map(\.message)
        guard errors.isEmpty else { throw ApplyError.blocked(errors) }

        let text: String
        do {
            text = try ZshGenerator.generate(config)
        } catch {
            throw ApplyError.blocked([error.localizedDescription])
        }

        do {
            if case .invalid(let diagnostics) = try await validator.validate(text) {
                throw ApplyError.syntaxInvalid(diagnostics)
            }
        } catch let error as ApplyError {
            throw error
        } catch {
            // Can't prove the file is valid, so don't write it.
            throw ApplyError.validatorUnavailable(error.localizedDescription)
        }

        let wrote = try GeneratedFileWriter(fileSystem: fileSystem, paths: paths).write(text)

        do {
            let wasInstalled = (try? hookManager.state(of: paths.zshrc)) == .installed
            let backup = try hookManager.install(into: paths.zshrc)
            Self.logger.info("Applied configuration (file changed: \(wrote, privacy: .public))")
            return ApplyOutcome(wroteGeneratedFile: wrote, installedHook: !wasInstalled, hookBackup: backup)
        } catch {
            throw ApplyError.hookFailed(Self.hookMessage(for: error))
        }
    }

    private static func hookMessage(for error: any Error) -> String {
        switch error as? StartupHookError {
        case .malformedMarkers:
            String(localized: "Your .zshrc has unbalanced Scope markers, so it was left untouched. Fix or remove them and apply again.")
        case .notUTF8:
            String(localized: "Your .zshrc isn't valid UTF-8, so it was left untouched.")
        case nil:
            error.localizedDescription
        }
    }
}
