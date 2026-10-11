//
//  ImportedItem+Display.swift
//  Scope
//

import Foundation

extension ImportedItem {
    var title: String {
        switch self {
        case .environment(let name, _, _), .alias(let name, _), .function(let name, _): name
        case .path(let raw): raw
        }
    }

    /// One-line value preview.
    var detail: String {
        switch self {
        case .environment(_, let value, _): value
        case .alias(_, let command): command
        case .function(_, let body): body.split(separator: "\n").first.map(String.init) ?? ""
        case .path: ""
        }
    }

    var kindTitle: String {
        switch self {
        case .environment: String(localized: "Environment")
        case .path: String(localized: "PATH")
        case .alias: String(localized: "Aliases")
        case .function: String(localized: "Functions")
        }
    }
}
