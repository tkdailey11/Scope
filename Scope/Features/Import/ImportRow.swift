//
//  ImportRow.swift
//  Scope
//

import Foundation

struct ImportRow: Identifiable {
    var candidate: ImportCandidate
    var isSelected: Bool

    var id: UUID { candidate.id }
}
