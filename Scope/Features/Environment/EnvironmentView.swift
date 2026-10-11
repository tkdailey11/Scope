//
//  EnvironmentView.swift
//  Scope
//

import SwiftUI

struct EnvironmentView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selection = Set<EnvironmentVariable.ID>()
    @State private var editorRequest: EnvironmentVariableEditorRequest?
    @State private var idsPendingDeletion = Set<EnvironmentVariable.ID>()
    @State private var isConfirmingDeletion = false

    private var variables: [EnvironmentVariable] {
        appState.environmentVariables(matching: searchText)
    }

    var body: some View {
        Group {
            if appState.configuration.environment.isEmpty {
                ContentUnavailableView {
                    Label("No Environment Variables", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Add variables like EDITOR or GOPATH. Scope writes them to a file your shell loads at startup.")
                } actions: {
                    Button("Add Variable", action: addVariable)
                        .buttonStyle(.borderedProminent)
                }
            } else if variables.isEmpty {
                ContentUnavailableView.search
            } else {
                table
            }
        }
        .searchable(text: $searchText, prompt: "Search variables")
        .toolbar {
            ToolbarItemGroup {
                Button("Delete", systemImage: "trash", action: deleteSelection)
                    .disabled(selection.isEmpty)
                Button("Add Variable", systemImage: "plus", action: addVariable)
            }
        }
        .sheet(item: $editorRequest, content: EnvironmentVariableEditor.init)
        .confirmationDialog(
            deletionTitle,
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: confirmDeletion)
        } message: {
            Text("This removes it from Scope. Your shell keeps the old value until you apply.")
        }
    }

    private var table: some View {
        Table(variables, selection: $selection) {
            TableColumn("Name") { variable in
                Text(variable.name)
                    .font(.body.monospaced())
                    .foregroundStyle(variable.isEnabled ? .primary : .secondary)
            }
            TableColumn("Value") { variable in
                EnvironmentValueCell(variable: variable)
                    .foregroundStyle(variable.isEnabled ? .primary : .secondary)
            }
            TableColumn("Scope") { variable in
                ScopeLabel(scope: variable.scope)
            }
            .width(min: 90, ideal: 110)
            TableColumn("Enabled") { variable in
                EnabledToggle(isOn: variable.isEnabled) { appState.setEnvironmentVariable(variable.id, enabled: $0) }
            }
            .width(70)
        }
        .contextMenu(forSelectionType: EnvironmentVariable.ID.self) { ids in
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
            ? String(localized: "Delete this variable?")
            : String(localized: "Delete \(idsPendingDeletion.count) variables?")
    }

    // MARK: - Actions

    private func addVariable() {
        editorRequest = .new
    }

    private func edit(_ ids: Set<EnvironmentVariable.ID>) {
        guard ids.count == 1, let id = ids.first,
              let variable = appState.configuration.environment.first(where: { $0.id == id }) else { return }
        editorRequest = .edit(variable)
    }

    private func deleteSelection() {
        requestDeletion(of: selection)
    }

    private func requestDeletion(of ids: Set<EnvironmentVariable.ID>) {
        guard !ids.isEmpty else { return }
        idsPendingDeletion = ids
        isConfirmingDeletion = true
    }

    private func confirmDeletion() {
        appState.deleteEnvironmentVariables(ids: idsPendingDeletion)
        selection.subtract(idsPendingDeletion)
        idsPendingDeletion = []
    }
}

#Preview("With variables") {
    var configuration = StoredConfiguration()
    configuration.environment = [
        .init(name: "EDITOR", value: "nvim"),
        .init(name: "GOPATH", value: "$HOME/go", valueMode: .expression),
        .init(name: "OLD_FLAG", value: "1", isEnabled: false),
        .init(name: "API_TOKEN", secretReference: "keychain:api"),
    ]
    let state = AppState(store: InMemoryConfigurationStore(configuration))
    return EnvironmentView()
        .environment(state)
        .task { await state.load() }
        .frame(width: 720, height: 420)
}

#Preview("Empty") {
    EnvironmentView()
        .environment(AppState(store: InMemoryConfigurationStore()))
        .frame(width: 720, height: 420)
}
