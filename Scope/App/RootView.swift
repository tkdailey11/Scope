//
//  RootView.swift
//  Scope
//

import SwiftUI

struct RootView: View {
    @State private var selection: SidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            if let selection {
                DetailView(item: selection)
            } else {
                ContentUnavailableView("Select a Section", systemImage: "sidebar.left")
            }
        }
        .background(Theme.windowBackground)
    }
}

#Preview {
    RootView()
}
