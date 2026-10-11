//
//  DetailView.swift
//  Scope
//
//  Routes a sidebar item to its screen. Screens not yet built show a placeholder
//  (see the implementation order in Design/11_AI_Coding_Assistant_Brief.md).
//

import SwiftUI

struct DetailView: View {
    let item: SidebarItem

    var body: some View {
        Group {
            switch item {
            case .environment:
                EnvironmentView()
            case .path:
                PathView()
            case .aliases:
                AliasView()
            case .functions:
                FunctionsView()
            case .generated:
                GeneratedConfigView()
            case .diagnostics:
                DiagnosticsView()
            case .profiles:
                ProfilesView()
            case .machines:
                MachinesView()
            case .icloud:
                SyncView()
            case .importConfig:
                ImportView()
            default:
                ComingSoonView(item: item)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
        .background(Theme.contentBackground)
        .navigationTitle(String(localized: item.title))
    }
}

#Preview {
    DetailView(item: .path)
        .environment(AppState(store: InMemoryConfigurationStore()))
}
