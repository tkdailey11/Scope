//
//  SidebarSection.swift
//  Scope
//
//  Sidebar grouping from Design/03_Information_Architecture.md.
//  Profiles, Machines and Sync sections arrive with their features.
//

import Foundation

enum SidebarSection: CaseIterable, Identifiable {
    case configuration
    case utilities

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .configuration: "Configuration"
        case .utilities: "Utilities"
        }
    }

    var items: [SidebarItem] {
        SidebarItem.allCases.filter { $0.section == self }
    }
}
