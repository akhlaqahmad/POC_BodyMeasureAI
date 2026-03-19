//
//  DesignSystem.swift
//  BodyMeasureAI
//
//  Clean / Minimal / Premium fashion design system. Light + Dark.
//

import SwiftUI

// MARK: - Typography
struct SFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .custom("Georgia", size: size).weight(weight)
    }
    static func heading(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}

// MARK: - Spacing
struct SSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius
struct SRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 12
    static let lg: CGFloat = 20
    static let pill: CGFloat = 100
}

// MARK: - Shadow helpers
extension View {
    func softShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    func mediumShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.10), radius: 20, x: 0, y: 8)
    }
}

// Color assets are referenced via `Color("sBackground")` etc. to avoid
// any ambiguity with other `Color` extensions from frameworks.
