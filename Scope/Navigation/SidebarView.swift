//
//  SidebarView.swift
//  Scope
//

import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarSection.allCases) { section in
                Section(String(localized: section.title)) {
                    ForEach(section.items) { item in
                        Label(String(localized: item.title), systemImage: item.systemImage)
                            .tag(item)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { SidebarHeader() }
        .navigationTitle("Scope")
    }
}

#Preview {
    SidebarView(selection: .constant(.overview))
        .frame(width: 230, height: 420)
}
