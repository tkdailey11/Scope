//
//  ProfileEditorRequest.swift
//  Scope
//

import Foundation

/// What the editor sheet should open with. Identifiable so it can drive `sheet(item:)`.
enum ProfileEditorRequest: Identifiable {
    case new
    case edit(Profile)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let profile): profile.id.uuidString
        }
    }

    var profile: Profile? {
        if case .edit(let profile) = self { profile } else { nil }
    }
}
