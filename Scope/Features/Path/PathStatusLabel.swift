//
//  PathStatusLabel.swift
//  Scope
//

import SwiftUI

/// Whether the directory exists. Icon + text, so status never relies on color alone.
struct PathStatusLabel: View {
    let status: PathStatus

    var body: some View {
        switch status {
        case .exists:
            Label("Found", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .missing:
            Label("Not found", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .unresolvable:
            Label("Not checked", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}
