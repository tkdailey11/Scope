//
//  AliasEditorRequest.swift
//  Scope
//

import Foundation

/// What the editor sheet should open with. Identifiable so it can drive `sheet(item:)`.
enum AliasEditorRequest: Identifiable {
    case new
    case edit(ShellAlias)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let alias): alias.id.uuidString
        }
    }

    var alias: ShellAlias? {
        if case .edit(let alias) = self { alias } else { nil }
    }

    var initialDraft: AliasDraft {
        alias.map(AliasDraft.init) ?? AliasDraft()
    }
}
