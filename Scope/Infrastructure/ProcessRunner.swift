//
//  ProcessRunner.swift
//  Scope
//
//  Subprocess launching behind a protocol. Output is never logged here:
//  callers decide what is safe to surface.
//

import Foundation

nonisolated struct ProcessResult: Equatable, Sendable {
    var exitCode: Int32
    var standardOutput: String
    var standardError: String
}

nonisolated enum ProcessRunnerError: Error, Equatable {
    case timedOut
    case launchFailed(String)
}

nonisolated protocol ProcessRunner: Sendable {
    func run(executable: URL, arguments: [String], timeout: Duration) async throws -> ProcessResult
}

nonisolated struct SystemProcessRunner: ProcessRunner {
    func run(executable: URL, arguments: [String], timeout: Duration) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        // Minimal, predictable environment; no stdin so nothing can block on input.
        process.environment = ["PATH": "/usr/bin:/bin", "HOME": NSHomeDirectory(), "LC_ALL": "en_US.UTF-8"]
        process.standardInput = FileHandle.nullDevice
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err

        // Drain pipes concurrently so a chatty child can't deadlock on a full buffer.
        let stdoutTask = Task.detached { out.fileHandleForReading.readDataToEndOfFile() }
        let stderrTask = Task.detached { err.fileHandleForReading.readDataToEndOfFile() }

        let exited = AsyncStream<Void>.makeStream()
        process.terminationHandler = { _ in
            exited.continuation.yield()
            exited.continuation.finish()
        }
        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        let timedOut = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in exited.stream { return false }
                return false
            }
            group.addTask {
                (try? await Task.sleep(for: timeout)) != nil
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        if timedOut {
            process.terminate()
            _ = await stdoutTask.value
            _ = await stderrTask.value
            throw ProcessRunnerError.timedOut
        }

        return ProcessResult(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: await stdoutTask.value, as: UTF8.self),
            standardError: String(decoding: await stderrTask.value, as: UTF8.self)
        )
    }
}
