import Foundation
import Testing
@testable import Scope

struct TestShellSessionTests {
    let temp: URL

    init() throws {
        temp = FileManager.default.temporaryDirectory.appending(path: "scope-ts-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    }

    private func session() -> TestShellSession {
        TestShellSession(temporaryDirectory: temp, home: temp)
    }

    /// Collects output until `marker` appears (or the shell ends / times out).
    private func output(of session: TestShellSession, until marker: String) async -> String {
        await withTaskGroup(of: String.self) { group in
            group.addTask {
                var text = ""
                for await chunk in session.output {
                    text += chunk
                    if text.contains(marker) { break }
                }
                return text
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return "TIMEOUT"
            }
            let first = await group.next() ?? ""
            group.cancelAll()
            return first
        }
    }

    @Test func pendingConfigurationIsLoaded() async throws {
        defer { try? FileManager.default.removeItem(at: temp) }
        let s = session()
        try await s.start(pendingConfig: "export SCOPE_T=hello\nalias scopealias='echo aliased'\n")
        await s.send("print -r -- \"var=$SCOPE_T\"; scopealias; print END")
        let text = await output(of: s, until: "END")
        #expect(text.contains("var=hello"))
        #expect(text.contains("aliased"))
        await s.stop()
    }

    @Test func realStartupFilesAreNotRead() async throws {
        defer { try? FileManager.default.removeItem(at: temp) }
        try "export FROM_ZSHRC=yes\n".write(to: temp.appending(path: ".zshrc"), atomically: true, encoding: .utf8)
        let s = session()
        try await s.start(pendingConfig: "")
        await s.send("print -r -- \"rc=${FROM_ZSHRC:-unset}\"; print END")
        let text = await output(of: s, until: "END")
        #expect(text.contains("rc=unset"))
        await s.stop()
    }

    @Test func aFailingCommandDoesNotEndTheSession() async throws {
        defer { try? FileManager.default.removeItem(at: temp) }
        let s = session()
        try await s.start(pendingConfig: "")
        await s.send("if then fi")
        await s.send("nosuchcommand_scope")
        await s.send("print STILL_ALIVE")
        let text = await output(of: s, until: "STILL_ALIVE")
        #expect(text.contains("STILL_ALIVE"))
        await s.stop()
    }

    @Test func stopTerminatesAndRemovesTemporaryFiles() async throws {
        defer { try? FileManager.default.removeItem(at: temp) }
        let s = session()
        try await s.start(pendingConfig: "export A=1\n")
        #expect(try FileManager.default.contentsOfDirectory(atPath: temp.path).contains { $0.hasPrefix("scope-test-") })
        await s.stop()
        #expect(await !s.isRunning)
        #expect(try !FileManager.default.contentsOfDirectory(atPath: temp.path).contains { $0.hasPrefix("scope-test-") })
        await s.stop() // idempotent
    }

    @Test func doesNotTouchScopeFiles() async throws {
        defer { try? FileManager.default.removeItem(at: temp) }
        let s = session()
        try await s.start(pendingConfig: "export A=1\n")
        await s.stop()
        #expect(!FileManager.default.fileExists(atPath: ScopePaths(home: temp).scopeDirectory.path))
        #expect(!FileManager.default.fileExists(atPath: ScopePaths(home: temp).zshrc.path))
    }
}
