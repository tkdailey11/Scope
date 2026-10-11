//
//  ImportScanner.swift
//  Scope
//
//  Reads zsh startup files (read-only) and merges what `ShellImporter` finds
//  into one review list that mirrors how the shell would resolve it.
//

import Foundation
import OSLog

nonisolated struct ImportScanResult: Sendable {
    var candidates: [ImportCandidate] = []
    var detected: [DetectedLine] = []
    /// Files that exist but couldn't be read as UTF-8 text.
    var unreadableFiles: [String] = []
    var scannedFiles: [String] = []
}

nonisolated struct ImportScanner: Sendable {
    /// zsh load order. Later files override earlier ones.
    static let fileNames = [".zshenv", ".zprofile", ".zshrc", ".zlogin"]

    let fileSystem: any FileSystem
    let paths: ScopePaths

    private static let logger = Logger(subsystem: "com.scope.Scope", category: "ImportScanner")

    func scan() async -> ImportScanResult {
        var parsed: [ImportParseResult] = []
        var result = ImportScanResult()
        for (order, name) in Self.fileNames.enumerated() {
            let url = paths.home.appending(path: name, directoryHint: .notDirectory)
            guard fileSystem.fileExists(at: url) else { continue }
            guard let data = try? fileSystem.read(url), let text = String(data: data, encoding: .utf8) else {
                Self.logger.error("Couldn't read \(name, privacy: .public) for import")
                result.unreadableFiles.append(name)
                continue
            }
            result.scannedFiles.append(name)
            parsed.append(ShellImporter.parse(text, file: name, fileOrder: order))
        }
        let merged = Self.merge(parsed)
        result.candidates = merged.candidates
        result.detected = merged.detected
        return result
    }

    /// Resolves overlaps the way the shell would. Anything superseded moves to `detected`,
    /// so no line silently disappears from the review.
    static func merge(_ results: [ImportParseResult]) -> ImportParseResult {
        var merged = ImportParseResult()
        merged.detected = results.flatMap(\.detected)
        let all = results.flatMap(\.candidates)

        // PATH: a later line prepends ahead of earlier ones, so it has higher priority.
        // The first occurrence of a directory wins.
        var seenPaths = Set<String>()
        let pathCandidates = all
            .filter { if case .path = $0.item { true } else { false } }
            .sorted { ($1.fileOrder, $1.line, $0.ordinal) < ($0.fileOrder, $0.line, $1.ordinal) }
        var kept: [ImportCandidate] = []
        for candidate in pathCandidates {
            guard case .path(let raw) = candidate.item else { continue }
            if seenPaths.insert(raw).inserted {
                kept.append(candidate)
            } else {
                merged.detected.append(DetectedLine(
                    file: candidate.file, line: candidate.line, text: raw,
                    reason: String(localized: "Already listed with higher priority.")
                ))
            }
        }

        // Other kinds: the last definition of a name wins.
        let ordered = all.filter { if case .path = $0.item { false } else { true } }
            .sorted { ($0.fileOrder, $0.line) < ($1.fileOrder, $1.line) }
        var winners: [String: Int] = [:]
        for (index, candidate) in ordered.enumerated() {
            winners[key(of: candidate.item)] = index
        }
        var others: [ImportCandidate] = []
        for (index, candidate) in ordered.enumerated() {
            if winners[key(of: candidate.item)] == index {
                others.append(candidate)
            } else {
                merged.detected.append(DetectedLine(
                    file: candidate.file, line: candidate.line, text: key(of: candidate.item).dropFirst(2).description,
                    reason: String(localized: "Overridden by a later definition.")
                ))
            }
        }

        merged.candidates = others + kept
        merged.detected.sort { ($0.file, $0.line) < ($1.file, $1.line) }
        return merged
    }

    private static func key(of item: ImportedItem) -> String {
        switch item {
        case .environment(let name, _, _): "e:\(name)"
        case .alias(let name, _): "a:\(name)"
        case .function(let name, _): "f:\(name)"
        case .path(let raw): "p:\(raw)"
        }
    }
}
