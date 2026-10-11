//
//  PathEntryEditor.swift
//  Scope
//

import SwiftUI
import UniformTypeIdentifiers

struct PathEntryEditor: View {
    let request: PathEntryEditorRequest

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PathEntryDraft
    @State private var scope: ConfigurationScope
    /// Validation messages stay hidden until the first edit or save attempt, so a blank form isn't shouting.
    @State private var showsValidation = false
    @State private var isChoosingDirectory = false

    init(request: PathEntryEditorRequest) {
        self.request = request
        _draft = State(initialValue: request.initialDraft)
        _scope = State(initialValue: request.entry?.scope ?? .global)
    }

    private var existingPaths: Set<String> {
        appState.pathStrings(in: scope, excluding: request.entry?.id)
    }

    private var pathIssue: String? { draft.pathIssue(existingPaths: existingPaths) }

    var body: some View {
        CardPage {
            CardSection(footer: "Use ~ or $HOME for your home folder. New entries are added at the bottom; drag them in the list to change priority.") {
                CardField(label: "Directory", text: $draft.rawPath, prompt: "~/go/bin", monospaced: true,
                          issue: showsValidation ? pathIssue : nil,
                          trailing: AnyView(Button("Choose…") { isChoosingDirectory = true }))

                if pathIssue == nil, appState.pathInspector.status(of: draft.trimmedPath) == .missing {
                    Label("This directory doesn't exist on this Mac. It's still saved, and your shell ignores missing entries.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                ScopePicker(scope: $scope, isEditable: request.entry == nil)

                CardToggle(label: "Enabled", isOn: $draft.isEnabled)
            }

            CardSection("Generated") {
                Text(draft.generatedLine ?? "—")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(draft.generatedLine == nil ? .secondary : .primary)
            }
        }
        .frame(minWidth: 460, minHeight: 340)
        .navigationTitle(request.entry == nil ? "Add Directory" : "Edit Directory")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(showsValidation && !draft.isValid(existingPaths: existingPaths))
            }
        }
        .onChange(of: draft.rawPath) { showsValidation = true }
        .fileImporter(isPresented: $isChoosingDirectory, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                draft.rawPath = appState.pathInspector.authoredForm(of: url)
            }
        }
    }

    private func save() {
        showsValidation = true
        if appState.savePathEntry(draft, replacing: request.entry?.id, scope: scope) {
            dismiss()
        }
    }
}

#Preview {
    PathEntryEditor(request: .new)
        .environment(AppState(store: InMemoryConfigurationStore()))
}
