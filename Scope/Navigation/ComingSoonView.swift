//
//  ComingSoonView.swift
//  Scope
//

import SwiftUI

struct ComingSoonView: View {
    let item: SidebarItem

    var body: some View {
        ContentUnavailableView(
            String(localized: item.title),
            systemImage: item.systemImage,
            description: Text(item.summary)
        )
    }
}

#Preview {
    ComingSoonView(item: .aliases)
}
