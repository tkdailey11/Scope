//
//  ScopeApp.swift
//  Scope
//
//  Created by Tyler Dailey on 10/1/26.
//

import SwiftUI

@main
struct ScopeApp: App {
    @State private var appState: AppState
    @State private var sync: SyncCoordinator

    init() {
        let appState = AppState(store: JSONConfigurationStore(fileSystem: LocalFileSystem(), paths: ScopePaths()))
        _appState = State(initialValue: appState)
        _sync = State(initialValue: SyncCoordinator(
            appState: appState,
            transport: CloudKitSyncTransport(),
            stateStore: JSONSyncStateStore(fileSystem: LocalFileSystem(), paths: ScopePaths())
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(sync)
                .frame(minWidth: 800, minHeight: 520)
                .tint(Theme.accent)
                // Scope's design is dark-only (Design/05_Visual_Design_System.md).
                .preferredColorScheme(.dark)
                .task {
                    await appState.load()
                    await sync.load()
                }
                .onChange(of: appState.configuration) { sync.localChangesDidOccur() }
                .alert("Scope", isPresented: errorIsPresented, presenting: appState.errorMessage) { _ in
                    Button("OK") { appState.errorMessage = nil }
                } message: { message in
                    Text(message)
                }
        }
        .defaultSize(width: 1000, height: 680)
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { appState.errorMessage != nil }, set: { if !$0 { appState.errorMessage = nil } })
    }
}
