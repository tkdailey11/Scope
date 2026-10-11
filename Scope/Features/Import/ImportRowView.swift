//
//  ImportRowView.swift
//  Scope
//

import SwiftUI

struct ImportRowView: View {
    @Binding var row: ImportRow
    let isAlreadyInScope: Bool

    var body: some View {
        Toggle(isOn: $row.isSelected) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(row.candidate.item.title)
                        .font(.body.monospaced())
                    if isAlreadyInScope {
                        Text("Already in Scope")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(row.candidate.file):\(row.candidate.line)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                if !row.candidate.item.detail.isEmpty {
                    Text(row.candidate.item.detail)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .toggleStyle(.checkbox)
        .disabled(isAlreadyInScope)
    }
}
