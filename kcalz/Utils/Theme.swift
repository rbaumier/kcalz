import SwiftUI

// MARK: - Couleurs — Palette Duolingo

/// Duolingo-inspired color palette for the entire app.
extension Color {
    // Core
    /// Duolingo green — primary action color (buttons, progress rings).
    static let kcFeather = Color(hex: 0x58CC02)
    /// Darker Duolingo green — 3D shadow beneath primary buttons.
    static let kcWing = Color(hex: 0x43C000)
    /// Bright lime green — active/highlighted accents.
    static let kcMask = Color(hex: 0x89E219)

    // Secondary — touches only
    /// Sky blue — informational badges, links.
    static let kcMacaw = Color(hex: 0x1CB0F6)
    /// Coral red — destructive actions, over-budget warnings.
    static let kcCardinal = Color(hex: 0xFF4B4B)
    /// Warm yellow — calorie ring, attention cues.
    static let kcBee = Color(hex: 0xFFC800)
    /// Orange — fat nutrient accent.
    static let kcFox = Color(hex: 0xFF9600)

    // Neutrals
    /// Dark grey — primary text color.
    static let kcEel = Color(hex: 0x4B4B4B)
    /// Medium grey — secondary/disabled text.
    static let kcWolf = Color(hex: 0x777777)
    /// Light grey — placeholder text, inactive controls.
    static let kcHare = Color(hex: 0xAFAFAF)
    /// Very light grey — card shadows, dividers.
    static let kcSwan = Color(hex: 0xE5E5E5)
    /// Near-white — page background.
    static let kcPolar = Color(hex: 0xF7F7F7)
    /// Pure white — card surfaces.
    static let kcSnow = Color.white

    /// Creates a color from a 24-bit hex value (e.g. `0xFF9600`).
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

/// Rounded, heavy typeface tokens matching Duolingo's playful style.
extension Font {
    /// 34pt black rounded — screen titles.
    static let kcTitle = Font.system(.largeTitle, design: .rounded, weight: .black)
    /// 20pt heavy rounded — section headings.
    static let kcHeadline = Font.system(.title3, design: .rounded, weight: .heavy)
    /// 15pt heavy rounded — sub-section headings.
    static let kcSubheadline = Font.system(.subheadline, design: .rounded, weight: .heavy)
    /// 17pt bold rounded — body text.
    static let kcBody = Font.system(.body, design: .rounded, weight: .bold)
    /// 12pt bold rounded — small captions.
    static let kcCaption = Font.system(.caption, design: .rounded, weight: .bold)
    /// 40pt black rounded — hero numeric display (daily total).
    static let kcNumber = Font.system(size: 40, weight: .black, design: .rounded)
    /// 30pt black rounded — mid-size numeric display.
    static let kcNumberMedium = Font.system(size: 30, weight: .black, design: .rounded)
    /// 34pt black rounded — large numeric display.
    static let kcNumberLarge = Font.system(size: 34, weight: .black, design: .rounded)
    /// Dynamic-size black rounded — inline numeric values.
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
    /// 16pt black rounded — inline kcal values in entry breakdown
    static let kcNumberInline = Font.system(size: 16, weight: .black, design: .rounded)
    /// 11pt bold rounded — compact macro pills in entry breakdown
    static let kcPill = Font.system(size: 11, weight: .bold, design: .rounded)
}

// MARK: - Spacing & Layout tokens

/// Shared spacing, sizing, and layout constants.
enum Theme {
    /// Small corner radius — pills, tags.
    static let cornerRadiusS: CGFloat = 12
    /// Medium corner radius — input fields.
    static let cornerRadiusM: CGFloat = 14
    /// Large corner radius — buttons.
    static let cornerRadiusL: CGFloat = 16
    /// Extra-large corner radius — cards.
    static let cornerRadiusXL: CGFloat = 20

    /// Standard horizontal padding for screen edges.
    static let horizontalPadding: CGFloat = 16
    /// Inner padding inside card surfaces.
    static let cardInnerPadding: CGFloat = 20

    /// Minimum touch-target size (44pt Apple HIG).
    static let buttonSize: CGFloat = 44
    /// Diameter of small indicator dots.
    static let dotSize: CGFloat = 10
    /// Height of nutrient progress bars.
    static let barHeight: CGFloat = 10
    /// Diameter of the main calorie ring.
    static let ringSize: CGFloat = 130
    /// Stroke width of the calorie ring.
    static let ringStroke: CGFloat = 12
    /// Minimum rendered width for nutrient bars so they stay visible.
    static let minBarWidth: CGFloat = 10

