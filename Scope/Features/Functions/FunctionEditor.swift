//
//  FunctionEditor.swift
//  Scope
//
//  Right-hand pane of the Functions screen. Edits a draft owned by the parent so
//  unsaved changes survive switching between functions.
//

import SwiftUI

struct FunctionEditor: View {
    @Binding var draft: FunctionDraft
    /// Where a new function applies. Fixed once the function exists.
    @Binding var scope: ConfigurationScope
    /// The function being edited, or nil when creating one.
    let function: ShellFunction?
    let hasUnsavedChanges: Bool
    let onSave: () -> Void
    let onRevert: () -> Void

    @Environment(AppState.self) private var appState
    /// Validation messages stay hidden until the first edit or save attempt, so a blank form isn't shouting.
    @State private var showsValidation = false
    @State private var syntax: SyntaxCheckResult?

    private var existingNames: Set<String> {
        appState.functionNames(in: scope, excluding: function?.id)
    }

    private var syntaxKey: String { draft.generatedText ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Name", text: $draft.name, prompt: Text("mkcd"))
                    .font(.title3.monospaced())
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                Spacer()
                ScopePicker(scope: $scope, isEditable: function == nil)
                    .labelsHidden()
                    .fixedSize()
                Toggle("Enabled", isOn: $draft.isEnabled)
                    .toggleStyle(.switch)
            }
            IssueText(message: showsValidation ? draft.nameIssue(existingNames: existingNames) : nil)
            if let warning = draft.nameWarning(aliasNames: appState.enabledAliasNames()) {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            // The wrapper lines are shown so it's clear the body is only what goes between the braces.
            VStack(alignment: .leading, spacing: 0) {
                Text("\(draft.trimmedName.isEmpty ? "name" : draft.trimmedName)() {")
                    .padding(.horizontal, 10).padding(.vertical, 6)
                CodeEditor(text: $draft.body, accessibilityLabel: String(localized: "Function body"))
                    .padding(.horizontal, 5)
                    .frame(minHeight: 160)
                Text("}")
                    .padding(.horizontal, 10).padding(.vertical, 6)
            }
            .font(.body.monospaced())
            .background(Theme.cardBackground, in: .rect(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Theme.cardBorder) }

            IssueText(message: showsValidation ? draft.bodyIssue() : nil)
            syntaxStatus

            HStack {
                Spacer()
                Button("Revert", action: onRevert)
                    .disabled(!hasUnsavedChanges)
                Button("Save") {
                    showsValidation = true
                    onSave()
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(function != nil && !hasUnsavedChanges)
            }
        }
        .padding()
        .onChange(of: draft) { showsValidation = true }
        .task(id: syntaxKey) { await checkSyntax() }
    }

    @ViewBuilder
    private var syntaxStatus: some View {
        switch syntax {
        case .valid:
            Label("Syntax OK", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .invalid(let diagnostics):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    Label(message(for: diagnostic), systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                }
                Text("You can still save. Apply will be blocked until this is fixed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case nil:
            EmptyView()
        }
    }

    private func message(for diagnostic: SyntaxDiagnostic) -> String {
        if let line = diagnostic.line, let bodyLine = draft.bodyLine(forGeneratedLine: line) {
            return String(localized: "Line \(bodyLine): \(diagnostic.message)")
        }
        return diagnostic.message
    }

    /// Debounced so zsh isn't launched on every keystroke; `task(id:)` cancels the previous wait.
    private func checkSyntax() async {
        syntax = nil
        guard draft.generatedText != nil else { return }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        let result = await appState.checkSyntax(of: draft)
        guard !Task.isCancelled else { return }
        syntax = result
    }
}
