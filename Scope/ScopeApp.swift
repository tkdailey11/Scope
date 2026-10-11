//
//  ScopeApp.swift
//  Scope
//
//  Created by Tyler Dailey on 10/1/26.
//

import SwiftUI

@main
struct ScopeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 800, minHeight: 520)
                .tint(Theme.accent)
                // Scope's design is dark-only (Design/05_Visual_Design_System.md).
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1000, height: 680)
    }
}
