//
//  EnvironmentVariableEditor.swift
//  Scope
//

import SwiftUI

struct EnvironmentVariableEditor: View {
    let request: EnvironmentVariableEditorRequest

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: EnvironmentVariableDraft
    @State private var scope: ConfigurationScope
    /// Validation messages stay hidden until the first save attempt or edit, so a blank form isn't shouting.
    @State private var showsValidation = false

    init(request: EnvironmentVariableEditorRequest) {
        self.request = request
        _draft = State(initialValue: request.initialDraft)
        _scope = State(initialValue: request.variable?.scope ?? .global)
    }

    private var isSecretBacked: Bool { request.variable?.secretReference != nil }

    private var existingNames: Set<String> {
        appState.environmentNames(in: scope, excluding: request.variable?.id)
    }

    private var nameIssue: String? { draft.nameIssue(existingNames: existingNames) }

    var body: some View {
        CardPage {
            CardSection(title: nil, footer: Text(draft.valueMode == .literal
                 ? "Literal: the value is used exactly as typed. Nothing expands."
                 : "Expression: $VARIABLES and $(commands) expand when a new shell starts.")) {
                CardField(label: "Name", text: $draft.name, prompt: "EDITOR", monospaced: true,
                          issue: showsValidation ? nameIssue : nil)

                HStack {
                    Text("Value type").foregroundStyle(.secondary)
                    Picker("Value type", selection: $draft.valueMode) {
                        Text("Literal").tag(ValueMode.literal)
                        Text("Expression").tag(ValueMode.expression)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                if isSecretBacked {
                    LabeledContent("Value", value: "Stored in Keychain")
                } else {
                    CardField(label: "Value", text: $draft.value, prompt: "nvim", monospaced: true,
                              multiline: true, issue: draft.valueIssue())
                }

                ScopePicker(scope: $scope, isEditable: request.variable == nil)

                CardToggle(label: "Enabled", isOn: $draft.isEnabled)
            }

            CardSection("Generated") {
                Text(draft.generatedLine ?? "—")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(draft.generatedLine == nil ? .secondary : .primary)
            }
        }
        .frame(minWidth: 460, minHeight: 420)
        .navigationTitle(request.variable == nil ? "Add Variable" : "Edit Variable")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(showsValidation && !draft.isValid(existingNames: existingNames))
            }
        }
        .onChange(of: draft.name) { showsValidation = true }
    }

    private func save() {
        showsValidation = true
        if appState.saveEnvironmentVariable(draft, replacing: request.variable?.id, scope: scope) {
            dismiss()
        }
    }
}

#Preview {
    EnvironmentVariableEditor(request: .new)
        .environment(AppState(store: InMemoryConfigurationStore()))
}
