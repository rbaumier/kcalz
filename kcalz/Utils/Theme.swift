import SwiftUI

// MARK: - Couleurs

extension Color {
    // Primaires
    static let kcPrimary = Color(hex: 0x4BBF00)
    static let kcSecondary = Color(hex: 0x1DA8F0)
    static let kcAccent = Color(hex: 0xFF8C00)
    static let kcDanger = Color(hex: 0xF04848)

    // Nutriments
    static let kcKcal = Color(hex: 0xFF8C00)
    static let kcProteins = Color(hex: 0xF04848)
    static let kcCarbs = Color(hex: 0x1DA8F0)
    static let kcFat = Color(hex: 0xF0B800)
    static let kcSugars = Color(hex: 0xC070F0)
    static let kcSalt = Color(hex: 0x6DB800)

    // Surfaces — tinted, never pure
    static let kcBackground = Color(hex: 0xF5F3EF)
    static let kcSurface = Color(hex: 0xFFFDF8)
    static let kcSurfaceElevated = Color(hex: 0xFFFFFA)
    static let kcTextPrimary = Color(hex: 0x1A1812)
    static let kcTextSecondary = Color(hex: 0x8A857A)
    static let kcDivider = Color(hex: 0xE8E4DC)

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Fonts

extension Font {
    static let kcTitle = Font.system(.largeTitle, design: .rounded, weight: .black)
    static let kcHeadline = Font.system(.title3, design: .rounded, weight: .bold)
    static let kcSubheadline = Font.system(.subheadline, design: .rounded, weight: .semibold)
    static let kcBody = Font.system(.body, design: .rounded)
    static let kcCaption = Font.system(.caption, design: .rounded, weight: .medium)
    static let kcNumber = Font.system(.largeTitle, design: .rounded, weight: .black)
    static let kcNumberMedium = Font.system(.title2, design: .rounded, weight: .heavy)
    static let kcNumberSmall = Font.system(.subheadline, design: .rounded, weight: .bold)
}

// MARK: - Animations — smooth deceleration, no bounce

extension Animation {
    static let kcSmooth = Animation.easeOut(duration: 0.5)
    static let kcSnappy = Animation.easeOut(duration: 0.25)
    static func kcStagger(_ index: Int) -> Animation {
        .easeOut(duration: 0.4).delay(Double(index) * 0.06)
    }
}

// MARK: - View Modifiers

struct KcSectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
    }
}

struct KcPressable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.kcSnappy, value: configuration.isPressed)
    }
}

extension View {
    func kcSection() -> some View { modifier(KcSectionModifier()) }
}
