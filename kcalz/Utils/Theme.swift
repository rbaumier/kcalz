import SwiftUI

// MARK: - Couleurs — Palette Duolingo

extension Color {
    // Core
    static let kcFeather = Color(hex: 0x58CC02)
    static let kcWing = Color(hex: 0x43C000)
    static let kcMask = Color(hex: 0x89E219)

    // Secondary — touches only
    static let kcMacaw = Color(hex: 0x1CB0F6)
    static let kcCardinal = Color(hex: 0xFF4B4B)
    static let kcBee = Color(hex: 0xFFC800)
    static let kcFox = Color(hex: 0xFF9600)

    // Neutrals
    static let kcEel = Color(hex: 0x4B4B4B)
    static let kcWolf = Color(hex: 0x777777)
    static let kcHare = Color(hex: 0xAFAFAF)
    static let kcSwan = Color(hex: 0xE5E5E5)
    static let kcPolar = Color(hex: 0xF7F7F7)
    static let kcSnow = Color.white

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

// MARK: - Fonts — Bold & rounded like Duolingo

extension Font {
    static let kcTitle = Font.system(.largeTitle, design: .rounded, weight: .black)
    static let kcHeadline = Font.system(.title3, design: .rounded, weight: .heavy)
    static let kcSubheadline = Font.system(.subheadline, design: .rounded, weight: .heavy)
    static let kcBody = Font.system(.body, design: .rounded, weight: .bold)
    static let kcCaption = Font.system(.caption, design: .rounded, weight: .bold)
    static let kcNumber = Font.system(size: 40, weight: .black, design: .rounded)
    static let kcNumberMedium = Font.system(size: 30, weight: .black, design: .rounded)
    static let kcNumberSmall = Font.system(.body, design: .rounded, weight: .black)
}

// MARK: - Animations — smooth deceleration, no bounce

extension Animation {
    static let kcSmooth = Animation.easeOut(duration: 0.5)
    static let kcSnappy = Animation.easeOut(duration: 0.1)
    static func kcStagger(_ index: Int) -> Animation {
        .easeOut(duration: 0.4).delay(Double(index) * 0.06)
    }
}

// MARK: - Button Style — Duolingo 3D press via shadow

struct Kc3DButton: ButtonStyle {
    var shadow: Color = .kcWing
    var depth: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(color: shadow, radius: 0, x: 0, y: configuration.isPressed ? 0 : depth)
            .offset(y: configuration.isPressed ? depth : 0)
            .animation(.kcSnappy, value: configuration.isPressed)
    }
}
