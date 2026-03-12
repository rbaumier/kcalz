import SwiftUI

// MARK: - Couleurs

extension Color {
    // Couleurs principales — palette vive style Duolingo
    static let kcPrimary = Color(hex: 0x58CC02)
    static let kcSecondary = Color(hex: 0x1CB0F6)
    static let kcAccent = Color(hex: 0xFF9600)
    static let kcDanger = Color(hex: 0xFF4B4B)

    // Nutriments — chaque macro a sa couleur
    static let kcKcal = Color(hex: 0xFF9600)
    static let kcProteins = Color(hex: 0xFF4B4B)
    static let kcCarbs = Color(hex: 0x1CB0F6)
    static let kcFat = Color(hex: 0xFFC800)
    static let kcSugars = Color(hex: 0xCE82FF)
    static let kcSalt = Color(hex: 0x78C800)

    // Surfaces
    static let kcBackground = Color(hex: 0xF7F7F7)
    static let kcCard = Color.white

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
    static let kcTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let kcHeadline = Font.system(.title2, design: .rounded, weight: .bold)
    static let kcSubheadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let kcBody = Font.system(.body, design: .rounded)
    static let kcCaption = Font.system(.caption, design: .rounded, weight: .medium)
    static let kcNumber = Font.system(.title, design: .rounded, weight: .heavy)
    static let kcNumberSmall = Font.system(.body, design: .rounded, weight: .bold)
}

// MARK: - Animations

extension Animation {
    static let kcBounce = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let kcSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
}

// MARK: - View Modifiers

struct KcCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.kcCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

struct KcBounceButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.kcBounce, value: configuration.isPressed)
    }
}

extension View {
    func kcCard() -> some View { modifier(KcCardModifier()) }
}
