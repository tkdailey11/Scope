//
//  TestShellSession.swift
//  Scope
//
//  A temporary zsh that has the pending (unapplied) configuration sourced into it.
//  Isolated from the user's real startup files (`zsh -f`, private ZDOTDIR), and
//  everything it creates is deleted on stop. Nothing is written to ~/.scope or
//  the user's startup files. See "Test Configuration" in Design/04_UX_Flows.md.
//

import Foundation
import OSLog

nonisolated enum TestShellError: Error, Equatable {
    case alreadyStarted
    case launchFailed(String)
}

nonisolated actor TestShellSession {
    /// Combined stdout and stderr, as it arrives. Finishes when the shell exits.
    nonisolated let output: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    private let fileSystem: any FileSystem
    private let temporaryDirectory: URL
    private let home: URL
    private let zshExecutable: URL
    private var process: Process?
    private var input: FileHandle?
    private var sessionDirectory: URL?

    private static let logger = Logger(subsystem: "com.scope.Scope", category: "TestShell")

    init(
        fileSystem: any FileSystem = LocalFileSystem(),
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        zshExecutable: URL = URL(filePath: "/bin/zsh")
    ) {
        self.fileSystem = fileSystem
        self.temporaryDirectory = temporaryDirectory
        self.home = home
        self.zshExecutable = zshExecutable
        (output, continuation) = AsyncStream.makeStream(of: String.self)
    }

    var isRunning: Bool { process?.isRunning ?? false }

    /// `pendingConfig` is the text Apply would write. It is only sourced, never installed.
    func start(pendingConfig: String) throws {
        guard process == nil else { throw TestShellError.alreadyStarted }

        let directory = temporaryDirectory.appending(path: "scope-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        let configFile = directory.appending(path: "pending.zsh", directoryHint: .notDirectory)
        try fileSystem.writeAtomically(Data(pendingConfig.utf8), to: configFile)
        sessionDirectory = directory
        let quoted = try ZshQuoting.literal(configFile.path(percentEncoded: false))

        let process = Process()
        process.executableURL = zshExecutable
        // -f: skip all startup files. -i: keep going after errors in a command.
        process.arguments = ["-f", "-i"]
        process.currentDirectoryURL = home
        process.environment = [
            "HOME": home.path(percentEncoded: false),
            "USER": NSUserName(),
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "LANG": "en_US.UTF-8",
            "TERM": "dumb",
            "ZDOTDIR": directory.path(percentEncoded: false),
            "SCOPE_TEST_SHELL": "1",
        ]
        let stdin = Pipe(), combined = Pipe()
        process.standardInput = stdin
        process.standardOutput = combined
        process.standardError = combined

        let continuation = continuation
        combined.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                continuation.finish()
            } else {
                continuation.yield(String(decoding: data, as: UTF8.self))
            }
        }

        do {
            try process.run()
        } catch {
            combined.fileHandleForReading.readabilityHandler = nil
            try? fileSystem.remove(directory)
            sessionDirectory = nil
            throw TestShellError.launchFailed(error.localizedDescription)
        }
        self.process = process
        input = stdin.fileHandleForWriting

        send(raw: """
            PROMPT=''; RPROMPT=''; HISTFILE=/dev/null
            eval "$(/usr/libexec/path_helper -s)"
            source \(quoted)

            """)
    }

    /// Runs one command line (which may span several lines) in the session.
    func send(_ command: String) {
        send(raw: command.hasSuffix("\n") ? command : command + "\n")
    }

    /// Terminates the shell and deletes its temporary files. Safe to call more than once.
    func stop() {
        try? input?.close()
        input = nil
        if process?.isRunning == true { process?.terminate() }
        process = nil
        if let sessionDirectory { try? fileSystem.remove(sessionDirectory) }
        sessionDirectory = nil
        continuation.finish()
    }

    private func send(raw text: String) {
        guard isRunning else { return }
        do {
            try input?.write(contentsOf: Data(text.utf8))
        } catch {
            Self.logger.error("Couldn't write to test shell: \(error.localizedDescription, privacy: .public)")
        }
    }
}
