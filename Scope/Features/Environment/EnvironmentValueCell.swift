//
//  EnvironmentValueCell.swift
//  Scope
//

import SwiftUI

struct EnvironmentValueCell: View {
    let variable: EnvironmentVariable

    var body: some View {
        if variable.secretReference != nil {
            // Secrets are masked by default (Design/02_Product_Requirements.md).
            Label("Secret", systemImage: "lock.fill")
                .foregroundStyle(.secondary)
        } else {
            Text(variable.value ?? "")
                .font(.body.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
