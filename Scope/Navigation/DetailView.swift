//
//  DetailView.swift
//  Scope
//
//  Routes a sidebar item to its screen. Screens are placeholders until
//  their implementation steps (Design/11_AI_Coding_Assistant_Brief.md).
//

import SwiftUI

struct DetailView: View {
    let item: SidebarItem

    var body: some View {
        ContentUnavailableView(
            String(localized: item.title),
            systemImage: item.systemImage,
            description: Text(item.summary)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.contentBackground)
        .navigationTitle(String(localized: item.title))
    }
}

#Preview {
    DetailView(item: .environment)
}
