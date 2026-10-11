//
//  DiagnosticsService.swift
//  Scope
//
//  Answers "Why isn't this working?" (Design/03). Read-only: it inspects files and
//  runs `zsh -n` / `zsh --version`, and never changes anything or logs config values.
//

import Foundation

nonisolated struct DiagnosticCheck: Identifiable, Equatable, Sendable {
    enum Section: String, CaseIterable, Sendable {
        case shell, files, configuration

        var title: LocalizedStringResource {
            switch self {
            case .shell: "Shell"
            case .files: "Scope Files"
            case .configuration: "Configuration"
            }
        }
    }

    /// Ordered so the worst result sorts highest.
    enum Severity: Int, Comparable, Sendable {
        case ok, info, warning, error
        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }

    var id: String
    var section: Section
    var severity: Severity
    var title: String
    var detail: String?
    /// What the user can do about it.
    var suggestion: String?
}

nonisolated struct DiagnosticsService: Sendable {
    var fileSystem: any FileSystem
    var paths: ScopePaths
    var processRunner: any ProcessRunner
    var pathInspector: PathInspector
    /// The user's login shell, e.g. `/bin/zsh`.
    var loginShell: String? = ProcessInfo.processInfo.environment["SHELL"]
    /// Directories searched when deciding whether an alias shadows a command.
    var commandDirectories = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]

    static let startupFileNames = [".zshenv", ".zprofile", ".zshrc", ".zlogin"]

    init(fileSystem: any FileSystem, paths: ScopePaths, processRunner: any ProcessRunner) {
        self.fileSystem = fileSystem
        self.paths = paths
        self.processRunner = processRunner
        self.pathInspector = PathInspector(fileSystem: fileSystem, home: paths.home)
    }

    func run(_ config: EffectiveConfiguration) async -> [DiagnosticCheck] {
        var checks = await shellChecks()
        checks += await fileChecks(config)
        checks += configurationChecks(config)
        return checks
    }

    // MARK: - Shell

    private func shellChecks() async -> [DiagnosticCheck] {
        var checks: [DiagnosticCheck] = []

        if let loginShell, loginShell.hasSuffix("/zsh") {
            checks.append(.init(id: "login-shell", section: .shell, severity: .ok, title: "Login shell is zsh", detail: loginShell))
        } else {
            checks.append(.init(
                id: "login-shell", section: .shell, severity: .warning,
                title: "Login shell isn't zsh", detail: loginShell,
                suggestion: "Scope only supports zsh. Terminals running another shell won't load its file."
            ))
        }

        if let result = try? await processRunner.run(executable: URL(filePath: "/bin/zsh"), arguments: ["--version"], timeout: .seconds(5)),
           result.exitCode == 0 {
            checks.append(.init(id: "zsh-version", section: .shell, severity: .ok, title: "zsh is available",
                                detail: result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)))
        } else {
            checks.append(.init(id: "zsh-version", section: .shell, severity: .error, title: "Can't run /bin/zsh",
                                suggestion: "Scope needs zsh to check generated files before applying them."))
        }

        let present = Self.startupFileNames.filter { fileSystem.fileExists(at: paths.home.appending(path: $0, directoryHint: .notDirectory)) }
        checks.append(.init(
            id: "startup-chain", section: .shell, severity: .info,
            title: "Startup files found",
            detail: present.isEmpty ? "None" : present.joined(separator: ", "),
            suggestion: "zsh reads these in order: .zshenv, .zprofile, .zshrc, .zlogin. Scope hooks into .zshrc, which interactive terminals read."
        ))
        return checks
    }

    // MARK: - Files

    private func fileChecks(_ config: EffectiveConfiguration) async -> [DiagnosticCheck] {
        var checks: [DiagnosticCheck] = []
        let generatedPath = paths.generatedFile.path(percentEncoded: false)

        let onDisk = try? fileSystem.read(paths.generatedFile)
        let expected = try? ZshGenerator.generate(config)

        if let onDisk {
            checks.append(.init(id: "generated-exists", section: .files, severity: .ok, title: "Generated file exists", detail: generatedPath))
            if let expected, Data(expected.utf8) != onDisk {
                checks.append(.init(
                    id: "generated-stale", section: .files, severity: .warning,
                    title: "Generated file is out of date",
                    suggestion: "Your shell is using an older configuration. Apply from Generated Config."
                ))
            } else if expected != nil {
                checks.append(.init(id: "generated-stale", section: .files, severity: .ok, title: "Generated file matches your configuration"))
            }
            if let text = String(data: onDisk, encoding: .utf8) {
                checks.append(await syntaxCheck(of: text))
            }
        } else {
            checks.append(.init(
                id: "generated-exists", section: .files, severity: .warning,
                title: "Generated file doesn't exist yet", detail: generatedPath,
                suggestion: "Nothing is loaded by your shell until you apply."
            ))
        }

        checks.append(hookCheck())
        return checks
    }

    private func syntaxCheck(of text: String) async -> DiagnosticCheck {
        let validator = ShellSyntaxValidator(fileSystem: fileSystem, processRunner: processRunner)
        switch try? await validator.validate(text) {
        case .valid:
            return .init(id: "generated-syntax", section: .files, severity: .ok, title: "Generated file has valid syntax")
        case .invalid(let diagnostics):
            let detail = diagnostics.map { d in d.line.map { "Line \($0): \(d.message)" } ?? d.message }.joined(separator: "\n")
            return .init(id: "generated-syntax", section: .files, severity: .error,
                         title: "Generated file has a syntax error", detail: detail,
                         suggestion: "Your shell will report errors on startup. Fix the item and apply again.")
        case nil:
            return .init(id: "generated-syntax", section: .files, severity: .warning, title: "Couldn't check the generated file's syntax")
        }
    }

    private func hookCheck() -> DiagnosticCheck {
        let zshrc = paths.zshrc.path(percentEncoded: false)
        let manager = StartupHookManager(fileSystem: fileSystem, paths: paths)
        do {
            if try manager.state(of: paths.zshrc) == .installed {
                return .init(id: "hook", section: .files, severity: .ok, title: "Your .zshrc loads Scope's file", detail: zshrc)
            }
            return .init(id: "hook", section: .files, severity: .warning,
                         title: "Your .zshrc doesn't load Scope's file", detail: zshrc,
                         suggestion: "Apply adds a marked line to your .zshrc, after making a backup.")
        } catch StartupHookError.malformedMarkers {
            return .init(id: "hook", section: .files, severity: .error,
                         title: "Scope's markers in .zshrc are unbalanced", detail: zshrc,
                         suggestion: "Make sure there is exactly one “# >>> Scope >>>” and one “# <<< Scope <<<” line, in that order, or delete both.")
        } catch {
            return .init(id: "hook", section: .files, severity: .error, title: "Couldn't read your .zshrc", detail: error.localizedDescription)
        }
    }

    // MARK: - Configuration

    private func configurationChecks(_ config: EffectiveConfiguration) -> [DiagnosticCheck] {
        var checks: [DiagnosticCheck] = []

        for issue in config.issues {
            checks.append(.init(
                id: "issue-\(issue.itemID?.uuidString ?? issue.message)", section: .configuration,
                severity: issue.severity == .error ? .error : .warning, title: issue.message
            ))
        }

        let missing = config.path.filter { pathInspector.status(of: $0.rawPath) == .missing }.map(\.rawPath)
        if !missing.isEmpty {
            checks.append(.init(
                id: "path-missing", section: .configuration, severity: .warning,
                title: "\(missing.count) PATH \(missing.count == 1 ? "directory doesn't" : "directories don't") exist",
                detail: missing.joined(separator: "\n"),
                suggestion: "Your shell ignores missing entries. Remove them, or disable them if they only exist on another Mac."
            ))
        }

        let duplicates = Dictionary(grouping: config.path, by: { pathInspector.expand($0.rawPath) ?? $0.rawPath })
            .filter { $0.value.count > 1 }.keys.sorted()
        if !duplicates.isEmpty {
            checks.append(.init(
                id: "path-duplicates", section: .configuration, severity: .info,
                title: "Different spellings of the same PATH directory",
                detail: duplicates.joined(separator: "\n"),
                suggestion: "Only the first occurrence has any effect."
            ))
        }

        let overridden = config.environment.filter { $0.overrideCount > 0 }.map(\.item.name)
        if !overridden.isEmpty {
            checks.append(.init(
                id: "env-overridden", section: .configuration, severity: .info,
                title: "\(overridden.count) \(overridden.count == 1 ? "variable is" : "variables are") overridden by a more specific scope",
                detail: overridden.joined(separator: ", ")
            ))
        }

        let aliasNames = Set(config.aliases.map(\.item.name))
        let conflicts = config.functions.map(\.item.name).filter(aliasNames.contains)
        if !conflicts.isEmpty {
            checks.append(.init(
                id: "alias-function-conflict", section: .configuration, severity: .error,
                title: "A function has the same name as an alias",
                detail: conflicts.joined(separator: ", "),
                suggestion: "zsh refuses to define a function whose name is already an alias. Rename or disable one."
            ))
        }

        let shadowing = config.aliases.map(\.item.name).filter { name in
            commandDirectories.contains { fileSystem.fileExists(at: URL(filePath: $0).appending(path: name, directoryHint: .notDirectory)) }
        }
        if !shadowing.isEmpty {
            checks.append(.init(
                id: "alias-shadowing", section: .configuration, severity: .info,
                title: "\(shadowing.count) \(shadowing.count == 1 ? "alias hides" : "aliases hide") an existing command",
                detail: shadowing.joined(separator: ", "),
                suggestion: "This is often intentional. Use `command name` to run the original."
            ))
        }

        if !checks.contains(where: { $0.severity >= .warning }) {
            checks.append(.init(id: "config-ok", section: .configuration, severity: .ok, title: "No problems found in your configuration"))
        }
        return checks
    }
}