    /// Letter-spacing for uppercase section labels.
    static let labelKerning: CGFloat = 0.8
    /// Letter-spacing for ring nutrient labels.
    static let ringLabelKerning: CGFloat = 0.6
}

// MARK: - Card style

/// Duolingo-style card modifier (white surface + rounded corners + 3D shadow).
extension View {
    /// Applies the standard card appearance: white background, continuous corner radius,
    /// and a bottom shadow that creates the Duolingo signature 3D / embossed look.
    func kcCard(radius: CGFloat = Theme.cornerRadiusXL) -> some View {
        self
            .background(Color.kcSnow)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            // Flat y-offset shadow (no blur) mimics Duolingo's 3D "raised card" effect.
            .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
    }
}

// MARK: - Primary Button

/// Full-width green CTA button with a 3D press effect and pop-in animation.
struct KcPrimaryButton: View {
    /// Button label text.
    let label: String
    /// Optional SF Symbol name shown before the label.
    var icon: String?
    /// Controls visibility; the button pops in/out with a spring animation.
    var enabled: Bool = true
    /// Action triggered on tap.
    let action: () -> Void

    // Pop-in animation parameters (disabled → enabled transition).
    /// Near-zero scale so the button appears to grow from nothing.
    private static let popScale: CGFloat = 0.01
    /// Vertical offset so the button slides up while scaling in.
    private static let popOffset: CGFloat = 12
    /// Slight counter-clockwise tilt for a playful entrance.
    private static let popRotation: Double = -2

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
        .scaleEffect(enabled ? 1 : Self.popScale)
        .offset(y: enabled ? 0 : Self.popOffset)
        .rotationEffect(.degrees(enabled ? 0 : Self.popRotation))
        .animation(.spring(duration: 0.3, bounce: 0.4), value: enabled)
    }
}

// MARK: - Numeric Input

/// Decimal/integer text field with locale-safe input filtering.
struct KcNumericField: View {
    /// Placeholder text shown when the field is empty.
    let placeholder: String
    /// Bound text value (filtered to digits and optional decimal point).
    @Binding var text: String
    /// Font used for the numeric display.
    var font: Font = .kcNumberMedium
    /// Text color.
    var color: Color = .kcEel
    /// Fixed width of the field.
    var width: CGFloat = 100
    /// When `true`, allows a single decimal point; otherwise integers only.
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
                    // Accept digits, dots, and commas; normalise commas → dots for
                    // locales that use comma as decimal separator.
                    var result = new.filter { "0123456789.,".contains($0) }
                        .replacingOccurrences(of: ",", with: ".")
                    // Single-dot enforcement: after normalisation the string may
                    // contain multiple dots (e.g. user typed "1.2.3"). We keep only
                    // the first dot and strip all subsequent ones so the value stays
                    // parseable as a valid decimal number.
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

/// Convenience numeric formatting for display strings.
extension Double {
    /// Returns `"42"` for whole numbers, `"42.5"` for fractional — no trailing zeros.
    var kcFormatted: String {
        truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(self))" : String(format: "%.1f", self)
    }
}

// MARK: - Animations — smooth deceleration, no bounce

/// Shared animation presets.
extension Animation {
    /// Ultra-fast ease-out for instant feedback (button presses).
    static let kcSnappy = Animation.easeOut(duration: 0.1)
    /// Staggered ease-out — each successive item starts `0.06s` later for a cascade effect.
    static func kcStagger(_ index: Int) -> Animation {
        .easeOut(duration: 0.4).delay(Double(index) * 0.06)
    }
}

// MARK: - Button Style — Duolingo 3D press via shadow

/// Button style that fakes a 3D press by shifting a flat shadow on press.
struct Kc3DButton: ButtonStyle, Sendable {
    /// Color of the bottom shadow (usually the darker variant of the button color).
    var shadow: Color = .kcWing
    /// Shadow offset in points — controls perceived depth.
    var depth: CGFloat = 4

    /// Moves the label down and removes the shadow on press, creating a "push-in" illusion.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(color: shadow, radius: 0, x: 0, y: configuration.isPressed ? 0 : depth)
            .offset(y: configuration.isPressed ? depth : 0)
            .animation(.kcSnappy, value: configuration.isPressed)
    }
}
