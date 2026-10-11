//
//  IssueText.swift
//  Scope
//

import SwiftUI

/// Inline validation message. Uses an icon plus text so it never relies on color alone.
struct IssueText: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.red)
        }
    }
}
