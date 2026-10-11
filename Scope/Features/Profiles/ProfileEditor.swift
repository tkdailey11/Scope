//
//  ProfileEditor.swift
//  Scope
//

import SwiftUI

struct ProfileEditor: View {
    static let icons = ["person.crop.square", "briefcase", "house", "laptopcomputer", "hammer", "graduationcap", "gamecontroller", "shippingbox"]
    static let defaultIcon = icons[0]

    let request: ProfileEditorRequest

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var iconName: String
    /// Validation messages stay hidden until the first edit or save attempt, so a blank form isn't shouting.
    @State private var showsValidation = false

    init(request: ProfileEditorRequest) {
        self.request = request
        _name = State(initialValue: request.profile?.name ?? "")
        _iconName = State(initialValue: request.profile?.iconName ?? Self.defaultIcon)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var nameIssue: String? {
        if trimmedName.isEmpty { return String(localized: "Enter a name.") }
        if appState.profileNames(excluding: request.profile?.id).contains(trimmedName.lowercased()) {
            return String(localized: "A profile named “\(trimmedName)” already exists.")
        }
        return nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name, prompt: Text("Work"))
                    .autocorrectionDisabled()
                IssueText(message: showsValidation ? nameIssue : nil)

                Picker("Icon", selection: $iconName) {
                    ForEach(Self.icons, id: \.self) { icon in
                        Image(systemName: icon).tag(icon).accessibilityLabel(icon)
                    }
                }
                .pickerStyle(.palette)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 200)
        .navigationTitle(request.profile == nil ? "Add Profile" : "Edit Profile")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(showsValidation && nameIssue != nil)
            }
        }
        .onChange(of: name) { showsValidation = true }
    }

    private func save() {
        showsValidation = true
        if appState.saveProfile(name: name, iconName: iconName, replacing: request.profile?.id) != nil {
            dismiss()
        }
    }
}

#Preview {
    ProfileEditor(request: .new)
        .environment(AppState(store: InMemoryConfigurationStore()))
}
