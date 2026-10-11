//
//  TestConfigurationSheet.swift
//  Scope
//
//  A compact terminal-like sheet backed by a temporary zsh. Closing it ends the
//  shell and deletes its files; nothing is applied.
//

import SwiftUI

@Observable
private final class TestShellModel {
    private(set) var transcript = ""
    private(set) var hasExited = false
    private(set) var failure: String?
    private let session = TestShellSession()
    private var reader: Task<Void, Never>?

    func start(with config: String) async {
        reader = Task { [session] in
            for await chunk in session.output { transcript += chunk }
            hasExited = true
        }
        do {
            try await session.start(pendingConfig: config)
        } catch {
            failure = String(localized: "Couldn't start zsh: \(error.localizedDescription)")
        }
    }

    func run(_ command: String) async {
        transcript += "% \(command)\n"
        await session.send(command)
    }

    func stop() async {
        await session.stop()
        reader?.cancel()
    }
}

struct TestConfigurationSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var model = TestShellModel()
    @State private var command = ""
    @State private var preview: ConfigurationPreview?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            banner
            Divider()
            terminal
            Divider()
            inputRow
        }
        .frame(minWidth: 640, minHeight: 420)
        .task {
            let preview = await appState.preview()
            self.preview = preview
            if let text = preview.text, preview.blockers.isEmpty {
                await model.start(with: text)
            }
            inputFocused = true
        }
        .onDisappear { Task { await model.stop() } }
    }

    private var canTest: Bool { preview?.text != nil && preview?.blockers.isEmpty == true }

    private var banner: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Test Configuration", systemImage: "testtube.2").font(.headline)
                Text("Temporary shell with your pending changes. Closing this window applies nothing and discards it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    @ViewBuilder
    private var terminal: some View {
        if preview == nil {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !canTest {
            ContentUnavailableView(
                "Can't Test Yet",
                systemImage: "exclamationmark.triangle",
                description: Text(preview?.blockers.joined(separator: "\n") ?? "Fix the problems shown in Generated Config first.")
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.transcript.isEmpty ? " " : model.transcript)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(height: 1).id("end")
                }
                .onChange(of: model.transcript) { proxy.scrollTo("end") }
            }
            .background(Theme.contentBackground.opacity(0.5))
        }
    }

    private var inputRow: some View {
        HStack {
            Text("%").font(.body.monospaced()).foregroundStyle(.secondary)
            TextField("Run a command", text: $command)
                .font(.body.monospaced())
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .focused($inputFocused)
                .onSubmit(submit)
                .disabled(!canTest || model.hasExited)
            if let failure = model.failure {
                Text(failure).foregroundStyle(.red)
            } else if model.hasExited {
                Text("Shell ended").foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func submit() {
        let text = command
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        command = ""
        Task { await model.run(text) }
    }
}
