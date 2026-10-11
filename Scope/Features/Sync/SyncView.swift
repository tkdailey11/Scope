//
//  SyncView.swift
//  Scope
//
//  Opt-in iCloud sync. Editing works the same with sync off, offline or failing.
//

import SwiftUI

struct SyncView: View {
    @Environment(SyncCoordinator.self) private var sync

    var body: some View {
        Form {
            Section {
                Toggle("Sync with iCloud", isOn: enabledBinding)
                    .disabled(sync.isSyncing)
                if let message = sync.accountStatus?.message, !sync.isEnabled || sync.lastError != nil {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
                Text("Syncs profiles, environment variables, PATH entries, aliases and functions, encrypted in your private iCloud. Machine-specific items, secret values, the generated shell file and backups stay on this Mac. Which profile is active is chosen per Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if sync.isEnabled {
                Section("Status") {
                    LabeledContent("Last synced") {
                        if let date = sync.state.lastSyncedAt {
                            Text(date, format: .relative(presentation: .named))
                        } else {
                            Text("Not yet")
                        }
                    }
                    if sync.isSyncing {
                        ProgressView().controlSize(.small)
                    }
                    IssueText(message: sync.lastError)
                    Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await sync.syncNow() }
                    }
                    .disabled(sync.isSyncing)
                }
            }

            if !sync.conflicts.isEmpty {
                Section {
                    ForEach(sync.conflicts) { SyncConflictRow(conflict: $0) }
                } header: {
                    Text("Needs Your Decision")
                } footer: {
                    Text("These items were changed on this Mac and on another. Nothing is overwritten until you choose.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { sync.isEnabled }, set: { value in Task { await sync.setEnabled(value) } })
    }
}
