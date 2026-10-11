//
//  GeneratedFileWriter.swift
//  Scope
//
//  Writes the Scope-owned ~/.scope/generated.zsh atomically.
//

import Foundation

nonisolated struct GeneratedFileWriter: Sendable {
    var fileSystem: any FileSystem
    var paths: ScopePaths

    /// Returns `true` if the file changed, `false` if it was already up to date.
    @discardableResult
    func write(_ content: String) throws -> Bool {
        let data = Data(content.utf8)
        if fileSystem.fileExists(at: paths.generatedFile),
           (try? fileSystem.read(paths.generatedFile)) == data {
            return false
        }
        try fileSystem.writeAtomically(data, to: paths.generatedFile)
        return true
    }
}
