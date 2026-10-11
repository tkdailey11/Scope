import Foundation
import Testing
@testable import Scope

struct DiagnosticsTests {
    let home: URL
    let paths: ScopePaths

    init() throws {
        home = FileManager.default.temporaryDirectory.appending(path: "scope-diag-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        paths = ScopePaths(home: home)
    }

    private func service() -> DiagnosticsService {
        var service = DiagnosticsService(fileSystem: LocalFileSystem(), paths: paths, processRunner: SystemProcessRunner())
        service.loginShell = "/bin/zsh"
        service.commandDirectories = ["/bin"]
        return service
    }

    private func config(_ snapshot: ConfigurationSnapshot) -> EffectiveConfiguration {
        ConfigurationComposer.compose(snapshot, activeProfileID: nil, machineID: nil)
    }

    private func check(_ id: String, in checks: [DiagnosticCheck]) -> DiagnosticCheck? {
        checks.first { $0.id == id }
    }

    @Test func freshMachineWarnsAboutMissingFileAndHook() async {
        defer { try? FileManager.default.removeItem(at: home) }
        let checks = await service().run(config(.init()))
        #expect(check("generated-exists", in: checks)?.severity == .warning)
        #expect(check("hook", in: checks)?.severity == .warning)
        #expect(check("login-shell", in: checks)?.severity == .ok)
    }

    @Test func appliedConfigurationIsAllClear() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let effective = config(.init(environment: [.init(name: "A", value: "1")]))
        try await ApplyService(fileSystem: LocalFileSystem(), paths: paths, processRunner: SystemProcessRunner()).apply(effective)
        let checks = await service().run(effective)
        #expect(checks.allSatisfy { $0.severity < .warning })
        #expect(check("generated-stale", in: checks)?.severity == .ok)
    }

    @Test func staleGeneratedFileIsFlagged() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try await ApplyService(fileSystem: LocalFileSystem(), paths: paths, processRunner: SystemProcessRunner())
            .apply(config(.init(environment: [.init(name: "A", value: "1")])))
        let checks = await service().run(config(.init(environment: [.init(name: "A", value: "2")])))
        #expect(check("generated-stale", in: checks)?.severity == .warning)
    }

    @Test func brokenGeneratedFileAndMarkersAreErrors() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: paths.scopeDirectory, withIntermediateDirectories: true)
        try "foo() {\n".write(to: paths.generatedFile, atomically: true, encoding: .utf8)
        try "\(StartupHook.beginMarker)\n".write(to: paths.zshrc, atomically: true, encoding: .utf8)
        let checks = await service().run(config(.init()))
        #expect(check("generated-syntax", in: checks)?.severity == .error)
        #expect(check("hook", in: checks)?.severity == .error)
    }

    @Test func configurationProblemsAreReported() async {
        defer { try? FileManager.default.removeItem(at: home) }
        let effective = config(.init(
            path: [.init(rawPath: "~/missing-dir", order: 0), .init(rawPath: "$HOME/dup", order: 1), .init(rawPath: "~/dup", order: 2)],
            aliases: [.init(name: "ls", command: "ls -G"), .init(name: "mk", command: "make")],
            functions: [.init(name: "mk", body: "  echo")]
        ))
        let checks = await service().run(effective)
        #expect(check("path-missing", in: checks)?.severity == .warning)
        #expect(check("path-duplicates", in: checks)?.severity == .info)
        #expect(check("alias-function-conflict", in: checks)?.detail == "mk")
        #expect(check("alias-shadowing", in: checks)?.detail == "ls")
    }
}
