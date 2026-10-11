//
//  FunctionsView.swift
//  Scope
//
//  Split layout: searchable list on the left, code editor on the right.
//

import SwiftUI

struct FunctionsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selection: ShellFunction.ID?
    /// A function being created. Shown when nothing is selected.
    @State private var newDraft: FunctionDraft?
    /// Unsaved edits per function, so switching rows never loses work.
    @State private var edits: [ShellFunction.ID: FunctionDraft] = [:]
    @State private var isConfirmingDeletion = false

    private var functions: [ShellFunction] { appState.functions(matching: searchText) }

    private var selectedFunction: ShellFunction? {
        selection.flatMap { id in appState.configuration.functions.first { $0.id == id } }
    }

    var body: some View {
        Group {
            if appState.configuration.functions.isEmpty && newDraft == nil {
                ContentUnavailableView {
                    Label("No Functions", systemImage: "curlybraces")
                } description: {
                    Text("Add reusable shell functions like mkcd. Scope writes them to a file your shell loads at startup.")
                } actions: {
                    Button("Add Function", action: addFunction)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                HSplitView {
                    list.frame(minWidth: 200, idealWidth: 240, maxWidth: 360)
                    editor.frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Delete", systemImage: "trash") { isConfirmingDeletion = true }
                    .disabled(selectedFunction == nil)
                Button("Add Function", systemImage: "plus", action: addFunction)
            }
        }
        .confirmationDialog("Delete this function?", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteSelection)
        } message: {
            Text("This removes it from Scope. Your shell keeps the function until you apply.")
        }
        .onChange(of: appState.configuration.functions.map(\.id)) { _, ids in
            if let selection, !ids.contains(selection) { self.selection = nil }
            edits = edits.filter { ids.contains($0.key) }
        }
    }

    // MARK: - List

    private var list: some View {
        List(selection: $selection) {
            ForEach(functions) { function in
                HStack {
                    Text(function.name)
                        .font(.body.monospaced())
                        .lineLimit(1)
                        .foregroundStyle(function.isEnabled ? .primary : .secondary)
                    Spacer()
                    if edits[function.id] != nil {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(Theme.accent)
                            .help("Unsaved changes")
                            .accessibilityLabel("Unsaved changes")
                    }
                    if !function.isEnabled {
                        Image(systemName: "pause.circle")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Disabled")
                    }
                }
                .tag(function.id)
                .contextMenu {
                    Button(function.isEnabled ? "Disable" : "Enable") {
                        appState.setFunction(function.id, enabled: !function.isEnabled)
                    }
                    Button("Delete", role: .destructive) {
                        selection = function.id
                        isConfirmingDeletion = true
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search functions")
        .overlay {
            if functions.isEmpty && !searchText.isEmpty { ContentUnavailableView.search }
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        if let function = selectedFunction {
            FunctionEditor(
                draft: Binding(
                    get: { edits[function.id] ?? FunctionDraft(function) },
                    set: { edits[function.id] = $0 == FunctionDraft(function) ? nil : $0 }
                ),
                function: function,
                hasUnsavedChanges: edits[function.id] != nil,
                onSave: { save(function) },
                onRevert: { edits[function.id] = nil }
            )
            .id(function.id)
        } else if newDraft != nil {
            FunctionEditor(
                draft: Binding(get: { newDraft ?? FunctionDraft() }, set: { newDraft = $0 }),
                function: nil,
                hasUnsavedChanges: newDraft != FunctionDraft(),
                onSave: saveNew,
                onRevert: { newDraft = FunctionDraft() }
            )
            .id("new")
        } else {
            ContentUnavailableView("Select a Function", systemImage: "curlybraces",
                                   description: Text("Choose a function to edit, or add a new one."))
        }
    }

    // MARK: - Actions

    private func addFunction() {
        selection = nil
        if newDraft == nil { newDraft = FunctionDraft() }
    }

    private func save(_ function: ShellFunction) {
        guard let draft = edits[function.id] else { return }
        if appState.saveFunction(draft, replacing: function.id) != nil {
            edits[function.id] = nil
        }
    }

    private func saveNew() {
        guard let draft = newDraft, let id = appState.saveFunction(draft) else { return }
        newDraft = nil
        selection = id
    }

    private func deleteSelection() {
        guard let selection else { return }
        appState.deleteFunctions(ids: [selection])
    }
}

#Preview("With functions") {
    var configuration = StoredConfiguration()
    configuration.functions = [
        .init(name: "mkcd", body: "  mkdir -p \"$1\" && cd \"$1\""),
        .init(name: "gco", body: "  git checkout \"$@\""),
        .init(name: "broken", body: "  if true; then", isEnabled: false),
    ]
    let state = AppState(store: InMemoryConfigurationStore(configuration))
    return FunctionsView()
        .environment(state)
        .task { await state.load() }
        .frame(width: 900, height: 520)
}

#Preview("Empty") {
    FunctionsView()
        .environment(AppState(store: InMemoryConfigurationStore()))
        .frame(width: 900, height: 520)
}
