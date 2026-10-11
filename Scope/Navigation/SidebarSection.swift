//
//  SidebarSection.swift
//  Scope
//
//  Sidebar grouping from Design/03_Information_Architecture.md.
//

import Foundation

enum SidebarSection: CaseIterable, Identifiable {
    case configuration
    case scopes
    case sync
    case utilities

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .configuration: "Configuration"
        case .scopes: "Where It Applies"
        case .sync: "Sync"
        case .utilities: "Utilities"
        }
    }

    var items: [SidebarItem] {
        SidebarItem.allCases.filter { $0.section == self }
    }
}
