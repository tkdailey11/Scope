//
//  Theme.swift
//  Scope
//
//  Shared design tokens. See Design/05_Visual_Design_System.md.
//  Values are tuned by eye; the doc's palette is a reference, not a standard.
//

import SwiftUI

enum Theme {
    // Brand accents
    static let cyan = Color(hex: 0x00D1FF)
    static let blue = Color(hex: 0x3B82F6)
    static let violet = Color(hex: 0xA855F7)

    // Surfaces: deep navy window, slightly lighter content field.
    static let windowBackground = Color(hex: 0x0B1F36)
    static let contentBackground = Color(hex: 0x102A47)
    static let cardBackground = Color(hex: 0x16355A)

    /// Default tint for selection and controls.
    static let accent = blue

    // Shape
    static let cardRadius: CGFloat = 12
}
