//
//  SyncConflictRow.swift
//  Scope
//

import SwiftUI

struct SyncConflictRow: View {
    let conflict: PendingConflict

    @Environment(AppState.self) private var appState
    @Environment(SyncCoordinator.self) private var sync

    private var localItem: SyncItem? {
        appState.syncItems().first { $0.id == conflict.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text((localItem ?? conflict.remote.item)?.title ?? String(localized: "Deleted item"))
                .font(.headline.monospaced())
            HStack(alignment: .top, spacing: 16) {
                version(
                    title: "This Mac",
                    text: localItem?.summary ?? String(localized: "Deleted on this Mac"),
                    date: localItem?.modifiedAt,
                    keepTitle: "Keep This Mac",
                    keepLocal: true
                )
                version(
                    title: "iCloud",
                    text: conflict.remote.item?.summary ?? String(localized: "Deleted on another Mac"),
                    date: conflict.remote.modifiedAt,
                    keepTitle: "Keep iCloud",
                    keepLocal: false
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func version(title: LocalizedStringKey, text: String, date: Date?, keepTitle: LocalizedStringKey, keepLocal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.bold())
            if let date {
                Text(date, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.callout.monospaced())
                .lineLimit(8)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(keepTitle) { Task { await sync.resolve(conflict.id, keepLocal: keepLocal) } }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
