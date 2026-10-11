//
//  PathView.swift
//  Scope
//

import SwiftUI

struct PathView: View {
    @Environment(AppState.self) private var appState
    @State private var selection = Set<PathEntry.ID>()
    @State private var editorRequest: PathEntryEditorRequest?
    @State private var idsPendingDeletion = Set<PathEntry.ID>()
    @State private var isConfirmingDeletion = false

    /// Scopes that have entries, in the order they appear in `$PATH`: this Mac, profiles, then Global.
    private var scopes: [ConfigurationScope] {
        let used = Set(appState.configuration.path.map(\.scope))
        return appState.availableScopes.reversed().filter(used.contains)
    }

    var body: some View {
        Group {
            if scopes.isEmpty {
                ContentUnavailableView {
                    Label("No PATH Entries", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                } description: {
                    Text("Add directories like ~/go/bin so your shell can find the tools inside them.")
                } actions: {
                    Button("Add Directory", action: addEntry)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                list
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Delete", systemImage: "trash", action: deleteSelection)
                    .disabled(selection.isEmpty)
                Button("Add Directory", systemImage: "plus", action: addEntry)
            }
        }
        .sheet(item: $editorRequest, content: PathEntryEditor.init)
        .confirmationDialog(
            deletionTitle,
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: confirmDeletion)
        } message: {
            Text("This removes it from Scope. Your shell keeps the old PATH until you apply.")
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(scopes, id: \.self) { scope in
                section(for: scope)
            }
        }
        .contextMenu(forSelectionType: PathEntry.ID.self, menu: { _ in }) { ids in
            edit(ids)
        }
        .onDeleteCommand(perform: deleteSelection)
    }

    private func section(for scope: ConfigurationScope) -> some View {
        let entries = appState.pathEntries(in: scope)
        let isInactive = isInactiveProfile(scope)
        return Section {
            ForEach(Array(entries.enumerated()), id: \.element.id) { position, entry in
                PathEntryRow(
                    position: position + 1,
                    entry: entry,
                    status: appState.pathInspector.status(of: entry.rawPath),
                    onToggle: { appState.setPathEntry(entry.id, enabled: $0) }
                )
                .contextMenu {
                    Button("Edit…") { edit(entry.id) }
                    Button("Delete", role: .destructive) { requestDeletion(of: selectionOrSelf(entry.id)) }
                }
            }
            .onMove { appState.movePathEntries(in: scope, fromOffsets: $0, toOffset: $1) }
        } header: {
            HStack {
                ScopeLabel(scope: scope)
                if isInactive {
                    Text("Not active, so these aren't in your PATH")
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            if scope == scopes.last {
                Text("Entries higher in the list are searched first. Sections higher up override those below.")
            }
        }
    }

    private func isInactiveProfile(_ scope: ConfigurationScope) -> Bool {
        if case .profile(let id) = scope { id != appState.activeProfile?.id } else { false }
    }

    private var deletionTitle: String {
        idsPendingDeletion.count == 1
            ? String(localized: "Delete this directory?")
            : String(localized: "Delete \(idsPendingDeletion.count) directories?")
    }

    // MARK: - Actions

    private func addEntry() {
        editorRequest = .new
    }

    private func edit(_ ids: Set<PathEntry.ID>) {
        guard ids.count == 1, let id = ids.first else { return }
        edit(id)
    }

    private func edit(_ id: PathEntry.ID) {
        guard let entry = appState.configuration.path.first(where: { $0.id == id }) else { return }
        editorRequest = .edit(entry)
    }

    /// Right-clicking a selected row acts on the whole selection; otherwise just that row.
    private func selectionOrSelf(_ id: PathEntry.ID) -> Set<PathEntry.ID> {
        selection.contains(id) ? selection : [id]
    }

    private func deleteSelection() {
        requestDeletion(of: selection)
    }

    private func requestDeletion(of ids: Set<PathEntry.ID>) {
        guard !ids.isEmpty else { return }
        idsPendingDeletion = ids
        isConfirmingDeletion = true
    }

    private func confirmDeletion() {
        appState.deletePathEntries(ids: idsPendingDeletion)
        selection.subtract(idsPendingDeletion)
        idsPendingDeletion = []
    }
}

private struct PathEntryRow: View {
    let position: Int
    let entry: PathEntry
    let status: PathStatus
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text("\(position)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 20, alignment: .trailing)
            Text(entry.rawPath)
                .font(.body.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(entry.isEnabled ? .primary : .secondary)
            Spacer()
            if entry.isEnabled {
                PathStatusLabel(status: status)
            }
            EnabledToggle(isOn: entry.isEnabled, onChange: onToggle)
        }
        .padding(.vertical, 2)
    }
}

#Preview("With entries") {
    var configuration = StoredConfiguration()
    configuration.path = [
        .init(rawPath: "/opt/homebrew/bin", order: 0),
        .init(rawPath: "~/go/bin", order: 1),
        .init(rawPath: "$HOME/definitely-missing", order: 2),
        .init(rawPath: "~/old/bin", order: 3, isEnabled: false),
    ]
    let state = AppState(store: InMemoryConfigurationStore(configuration))
    return PathView()
        .environment(state)
        .task { await state.load() }
        .frame(width: 720, height: 420)
}

#Preview("Empty") {
    PathView()
        .environment(AppState(store: InMemoryConfigurationStore()))
        .frame(width: 720, height: 420)
}
