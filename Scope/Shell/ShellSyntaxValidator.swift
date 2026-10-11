//
//  ShellSyntaxValidator.swift
//  Scope
//
//  Runs `zsh -n` (parse only, nothing executes) over generated output.
//  A failure here must block Apply.
//

import Foundation

nonisolated struct SyntaxDiagnostic: Equatable, Sendable {
    /// 1-based line in the validated content, when zsh reported one.
    var line: Int?
    var message: String
}

nonisolated enum SyntaxCheckResult: Equatable, Sendable {
    case valid
    case invalid([SyntaxDiagnostic])

    var isValid: Bool { self == .valid }
}

nonisolated struct ShellSyntaxValidator: Sendable {
    var fileSystem: any FileSystem
    var processRunner: any ProcessRunner
    var zshExecutable = URL(filePath: "/bin/zsh")
    var temporaryDirectory = FileManager.default.temporaryDirectory
    var timeout: Duration = .seconds(5)

    /// Throws only for infrastructure failures (can't launch zsh, timeout, can't write temp file).
    /// Bad syntax is a normal `.invalid` result.
    func validate(_ content: String) async throws -> SyntaxCheckResult {
        // A file (rather than stdin) makes zsh report line numbers. The directory
        // is unique per call, so nothing predictable is ever opened or overwritten.
        let directory = temporaryDirectory.appending(path: "scope-validate-\(UUID().uuidString)", directoryHint: .isDirectory)
        let file = directory.appending(path: "generated.zsh", directoryHint: .notDirectory)
        try fileSystem.writeAtomically(Data(content.utf8), to: file)
        defer { try? fileSystem.remove(directory) }

        // -n: parse only. -f: skip the user's startup files (no side effects, reproducible).
        let result = try await processRunner.run(
            executable: zshExecutable,
            arguments: ["-n", "-f", file.path(percentEncoded: false)],
            timeout: timeout
        )
        guard result.exitCode != 0 else { return .valid }

        let diagnostics = Self.parseDiagnostics(result.standardError, filePath: file.path(percentEncoded: false))
        return .invalid(diagnostics.isEmpty
            ? [SyntaxDiagnostic(line: nil, message: "zsh reported a syntax error (exit \(result.exitCode)).")]
            : diagnostics)
    }

    /// Lines look like `/tmp/x/generated.zsh:4: parse error near `fi'`
    /// or, for unterminated quotes, `zsh: unmatched '`.
    static func parseDiagnostics(_ stderr: String, filePath: String) -> [SyntaxDiagnostic] {
        stderr.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = String(rawLine)
            if line.hasPrefix(filePath + ":") {
                let rest = line.dropFirst(filePath.count + 1)
                if let colon = rest.firstIndex(of: ":"), let number = Int(rest[..<colon]) {
                    let message = rest[rest.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    return SyntaxDiagnostic(line: number, message: message)
                }
            }
            let message = line.replacing("zsh: ", with: "", maxReplacements: 1)
            return message.isEmpty ? nil : SyntaxDiagnostic(line: nil, message: message)
        }
    }
}
