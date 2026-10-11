import Foundation
import Testing
@testable import Scope

private struct StubRunner: ProcessRunner {
    var exitCode: Int32 = 0
    var stderr = ""
    func run(executable: URL, arguments: [String], timeout: Duration) async throws -> ProcessResult {
        ProcessResult(exitCode: exitCode, standardOutput: "", standardError: stderr)
    }
}

struct ApplyServiceTests {
    let home: URL
    let paths: ScopePaths

    init() throws {
        home = FileManager.default.temporaryDirectory.appending(path: "scope-apply-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        paths = ScopePaths(home: home)
    }

    private func service(runner: any ProcessRunner = SystemProcessRunner()) -> ApplyService {
        ApplyService(fileSystem: LocalFileSystem(), paths: paths, processRunner: runner)
    }

    private func config(_ snapshot: ConfigurationSnapshot) -> EffectiveConfiguration {
        ConfigurationComposer.compose(snapshot, activeProfileID: nil, machineID: nil)
    }

    private let valid = ConfigurationSnapshot(environment: [.init(name: "A", value: "1")])

    @Test func applyWritesFileAndInstallsHook() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let outcome = try await service().apply(config(valid))
        #expect(outcome.wroteGeneratedFile && outcome.installedHook)
        #expect(try String(contentsOf: paths.generatedFile, encoding: .utf8).contains("export A='1'"))
        #expect(try String(contentsOf: paths.zshrc, encoding: .utf8).contains(StartupHook.beginMarker))
    }

    @Test func secondApplyChangesNothing() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try await service().apply(config(valid))
        let outcome = try await service().apply(config(valid))
        #expect(!outcome.wroteGeneratedFile && !outcome.installedHook)
    }

    @Test func configurationErrorsBlockApplyAndWriteNothing() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let bad = config(.init(aliases: [.init(name: "bad name", command: "x")]))
        await #expect(throws: ApplyError.self) { try await service().apply(bad) }
        #expect(!FileManager.default.fileExists(atPath: paths.generatedFile.path))
        #expect(!FileManager.default.fileExists(atPath: paths.zshrc.path))
    }

    @Test func syntaxErrorsBlockApplyAndKeepPreviousFile() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try await service().apply(config(valid))
        let broken = config(.init(functions: [.init(name: "f", body: "  if true; then")]))
        await #expect {
            try await service().apply(broken)
        } throws: { error in
            if case ApplyError.syntaxInvalid = error { true } else { false }
        }
        #expect(try String(contentsOf: paths.generatedFile, encoding: .utf8).contains("export A='1'"))
    }

    @Test func unavailableValidatorBlocksApply() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        struct Failing: ProcessRunner {
            func run(executable: URL, arguments: [String], timeout: Duration) async throws -> ProcessResult {
                throw ProcessRunnerError.launchFailed("nope")
            }
        }
        await #expect(throws: ApplyError.self) { try await service(runner: Failing()).apply(config(valid)) }
        #expect(!FileManager.default.fileExists(atPath: paths.generatedFile.path))
    }

    @Test func malformedHookLeavesZshrcAlone() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let broken = "export X=1\n\(StartupHook.beginMarker)\n"
        try broken.write(to: paths.zshrc, atomically: true, encoding: .utf8)
        await #expect {
            try await service().apply(config(valid))
        } throws: { error in
            if case ApplyError.hookFailed = error { true } else { false }
        }
        #expect(try String(contentsOf: paths.zshrc, encoding: .utf8) == broken)
    }

    @Test func previewReportsPendingChangesUntilApplied() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let effective = config(valid)
        var preview = await service().preview(effective)
        #expect(preview.canApply && preview.hasPendingChanges && preview.hookState == .absent)
        try await service().apply(effective)
        preview = await service().preview(effective)
        #expect(!preview.hasPendingChanges && preview.hookState == .installed)
    }

    @Test func previewWithErrorsCannotApply() async {
        defer { try? FileManager.default.removeItem(at: home) }
        let preview = await service().preview(config(.init(environment: [.init(name: "1bad", value: "x")])))
        #expect(!preview.canApply && !preview.blockers.isEmpty)
    }
}
