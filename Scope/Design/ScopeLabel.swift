//
//  ScopeLabel.swift
//  Scope
//

import SwiftUI

/// Shows where an item applies. Icon + text, so scope is never conveyed by color alone.
struct ScopeLabel: View {
    let scope: ConfigurationScope

    @Environment(AppState.self) private var appState

    var body: some View {
        Label(appState.name(of: scope), systemImage: systemImage)
    }

    private var systemImage: String {
        switch scope {
        case .global: "globe"
        case .profile: "person.crop.square"
        case .machine: "laptopcomputer"
        }
    }
}

/// Chooses where a new item applies. Existing items keep their scope, so it is shown read-only there.
struct ScopePicker: View {
    @Binding var scope: ConfigurationScope
    var isEditable = true

    @Environment(AppState.self) private var appState

    var body: some View {
        if isEditable {
            Picker("Applies to", selection: $scope) {
                ForEach(appState.availableScopes, id: \.self) { scope in
                    ScopeLabel(scope: scope).tag(scope)
                }
            }
        } else {
            LabeledContent("Applies to") { ScopeLabel(scope: scope) }
        }
    }
}

#Preview {
    let profile = Profile(name: "Work")
    var configuration = StoredConfiguration()
    configuration.profiles = [profile]
    return VStack(alignment: .leading) {
        ScopeLabel(scope: .global)
        ScopeLabel(scope: .profile(profile.id))
        ScopeLabel(scope: .machine(UUID()))
    }
    .padding()
    .environment(AppState(store: InMemoryConfigurationStore(configuration)))
}
