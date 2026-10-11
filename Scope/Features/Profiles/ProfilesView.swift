//
//  ProfilesView.swift
//  Scope
//
//  One profile is active at a time (MVP, see Design/12). Global and This Mac always apply.
//

import SwiftUI

struct ProfilesView: View {
    @Environment(AppState.self) private var appState
    @State private var editorRequest: ProfileEditorRequest?
    @State private var profilePendingDeletion: Profile?

    var body: some View {
        Group {
            if appState.configuration.profiles.isEmpty {
                ContentUnavailableView {
                    Label("No Profiles", systemImage: "person.crop.square.stack")
                } description: {
                    Text("Profiles hold configuration for a context, like Work or Personal. Only one is active at a time, and it sits between Global and This Mac.")
                } actions: {
                    Button("Add Profile", action: addProfile)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                list
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Add Profile", systemImage: "plus", action: addProfile)
            }
        }
        .sheet(item: $editorRequest, content: ProfileEditor.init)
        .confirmationDialog(
            "Delete “\(profilePendingDeletion?.name ?? "")”?",
            isPresented: Binding(get: { profilePendingDeletion != nil }, set: { if !$0 { profilePendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: profilePendingDeletion
        ) { profile in
            Button("Delete Profile and Its Items", role: .destructive) { appState.deleteProfile(profile.id) }
        } message: { profile in
            Text(deletionMessage(for: profile))
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(appState.profilesByName) { profile in
                    ProfileRow(
                        profile: profile,
                        counts: appState.itemCounts(in: .profile(profile.id)),
                        onActivate: { appState.setActiveProfile($0 ? profile.id : nil) }
                    )
                    .contextMenu {
                        Button(profile.isActive ? "Deactivate" : "Activate") {
                            appState.setActiveProfile(profile.isActive ? nil : profile.id)
                        }
                        Button("Rename…") { editorRequest = .edit(profile) }
                        Button("Delete…", role: .destructive) { profilePendingDeletion = profile }
                    }
                }
            } footer: {
                Text("Items in the active profile override Global items with the same name. Items scoped to This Mac override both.")
            }
        }
    }

    private func deletionMessage(for profile: Profile) -> String {
        let counts = appState.itemCounts(in: .profile(profile.id))
        let total = counts.environment + counts.path + counts.aliases + counts.functions
        return total == 0
            ? String(localized: "This profile has no items.")
            : String(localized: "This also deletes its \(total) items from Scope. Your shell keeps them until you apply.")
    }

    private func addProfile() {
        editorRequest = .new
    }
}

private struct ProfileRow: View {
    let profile: Profile
    let counts: (environment: Int, path: Int, aliases: Int, functions: Int)
    let onActivate: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: profile.iconName ?? ProfileEditor.defaultIcon)
                .frame(width: 24)
                .foregroundStyle(profile.isActive ? Theme.accent : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Active", isOn: Binding(get: { profile.isActive }, set: onActivate))
                .toggleStyle(.switch)
        }
        .padding(.vertical, 2)
    }

    private var summary: String {
        String(localized: "\(counts.environment) variables · \(counts.path) PATH entries · \(counts.aliases) aliases · \(counts.functions) functions")
    }
}

#Preview {
    var configuration = StoredConfiguration()
    configuration.profiles = [
        .init(name: "Work", iconName: "briefcase", isActive: true),
        .init(name: "Personal", iconName: "house"),
    ]
    let state = AppState(store: InMemoryConfigurationStore(configuration))
    return ProfilesView()
        .environment(state)
        .task { await state.load() }
        .frame(width: 720, height: 420)
}
