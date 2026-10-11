//
//  SidebarItem.swift
//  Scope
//

import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview
    case environment
    case path
    case aliases
    case functions
    case profiles
    case machines
    case diagnostics
    case backups

    var id: Self { self }

    var section: SidebarSection {
        switch self {
        case .overview, .environment, .path, .aliases, .functions: .configuration
        case .profiles, .machines: .scopes
        case .diagnostics, .backups: .utilities
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .overview: "Overview"
        case .environment: "Environment"
        case .path: "PATH"
        case .aliases: "Aliases"
        case .functions: "Functions"
        case .profiles: "Profiles"
        case .machines: "Machines"
        case .diagnostics: "Diagnostics"
        case .backups: "Backups"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .environment: "list.bullet.rectangle"
        case .path: "arrow.triangle.branch"
        case .aliases: "arrowshape.turn.up.right"
        case .functions: "curlybraces"
        case .profiles: "person.crop.square.stack"
        case .machines: "laptopcomputer"
        case .diagnostics: "stethoscope"
        case .backups: "clock.arrow.circlepath"
        }
    }

    /// One-line explanation shown until the real screen is built.
    var summary: LocalizedStringResource {
        switch self {
        case .overview: "Status, counts and quick actions for your shell configuration."
        case .environment: "Environment variables exported by your shell."
        case .path: "An ordered list of directories added to PATH."
        case .aliases: "Short names that expand to longer commands."
        case .functions: "Reusable shell functions."
        case .profiles: "Named sets of configuration, like Work and Personal."
        case .machines: "Configuration that applies only to one Mac."
        case .diagnostics: "Find out why your configuration isn't working."
        case .backups: "Restore files Scope has backed up."
        }
    }
}
