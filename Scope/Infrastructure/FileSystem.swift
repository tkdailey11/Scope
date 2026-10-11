//
//  FileSystem.swift
//  Scope
//
//  Filesystem access behind a protocol so services are testable and the
//  distribution/sandbox policy can change without touching callers.
//

import Foundation

nonisolated protocol FileSystem: Sendable {
    func fileExists(at url: URL) -> Bool
    func read(_ url: URL) throws -> Data
    /// Replaces the file atomically, creating parent directories as needed.
    func writeAtomically(_ data: Data, to url: URL) throws
    /// Follows symlinks so dotfile-manager setups (`~/.zshrc -> ~/dotfiles/zshrc`) keep their link.
    func resolvingSymlinks(_ url: URL) -> URL
}

nonisolated struct LocalFileSystem: FileSystem {
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    func read(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func writeAtomically(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // Preserve the existing file's permissions when replacing it.
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        try data.write(to: url, options: .atomic)
        if let permissions = attributes?[.posixPermissions] {
            try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path(percentEncoded: false))
        }
    }

    func resolvingSymlinks(_ url: URL) -> URL {
        url.resolvingSymlinksInPath()
    }
}

/// Well-known locations. Injectable `home` keeps tests out of the real home directory.
nonisolated struct ScopePaths: Sendable {
    var home: URL

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    var scopeDirectory: URL { home.appending(path: ".scope", directoryHint: .isDirectory) }
    var generatedFile: URL { scopeDirectory.appending(path: "generated.zsh", directoryHint: .notDirectory) }
    var backupsDirectory: URL { scopeDirectory.appending(path: "backups", directoryHint: .isDirectory) }
    var backupIndex: URL { backupsDirectory.appending(path: "index.json", directoryHint: .notDirectory) }
    var zshrc: URL { home.appending(path: ".zshrc", directoryHint: .notDirectory) }
}
