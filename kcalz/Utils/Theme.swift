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
    static let kcNumberLarge = Font.system(size: 34, weight: .black, design: .rounded)
    static let kcNumberSmall = Font.system(.body, design: .rounded, weight: .black)

    /// 11pt heavy rounded — section labels (CONSOMMÉ, QUANTITÉ, RESTANTES)
    static let kcLabel = Font.system(size: 11, weight: .heavy, design: .rounded)
    /// 13pt heavy rounded — nutrient bar labels
    static let kcSmallLabel = Font.system(size: 13, weight: .heavy, design: .rounded)
    /// 13pt black rounded — nutrient bar values
    static let kcSmallNumber = Font.system(size: 13, weight: .black, design: .rounded)
    /// 12pt bold rounded — nutrient bar units, kcal suffix
    static let kcUnit = Font.system(size: 12, weight: .bold, design: .rounded)
    /// 14pt bold — icon buttons (chevrons)
    static let kcIcon = Font.system(size: 14, weight: .bold)
    /// 16pt bold — search/clear/plus icons
    static let kcIconMedium = Font.system(size: 16, weight: .bold)
    /// 28pt bold — empty state icons
    static let kcIconLarge = Font.system(size: 28, weight: .bold)
    /// 15pt heavy rounded — secondary values (goal suffix)
    static let kcSecondary = Font.system(size: 15, weight: .heavy, design: .rounded)
    /// 15pt bold rounded — empty state text
    static let kcEmptyText = Font.system(size: 15, weight: .bold, design: .rounded)
    /// 14pt bold rounded — grams badge in meal entries
    static let kcBadge = Font.system(size: 14, weight: .bold, design: .rounded)
}

// MARK: - Spacing & Layout tokens

enum Theme {
    static let cornerRadiusS: CGFloat = 12
    static let cornerRadiusM: CGFloat = 14
    static let cornerRadiusL: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20

    static let horizontalPadding: CGFloat = 16
    static let cardInnerPadding: CGFloat = 20

    static let buttonSize: CGFloat = 44
    static let dotSize: CGFloat = 10
    static let barHeight: CGFloat = 10
    static let ringSize: CGFloat = 130
    static let ringStroke: CGFloat = 12
    static let minBarWidth: CGFloat = 10

    static let labelKerning: CGFloat = 0.8
    static let ringLabelKerning: CGFloat = 0.6
}

// MARK: - Card style

extension View {
    func kcCard(radius: CGFloat = Theme.cornerRadiusXL) -> some View {
        self
            .background(Color.kcSnow)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
    }
}

// MARK: - Primary Button

struct KcPrimaryButton: View {
    let label: String
    var icon: String?
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.kcIconMedium)
                        .foregroundStyle(Color.kcSnow)
                }
                Text(label)
                    .font(.kcHeadline)
                    .foregroundStyle(Color.kcSnow)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.kcFeather)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL, style: .continuous))
        }
        .buttonStyle(Kc3DButton(shadow: .kcWing, depth: 5))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0)
        .scaleEffect(enabled ? 1 : 0.01)
        .offset(y: enabled ? 0 : 12)
        .rotationEffect(.degrees(enabled ? 0 : -2))
        .animation(.spring(duration: 0.3, bounce: 0.4), value: enabled)
    }
}

// MARK: - Numeric Input

struct KcNumericField: View {
    let placeholder: String
    @Binding var text: String
    var font: Font = .kcNumberMedium
    var color: Color = .kcEel
    var width: CGFloat = 100
    var decimals: Bool = true

    var body: some View {
        TextField(placeholder, text: $text)
            .font(font)
            .foregroundStyle(color)
            .keyboardType(decimals ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .frame(width: width)
            .onChange(of: text) { _, new in
                let filtered: String
                if decimals {
                    var result = new.filter { "0123456789.,".contains($0) }
                        .replacingOccurrences(of: ",", with: ".")
                    // Keep only the first dot
                    if let firstDot = result.firstIndex(of: ".") {
                        let afterDot = result.index(after: firstDot)
                        if afterDot < result.endIndex {
                            result = String(result[..<afterDot]) + result[afterDot...].filter { $0 != "." }
                        }
                    }
                    filtered = result
                } else {
                    filtered = new.filter(\.isNumber)
                }
                if filtered != new { text = filtered }
            }
    }
}

// MARK: - Formatting

extension Double {
    var kcFormatted: String {
        truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(self))" : String(format: "%.1f", self)
    }
}

// MARK: - Animations — smooth deceleration, no bounce

extension Animation {
    static let kcSnappy = Animation.easeOut(duration: 0.1)
    static func kcStagger(_ index: Int) -> Animation {
        .easeOut(duration: 0.4).delay(Double(index) * 0.06)
    }
}

// MARK: - Button Style — Duolingo 3D press via shadow

struct Kc3DButton: ButtonStyle, Sendable {
    var shadow: Color = .kcWing
    var depth: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(color: shadow, radius: 0, x: 0, y: configuration.isPressed ? 0 : depth)
            .offset(y: configuration.isPressed ? depth : 0)
            .animation(.kcSnappy, value: configuration.isPressed)
    }
}
