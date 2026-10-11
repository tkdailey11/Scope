//
//  PathEntryEditorRequest.swift
//  Scope
//

import Foundation

/// What the editor sheet should open with. Identifiable so it can drive `sheet(item:)`.
enum PathEntryEditorRequest: Identifiable {
    case new
    case edit(PathEntry)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let entry): entry.id.uuidString
        }
    }

    var entry: PathEntry? {
        if case .edit(let entry) = self { entry } else { nil }
    }

    var initialDraft: PathEntryDraft {
        entry.map(PathEntryDraft.init) ?? PathEntryDraft()
    }
}
