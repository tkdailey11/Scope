//
//  ScopeLabel.swift
//  Scope
//

import SwiftUI

/// Shows where an item applies. Icon + text, so scope is never conveyed by color alone.
/// Profile and machine names are generic until those features exist (step 11).
struct ScopeLabel: View {
    let scope: ConfigurationScope

    var body: some View {
        switch scope {
        case .global: Label("Global", systemImage: "globe")
        case .profile: Label("Profile", systemImage: "person.crop.square")
        case .machine: Label("This Mac", systemImage: "laptopcomputer")
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        ScopeLabel(scope: .global)
        ScopeLabel(scope: .profile(UUID()))
        ScopeLabel(scope: .machine(UUID()))
    }
    .padding()
}
