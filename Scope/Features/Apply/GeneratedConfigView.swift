//
//  GeneratedConfigView.swift
//  Scope
//
//  Shows exactly what Apply will write to ~/.scope/generated.zsh, whether it is
//  valid, and lets the user apply it.
//

import SwiftUI

struct GeneratedConfigView: View {
    @Environment(AppState.self) private var appState
    @State private var preview: ConfigurationPreview?
    /// Bumped after Apply so the preview re-reads the file on disk.
    @State private var refreshCount = 0
    @State private var isTesting = false

    private struct RefreshKey: Equatable {
        var configuration: StoredConfiguration
        var count: Int
    }

    private var refreshKey: RefreshKey {
        RefreshKey(configuration: appState.configuration, count: refreshCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let preview {
                statusBar(for: preview)
                Divider()
                content(for: preview)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Test Configuration", systemImage: "testtube.2") { isTesting = true }
                    .help("Try the pending configuration in a temporary shell without applying it")
            }
            ToolbarItem {
                Button("Apply", systemImage: "checkmark.circle", action: apply)
                    .disabled(!canApply)
                    .help("Write the generated file and make sure your shell loads it")
            }
        }
        .sheet(isPresented: $isTesting) { TestConfigurationSheet() }
        .task(id: refreshKey) { preview = await appState.preview() }
    }

    private var needsApply: Bool {
        guard let preview else { return false }
        return preview.hasPendingChanges || preview.hookState != .installed
    }

    private var canApply: Bool {
        (preview?.canApply ?? false) && needsApply && !appState.isApplying
    }

    // MARK: - Status

    @ViewBuilder
    private func statusBar(for preview: ConfigurationPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let result = appState.applyResult {
                resultBanner(result)
            }
            if !preview.blockers.isEmpty {
                ForEach(preview.blockers, id: \.self) { blocker in
                    Label(blocker, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                }
                Text("Fix these before applying.").foregroundStyle(.secondary)
            } else if case .invalid(let diagnostics) = preview.syntax {
                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    Label(diagnostic.line.map { "Line \($0): \(diagnostic.message)" } ?? diagnostic.message,
                          systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                }
                Text("zsh rejected this output, so Apply is blocked.").foregroundStyle(.secondary)
            } else if preview.syntax == nil {
                Label("Couldn't run zsh to check the syntax, so Apply is blocked.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Label(preview.hasPendingChanges ? "Changes pending" : "Up to date",
                      systemImage: preview.hasPendingChanges ? "circle.dotted" : "checkmark.circle")
                    .foregroundStyle(preview.hasPendingChanges ? Theme.accent : .secondary)
                Label(hookDescription(preview.hookState),
                      systemImage: preview.hookState == .installed ? "link" : "link.badge.plus")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hookDescription(_ state: StartupHook.State?) -> String {
        state == .installed
            ? String(localized: "Your .zshrc loads this file.")
            : String(localized: "Apply will add a marked line to your .zshrc (a backup is made first).")
    }

    @ViewBuilder
    private func resultBanner(_ result: ApplyResultMessage) -> some View {
        HStack(alignment: .firstTextBaseline) {
            switch result {
            case .success(let outcome):
                Label(successText(outcome), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .failure(let error):
                Label(failureText(error), systemImage: "xmark.octagon.fill").foregroundStyle(.red)
            }
            Spacer()
            Button("Dismiss") { appState.dismissApplyResult() }.buttonStyle(.link)
        }
    }

    private func successText(_ outcome: ApplyOutcome) -> String {
        outcome.wroteGeneratedFile || outcome.installedHook
            ? String(localized: "Applied. Open a new terminal tab, or run `source ~/.zshrc`, to pick up the changes.")
            : String(localized: "Already up to date.")
    }

    private func failureText(_ error: ApplyError) -> String {
        switch error {
        case .blocked(let reasons): reasons.joined(separator: " ")
        case .syntaxInvalid: String(localized: "Not applied: zsh rejected the generated file.")
        case .validatorUnavailable(let reason): String(localized: "Not applied: couldn't check the syntax (\(reason)).")
        case .hookFailed(let reason): String(localized: "The generated file was written, but \(reason)")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for preview: ConfigurationPreview) -> some View {
        if let text = preview.text {
            ScrollView([.vertical, .horizontal]) {
                Text(text)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("Nothing to Show", systemImage: "doc.text",
                                   description: Text("The configuration can't be generated yet."))
        }
    }

    private func apply() {
        Task {
            await appState.apply()
            refreshCount += 1
        }
    }
}

#Preview {
    var configuration = StoredConfiguration()
    configuration.environment = [.init(name: "EDITOR", value: "nvim")]
    configuration.path = [.init(rawPath: "~/go/bin")]
    configuration.aliases = [.init(name: "gs", command: "git status")]
    let state = AppState(store: InMemoryConfigurationStore(configuration))
    return GeneratedConfigView()
        .environment(state)
        .task { await state.load() }
        .frame(width: 720, height: 460)
}
