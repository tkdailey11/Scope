//
//  AliasEditor.swift
//  Scope
//

import SwiftUI

struct AliasEditor: View {
    let request: AliasEditorRequest

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: AliasDraft
    @State private var scope: ConfigurationScope
    /// Validation messages stay hidden until the first edit or save attempt, so a blank form isn't shouting.
    @State private var showsValidation = false

    init(request: AliasEditorRequest) {
        self.request = request
        _draft = State(initialValue: request.initialDraft)
        _scope = State(initialValue: request.alias?.scope ?? .global)
    }

    private var existingNames: Set<String> {
        appState.aliasNames(in: scope, excluding: request.alias?.id)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $draft.name, prompt: Text("gs"))
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                IssueText(message: showsValidation ? draft.nameIssue(existingNames: existingNames) : nil)

                TextField("Command", text: $draft.command, prompt: Text("git status"), axis: .vertical)
                    .font(.body.monospaced())
                    .lineLimit(1...6)
                    .autocorrectionDisabled()
                IssueText(message: showsValidation ? draft.commandIssue() : nil)

                ScopePicker(scope: $scope, isEditable: request.alias == nil)

                Toggle("Enabled", isOn: $draft.isEnabled)
            } footer: {
                Text("The command is used exactly as typed. Nothing expands until you run the alias.")
            }

            Section("Generated") {
                Text(draft.generatedLine ?? "—")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(draft.generatedLine == nil ? .secondary : .primary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 380)
        .navigationTitle(request.alias == nil ? "Add Alias" : "Edit Alias")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(showsValidation && !draft.isValid(existingNames: existingNames))
            }
        }
        .onChange(of: draft) { showsValidation = true }
    }

    private func save() {
        showsValidation = true
        if appState.saveAlias(draft, replacing: request.alias?.id, scope: scope) {
            dismiss()
        }
    }
}

#Preview {
    AliasEditor(request: .new)
        .environment(AppState(store: InMemoryConfigurationStore()))
}
