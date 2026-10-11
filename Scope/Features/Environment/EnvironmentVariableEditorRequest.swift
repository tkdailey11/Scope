//
//  EnvironmentVariableEditorRequest.swift
//  Scope
//

import Foundation

/// What the editor sheet should open with. Identifiable so it can drive `sheet(item:)`.
enum EnvironmentVariableEditorRequest: Identifiable {
    case new
    case edit(EnvironmentVariable)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let variable): variable.id.uuidString
        }
    }

    var variable: EnvironmentVariable? {
        if case .edit(let variable) = self { variable } else { nil }
    }

    var initialDraft: EnvironmentVariableDraft {
        variable.map(EnvironmentVariableDraft.init) ?? EnvironmentVariableDraft()
    }
}
