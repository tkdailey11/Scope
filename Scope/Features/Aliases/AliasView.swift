//
//  AliasView.swift
//  Scope
//

import SwiftUI

struct AliasView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selection = Set<ShellAlias.ID>()
    @State private var editorRequest: AliasEditorRequest?
    @State private var idsPendingDeletion = Set<ShellAlias.ID>()
    @State private var isConfirmingDeletion = false

    private var aliases: [ShellAlias] {
        appState.aliases(matching: searchText)
    }

    var body: some View {
        Group {
            if appState.configuration.aliases.isEmpty {
                ContentUnavailableView {
                    Label("No Aliases", systemImage: "arrow.right.square")
                } description: {
                    Text("Add shortcuts like gs for git status. Scope writes them to a file your shell loads at startup.")
                } actions: {
                    Button("Add Alias", action: addAlias)
                        .buttonStyle(.borderedProminent)
                }
            } else if aliases.isEmpty {
                ContentUnavailableView.search
            } else {
                table
            }
        }
        .searchable(text: $searchText, prompt: "Search aliases")
        .toolbar {
            ToolbarItemGroup {
                Button("Delete", systemImage: "trash", action: deleteSelection)
                    .disabled(selection.isEmpty)
                Button("Add Alias", systemImage: "plus", action: addAlias)
            }
        }
        .sheet(item: $editorRequest, content: AliasEditor.init)
        .confirmationDialog(
            deletionTitle,
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: confirmDeletion)
        } message: {
            Text("This removes it from Scope. Your shell keeps the alias until you apply.")
        }
    }

    private var table: some View {
        Table(aliases, selection: $selection) {
            TableColumn("Name") { alias in
                Text(alias.name)
                    .font(.body.monospaced())
                    .foregroundStyle(alias.isEnabled ? .primary : .secondary)
            }
            TableColumn("Command") { alias in
                Text(alias.command)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(alias.isEnabled ? .primary : .secondary)
            }
            TableColumn("Scope") { alias in
                ScopeLabel(scope: alias.scope)
            }
            .width(min: 90, ideal: 110)
            TableColumn("Enabled") { alias in
                EnabledToggle(isOn: alias.isEnabled) { appState.setAlias(alias.id, enabled: $0) }
            }
            .width(70)
        }
        .contextMenu(forSelectionType: ShellAlias.ID.self) { ids in
            if ids.count == 1 {
                Button("Edit…") { edit(ids) }
            }
            if !ids.isEmpty {
                Button("Delete", role: .destructive) { requestDeletion(of: ids) }
            }
        } primaryAction: { ids in
            edit(ids)
        }
        .onDeleteCommand(perform: deleteSelection)
    }

    private var deletionTitle: String {
        idsPendingDeletion.count == 1
            ? String(localized: "Delete this alias?")
            : String(localized: "Delete \(idsPendingDeletion.count) aliases?")
    }

    // MARK: - Actions

    private func addAlias() {
        editorRequest = .new
    }

    private func edit(_ ids: Set<ShellAlias.ID>) {
        guard ids.count == 1, let id = ids.first,
              let alias = appState.configuration.aliases.first(where: { $0.id == id }) else { return }
        editorRequest = .edit(alias)
    }

    private func deleteSelection() {
        requestDeletion(of: selection)
    }

    private func requestDeletion(of ids: Set<ShellAlias.ID>) {
        guard !ids.isEmpty else { return }
        idsPendingDeletion = ids
        isConfirmingDeletion = true
    }

    private func confirmDeletion() {
        appState.deleteAliases(ids: idsPendingDeletion)
        selection.subtract(idsPendingDeletion)
        idsPendingDeletion = []
    }
}

#Preview("With aliases") {
    var configuration = StoredConfiguration()
    configuration.aliases = [
        .init(name: "gs", command: "git status"),
        .init(name: "ll", command: "ls -lah"),
        .init(name: "old", command: "echo 'legacy'", isEnabled: false),
    ]
    let state = AppState(store: InMemoryConfigurationStore(configuration))
    return AliasView()
        .environment(state)
        .task { await state.load() }
        .frame(width: 720, height: 420)
}

#Preview("Empty") {
    AliasView()
        .environment(AppState(store: InMemoryConfigurationStore()))
        .frame(width: 720, height: 420)
}
