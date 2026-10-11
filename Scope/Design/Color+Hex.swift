//
//  Color+Hex.swift
//  Scope
//

import SwiftUI

extension Color {
    /// `Color(hex: 0x3B82F6)`: sRGB, opaque.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
