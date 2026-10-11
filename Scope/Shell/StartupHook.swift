//
//  StartupHook.swift
//  Scope
//
//  Detects, installs and removes the narrowly marked `source` hook in a
//  user-owned startup file. Pure text transforms live in `StartupHook`;
//  `StartupHookManager` adds backups and I/O.
//

import Foundation
import OSLog

nonisolated enum StartupHookError: Error, Equatable {
    /// A begin or end marker exists without its partner, or markers are duplicated.
    /// Scope refuses to guess and touch the file.
    case malformedMarkers
    case notUTF8
}

nonisolated enum StartupHook {
    static let beginMarker = "# >>> Scope >>>"
    static let endMarker = "# <<< Scope <<<"
    static let sourceLine = #"[[ -f "$HOME/.scope/generated.zsh" ]] && source "$HOME/.scope/generated.zsh""#
    static let block = [beginMarker, sourceLine, endMarker].joined(separator: "\n")

    enum State: Equatable {
        case absent
        case installed
    }

    static func state(of text: String) throws -> State {
        try blockLineRange(in: lines(of: text)) == nil ? .absent : .installed
    }

    /// Appends the hook block. Existing content is never modified. No-op if installed.
    static func installing(into text: String) throws -> String {
        if try state(of: text) == .installed { return text }
        var result = text
        if !result.isEmpty {
            if !result.hasSuffix("\n") { result += "\n" }
            result += "\n"  // blank separator line (removed again by `removing`)
        }
        return result + block + "\n"
    }

    /// Removes the block, plus the single blank separator line `installing` added.
    static func removing(from text: String) throws -> String {
        var all = lines(of: text)
        guard let range = try blockLineRange(in: all) else { return text }
        var lower = range.lowerBound
        if lower > 0, all[lower - 1].isEmpty { lower -= 1 }
        all.removeSubrange(lower..<range.upperBound)
        return all.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Splits keeping a trailing empty element when text ends in "\n", so
    /// `joined("\n")` reproduces the input exactly.
    private static func lines(of text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    /// Range of the marker block (inclusive of both marker lines) or nil.
    private static func blockLineRange(in lines: [String]) throws -> Range<Int>? {
        let begins = lines.indices.filter { lines[$0].trimmingCharacters(in: .whitespaces) == beginMarker }
        let ends = lines.indices.filter { lines[$0].trimmingCharacters(in: .whitespaces) == endMarker }
        switch (begins.count, ends.count) {
        case (0, 0): return nil
        case (1, 1) where begins[0] < ends[0]: return begins[0]..<(ends[0] + 1)
        default: throw StartupHookError.malformedMarkers
        }
    }
}

// MARK: - Backups

nonisolated struct BackupRecord: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    /// The user file that was about to be modified.
    var originalPath: String
    var backupPath: String
    var createdAt: Date
    var reason: String
}

nonisolated struct StartupHookManager: Sendable {
    var fileSystem: any FileSystem
    var paths: ScopePaths
    var now: @Sendable () -> Date = { .now }

    private static let logger = Logger(subsystem: "com.scope.Scope", category: "StartupHook")

    func state(of startupFile: URL) throws -> StartupHook.State {
        guard fileSystem.fileExists(at: startupFile) else { return .absent }
        return try StartupHook.state(of: try readText(startupFile))
    }

    /// Installs the hook. Returns the backup made, or nil if nothing needed changing.
    @discardableResult
    func install(into startupFile: URL) throws -> BackupRecord? {
        try modify(startupFile, reason: "Install Scope hook") { try StartupHook.installing(into: $0) }
    }

    @discardableResult
    func remove(from startupFile: URL) throws -> BackupRecord? {
        guard fileSystem.fileExists(at: startupFile) else { return nil }
        return try modify(startupFile, reason: "Remove Scope hook") { try StartupHook.removing(from: $0) }
    }

    /// Restores a backup over its original file (itself backed up first).
    func restore(_ record: BackupRecord) throws {
        let original = URL(filePath: record.originalPath)
        let data = try fileSystem.read(URL(filePath: record.backupPath))
        if fileSystem.fileExists(at: original) {
            _ = try backup(original, reason: "Before restore")
        }
        try fileSystem.writeAtomically(data, to: fileSystem.resolvingSymlinks(original))
        Self.logger.info("Restored \(original.lastPathComponent, privacy: .public) from backup")
    }

    func backups() throws -> [BackupRecord] {
        guard fileSystem.fileExists(at: paths.backupIndex) else { return [] }
        return try JSONDecoder.scope.decode([BackupRecord].self, from: fileSystem.read(paths.backupIndex))
    }

    // MARK: - Internals

    private func modify(_ file: URL, reason: String, transform: (String) throws -> String) throws -> BackupRecord? {
        let target = fileSystem.resolvingSymlinks(file)
        let exists = fileSystem.fileExists(at: target)
        let original = exists ? try readText(target) : ""
        let updated = try transform(original)
        guard updated != original else { return nil }

        // Backup first; if it fails, the user file is untouched.
        let record = exists ? try backup(target, reason: reason) : nil
        try fileSystem.writeAtomically(Data(updated.utf8), to: target)
        Self.logger.info("\(reason, privacy: .public): \(target.lastPathComponent, privacy: .public)")
        return record
    }

    private func backup(_ file: URL, reason: String) throws -> BackupRecord {
        // Whole seconds, so the returned record equals what the ISO-8601 index round-trips.
        let date = Date(timeIntervalSince1970: now().timeIntervalSince1970.rounded(.down))
        let stamp = date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(.omitted).dateSeparator(.omitted))
        let id = UUID()
        let backupURL = paths.backupsDirectory
            .appending(path: "\(file.lastPathComponent).\(stamp).\(id.uuidString.prefix(8)).bak", directoryHint: .notDirectory)
        try fileSystem.writeAtomically(try fileSystem.read(file), to: backupURL)

        let record = BackupRecord(
            id: id,
            originalPath: file.path(percentEncoded: false),
            backupPath: backupURL.path(percentEncoded: false),
            createdAt: date,
            reason: reason
        )
        let index = try backups() + [record]
        try fileSystem.writeAtomically(try JSONEncoder.scope.encode(index), to: paths.backupIndex)
        return record
    }

    private func readText(_ url: URL) throws -> String {
        guard let text = String(data: try fileSystem.read(url), encoding: .utf8) else {
            throw StartupHookError.notUTF8
        }
        return text
    }
}

private extension JSONEncoder {
    nonisolated static var scope: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    nonisolated static var scope: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
