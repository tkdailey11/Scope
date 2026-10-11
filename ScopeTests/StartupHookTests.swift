import Foundation
import Testing
@testable import Scope

struct StartupHookTextTests {
    @Test func installAppendsAfterExistingContentUntouched() throws {
        let original = "export FOO=1\nalias x='y'\n"
        let result = try StartupHook.installing(into: original)
        #expect(result.hasPrefix(original))
        #expect(result == original + "\n" + StartupHook.block + "\n")
        #expect(try StartupHook.state(of: result) == .installed)
    }

    @Test func installIntoEmptyAndUnterminatedFiles() throws {
        #expect(try StartupHook.installing(into: "") == StartupHook.block + "\n")
        #expect(try StartupHook.installing(into: "no newline").hasPrefix("no newline\n\n"))
    }

    @Test func installIsIdempotent() throws {
        let once = try StartupHook.installing(into: "a\n")
        #expect(try StartupHook.installing(into: once) == once)
    }

    @Test func removeIsExactInverseOfInstall() throws {
        for original in ["", "a\n", "a\nb\n\nc\n", "# comment\n\n\nexport X=1\n"] {
            let installed = try StartupHook.installing(into: original)
            #expect(try StartupHook.removing(from: installed) == original, "original: \(original.debugDescription)")
        }
    }

    @Test func removeKeepsContentAfterBlock() throws {
        let text = "before\n\(StartupHook.block)\nafter\n"
        #expect(try StartupHook.removing(from: text) == "before\nafter\n")
    }

    @Test func removeWhenAbsentIsNoOp() throws {
        #expect(try StartupHook.removing(from: "a\n") == "a\n")
    }

    @Test func malformedMarkersAreRefused() {
        let cases = [
            "\(StartupHook.beginMarker)\n",
            "\(StartupHook.endMarker)\n",
            "\(StartupHook.block)\n\(StartupHook.block)\n",
            "\(StartupHook.endMarker)\n\(StartupHook.beginMarker)\n",
        ]
        for text in cases {
            #expect(throws: StartupHookError.malformedMarkers) { try StartupHook.installing(into: text) }
            #expect(throws: StartupHookError.malformedMarkers) { try StartupHook.removing(from: text) }
        }
    }
}

struct StartupHookManagerTests {
    private let home: URL
    private let paths: ScopePaths
    private let manager: StartupHookManager

    init() {
        home = FileManager.default.temporaryDirectory.appending(path: "scope-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        paths = ScopePaths(home: home)
        manager = StartupHookManager(fileSystem: LocalFileSystem(), paths: paths)
        try! FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    private func cleanUp() { try? FileManager.default.removeItem(at: home) }

    @Test func installBacksUpThenModifies() throws {
        defer { cleanUp() }
        try "export A=1\n".write(to: paths.zshrc, atomically: true, encoding: .utf8)

        let record = try #require(try manager.install(into: paths.zshrc))
        #expect(try String(contentsOfFile: record.backupPath, encoding: .utf8) == "export A=1\n")
        #expect(try String(contentsOf: paths.zshrc, encoding: .utf8).contains(StartupHook.sourceLine))
        #expect(try manager.backups() == [record])
        #expect(try manager.state(of: paths.zshrc) == .installed)

        // Second install changes nothing and makes no new backup.
        #expect(try manager.install(into: paths.zshrc) == nil)
        #expect(try manager.backups().count == 1)
    }

    @Test func removeThenRestoreRoundTrips() throws {
        defer { cleanUp() }
        let original = "export A=1\n"
        try original.write(to: paths.zshrc, atomically: true, encoding: .utf8)
        let installBackup = try #require(try manager.install(into: paths.zshrc))

        try manager.remove(from: paths.zshrc)
        #expect(try String(contentsOf: paths.zshrc, encoding: .utf8) == original)

        try manager.install(into: paths.zshrc)
        try manager.restore(installBackup)
        #expect(try String(contentsOf: paths.zshrc, encoding: .utf8) == original)
    }

    @Test func installCreatesMissingStartupFileWithoutBackup() throws {
        defer { cleanUp() }
        #expect(try manager.install(into: paths.zshrc) == nil)
        #expect(try manager.state(of: paths.zshrc) == .installed)
    }

    @Test func symlinkedStartupFileKeepsItsLink() throws {
        defer { cleanUp() }
        let real = home.appending(path: "dotfiles/zshrc")
        try FileManager.default.createDirectory(at: real.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "x\n".write(to: real, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: paths.zshrc, withDestinationURL: real)

        try manager.install(into: paths.zshrc)

        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: paths.zshrc.path)) != nil)
        #expect(try String(contentsOf: real, encoding: .utf8).contains(StartupHook.beginMarker))
    }

    @Test func malformedFileIsLeftUntouchedAndUnbackedUp() throws {
        defer { cleanUp() }
        let broken = "\(StartupHook.beginMarker)\nstuff\n"
        try broken.write(to: paths.zshrc, atomically: true, encoding: .utf8)
        #expect(throws: StartupHookError.malformedMarkers) { try manager.install(into: paths.zshrc) }
        #expect(try String(contentsOf: paths.zshrc, encoding: .utf8) == broken)
        #expect(try manager.backups().isEmpty)
    }
}

struct GeneratedFileWriterTests {
    @Test func writesAtomicallyAndSkipsUnchangedContent() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "scope-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = ScopePaths(home: home)
        let writer = GeneratedFileWriter(fileSystem: LocalFileSystem(), paths: paths)

        #expect(try writer.write("hello\n") == true)  // creates ~/.scope too
        #expect(try String(contentsOf: paths.generatedFile, encoding: .utf8) == "hello\n")
        #expect(try writer.write("hello\n") == false)
        #expect(try writer.write("changed\n") == true)
        #expect(try String(contentsOf: paths.generatedFile, encoding: .utf8) == "changed\n")
    }
}
