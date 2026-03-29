import SwiftUI

// MARK: - Adaptive color helper

private extension UIColor {
    /// Convenience: create an adaptive UIColor from two hex strings.
    static func adaptive(dark: String, light: String) -> UIColor {
        UIColor(dynamicProvider: { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }

    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, alpha: Double(a)/255)
    }
}

// MARK: - Colors

extension Color {
    // ── Adaptive backgrounds ────────────────────────────────────────────────
    /// Main page background
    static let claroBg = Color(uiColor: .adaptive(dark: "#0D1117", light: "#F0F4F8"))
    /// Card / surface background
    static let claroCard = Color(uiColor: .adaptive(dark: "#161B22", light: "#FFFFFF"))
    /// Subtle card border
    static let claroCardBorder = Color(uiColor: .adaptive(
        dark: "#FFFFFF14",   // white 8%
        light: "#00000014"   // black 8%
    ))

    // ── Adaptive text ───────────────────────────────────────────────────────
    static let claroTextPrimary   = Color(uiColor: .adaptive(dark: "#F1F5F9", light: "#0F172A"))
    static let claroTextSecondary = Color(uiColor: .adaptive(dark: "#94A3B8", light: "#475569"))
    static let claroTextMuted     = Color(uiColor: .adaptive(dark: "#64748B", light: "#94A3B8"))

    // ── Accent colors (same in both modes) ─────────────────────────────────
    static let claroViolet      = Color(hex: "#7C3AED")
    static let claroVioletLight = Color(hex: "#A78BFA")
    static let claroCyan        = Color(hex: "#06B6D4")
    static let claroGold        = Color(hex: "#F59E0B")

    // ── Semantic ────────────────────────────────────────────────────────────
    static let claroSuccess = Color(hex: "#10B981")
    static let claroDanger  = Color(hex: "#EF4444")
    static let claroWarning = Color(hex: "#F59E0B")

    // ── Hex initialiser (SwiftUI Color) ─────────────────────────────────────
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Typography

extension Font {
    static func claroLargeTitle() -> Font { .system(size: 34, weight: .black,    design: .rounded) }
    static func claroTitle()      -> Font { .system(size: 22, weight: .bold,     design: .rounded) }
    static func claroTitle2()     -> Font { .system(size: 18, weight: .bold,     design: .rounded) }
    static func claroHeadline()   -> Font { .system(size: 15, weight: .semibold) }
    static func claroBody()       -> Font { .system(size: 14, weight: .regular)  }
    static func claroCaption()    -> Font { .system(size: 11, weight: .medium)   }
    static func claroLabel()      -> Font { .system(size: 10, weight: .semibold) }
}

// MARK: - Spacing

enum ClaroSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 14
    static let lg:  CGFloat = 20
    static let xl:  CGFloat = 28
    static let xxl: CGFloat = 40
}

// MARK: - Corner Radii

enum ClaroRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 30
}

// MARK: - Shadows

extension View {
    func claroCardShadow() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    }

    func claroGlowShadow(color: Color = .claroViolet) -> some View {
        self.shadow(color: color.opacity(0.45), radius: 20, x: 0, y: 8)
    }
}
