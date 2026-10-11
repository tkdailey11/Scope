import Foundation
import Testing
@testable import Scope

private struct StubRunner: ProcessRunner {
    var result: Result<ProcessResult, ProcessRunnerError>
    func run(executable: URL, arguments: [String], timeout: Duration) async throws -> ProcessResult {
        try result.get()
    }
}

struct ShellSyntaxValidatorTests {
    private func validator(runner: any ProcessRunner = SystemProcessRunner()) -> ShellSyntaxValidator {
        ShellSyntaxValidator(fileSystem: LocalFileSystem(), processRunner: runner)
    }

    @Test func generatedOutputPassesRealZsh() async throws {
        let config = ConfigurationComposer.compose(
            ConfigurationSnapshot(
                environment: [.init(name: "A", value: "it's $HOME", valueMode: .literal)],
                path: [.init(rawPath: "~/bin")],
                aliases: [.init(name: "gs", command: "git status")],
                functions: [.init(name: "mkcd", body: "  mkdir -p \"$1\" && cd \"$1\"")]
            ),
            activeProfileID: nil, machineID: nil
        )
        let result = try await validator().validate(ZshGenerator.generate(config))
        #expect(result == .valid)
    }

    @Test func unterminatedFunctionReportsALine() async throws {
        let result = try await validator().validate("export A=1\nfoo() {\n  echo hi\n")
        guard case .invalid(let diagnostics) = result else { Issue.record("expected invalid"); return }
        #expect(diagnostics.first?.line == 4 || diagnostics.first?.line == 3)
        #expect(diagnostics.first?.message.contains("parse error") == true)
    }

    @Test func badTokenReportsExactLine() async throws {
        let result = try await validator().validate("export A=1\nif true; then\n  echo\nfi fi\n")
        #expect(result == .invalid([.init(line: 4, message: "parse error near `fi'")]))
    }

    @Test func unmatchedQuoteHasNoLineButHasMessage() async throws {
        let result = try await validator().validate("alias x='y\n")
        guard case .invalid(let diagnostics) = result else { Issue.record("expected invalid"); return }
        #expect(diagnostics.first?.message.contains("unmatched") == true)
    }

    @Test func validationNeverExecutesTheScript() async throws {
        let marker = FileManager.default.temporaryDirectory.appending(path: "scope-exec-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: marker) }
        _ = try await validator().validate("touch '\(marker.path)'\n")
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func temporaryFilesAreCleanedUp() async throws {
        let temp = FileManager.default.temporaryDirectory.appending(path: "scope-vtest-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        var v = validator()
        v.temporaryDirectory = temp
        _ = try await v.validate("echo ok\n")
        #expect(try FileManager.default.contentsOfDirectory(atPath: temp.path).isEmpty)
    }

    @Test func infrastructureFailuresThrowRatherThanLookInvalid() async {
        let v = validator(runner: StubRunner(result: .failure(.timedOut)))
        await #expect(throws: ProcessRunnerError.timedOut) { try await v.validate("echo\n") }
    }

    @Test func nonZeroExitWithUnparseableStderrStillInvalid() async throws {
        let stub = StubRunner(result: .success(.init(exitCode: 1, standardOutput: "", standardError: "")))
        let result = try await validator(runner: stub).validate("x")
        #expect(!result.isValid)
    }

    @Test func parserHandlesBothFormats() {
        let diagnostics = ShellSyntaxValidator.parseDiagnostics(
            "/t/g.zsh:7: parse error near `}'\nzsh: unmatched '\n", filePath: "/t/g.zsh"
        )
        #expect(diagnostics == [.init(line: 7, message: "parse error near `}'"), .init(line: nil, message: "unmatched '")])
    }
}

struct SystemProcessRunnerTests {
    @Test func capturesOutputAndExitCode() async throws {
        let result = try await SystemProcessRunner().run(
            executable: URL(filePath: "/bin/sh"), arguments: ["-c", "echo out; echo err >&2; exit 3"], timeout: .seconds(5)
        )
        #expect(result == .init(exitCode: 3, standardOutput: "out\n", standardError: "err\n"))
    }

    @Test func timesOutAndKillsLongRunningProcess() async {
        await #expect(throws: ProcessRunnerError.timedOut) {
            try await SystemProcessRunner().run(
                executable: URL(filePath: "/bin/sleep"), arguments: ["30"], timeout: .milliseconds(200)
            )
        }
    }

    @Test func missingExecutableIsLaunchFailure() async {
        await #expect(throws: (any Error).self) {
            try await SystemProcessRunner().run(executable: URL(filePath: "/nonexistent/x"), arguments: [], timeout: .seconds(1))
        }
    }
}
