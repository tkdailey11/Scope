//
//  PathInspector.swift
//  Scope
//
//  Checks whether a PATH entry points at a real directory, without changing
//  the authored form the user typed.
//

import Foundation

nonisolated enum PathStatus: Equatable, Sendable {
    case exists
    case missing
    /// Uses a variable other than `$HOME`, so it can't be resolved without a shell.
    case unresolvable
}

nonisolated struct PathInspector: Sendable {
    var fileSystem: any FileSystem
    var home: URL

    /// Home as a path with no trailing slash, so prefix checks and joins are exact.
    private var homePath: String {
        var path = home.path(percentEncoded: false)
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }

    init(fileSystem: any FileSystem = LocalFileSystem(), home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.fileSystem = fileSystem
        self.home = home
    }

    func status(of rawPath: String) -> PathStatus {
        guard let expanded = expand(rawPath) else { return .unresolvable }
        return fileSystem.directoryExists(at: URL(filePath: expanded, directoryHint: .isDirectory)) ? .exists : .missing
    }

    /// Expands `~` and `$HOME` / `${HOME}`. Returns nil if another variable or a command substitution remains.
    func expand(_ rawPath: String) -> String? {
        var path = rawPath.trimmingCharacters(in: .whitespaces)
        if path == "~" || path.hasPrefix("~/") { path = homePath + path.dropFirst() }
        path = path.replacing("${HOME}", with: homePath).replacing(/\$HOME(?![A-Za-z0-9_])/, with: homePath)
        return path.contains("$") || path.contains("`") ? nil : path
    }

    /// Writes a chosen directory the way users author paths: under home becomes `~/…`.
    func authoredForm(of url: URL) -> String {
        let path = url.path(percentEncoded: false)
        if path == homePath { return "~" }
        if path.hasPrefix(homePath + "/") { return "~" + path.dropFirst(homePath.count) }
        return path
    }
}
