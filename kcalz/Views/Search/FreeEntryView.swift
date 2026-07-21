import SwiftUI

/// Free-entry form — logs a portion by typing its grams and macros directly,
/// without selecting a food. Calories are derived live from the macros (Atwater
/// factors) and the portion is stored as a standard per-100g `FoodEntry`.
struct FreeEntryView: View {
    let onSave: (FoodEntry) -> Void

    @State private var nameText = ""
    @State private var gramsText = "100"
    @State private var proteinsText = ""
    @State private var carbsText = ""
    @State private var fatText = ""

    /// Fallback entry name when the name field is left blank.
    private static let defaultName = "Saisie libre"

    /// Portion weight in grams, `0` when the field is empty or invalid.
    private var grams: Double { Double(gramsText) ?? 0 }
    /// Portion proteins in grams, `0` when the field is empty.
    private var proteins: Double { Double(proteinsText) ?? 0 }
    /// Portion carbs in grams, `0` when the field is empty.
    private var carbs: Double { Double(carbsText) ?? 0 }
    /// Portion fat in grams, `0` when the field is empty.
    private var fat: Double { Double(fatText) ?? 0 }

    /// Live portion calories from the Atwater factors (4/4/9).
    private var kcal: Double { 4 * proteins + 4 * carbs + 9 * fat }

    /// Enabled once a positive weight and at least one positive macro are entered.
    private var isValid: Bool { grams > 0 && (proteins > 0 || carbs > 0 || fat > 0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOM")
                        .font(.kcLabel)
                        .foregroundStyle(Color.kcWolf)
                        .kerning(Theme.labelKerning)

                    TextField(Self.defaultName, text: $nameText)
                        .font(.kcBody)
                        .padding(.horizontal, Theme.cardInnerPadding)
                        .padding(.vertical, 14)
                        .kcCard(radius: Theme.cornerRadiusM)
                }
                .padding(.horizontal, Theme.cardInnerPadding)
                .padding(.top, Theme.horizontalPadding)

                // Grams
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUANTITÉ")
                        .font(.kcLabel)
                        .foregroundStyle(Color.kcWolf)
                        .kerning(Theme.labelKerning)

                    HStack(spacing: 8) {
                        KcNumericField(placeholder: "100", text: $gramsText)
                            .padding(.vertical, 12)
                            .kcCard(radius: Theme.cornerRadiusM)

                        Text("grammes")
                            .font(.kcBody)
                            .foregroundStyle(Color.kcWolf)
                    }
                }
                .padding(.horizontal, Theme.cardInnerPadding)

                // Macros (absolute values for the portion)
                VStack(alignment: .leading, spacing: 8) {
                    Text("MACROS DE LA PORTION")
                        .font(.kcLabel)
                        .foregroundStyle(Color.kcWolf)
                        .kerning(Theme.labelKerning)
                        .padding(.horizontal, Theme.cardInnerPadding)

                    VStack(spacing: 0) {
                        EditableNutrientRow(label: "Protéines", unit: "g", text: $proteinsText, color: .kcCardinal)
                        EditableNutrientRow(label: "Glucides", unit: "g", text: $carbsText, color: .kcMacaw)
                        EditableNutrientRow(label: "Lipides", unit: "g", text: $fatText, color: .kcBee)
                    }
                    .kcCard()
                    .padding(.horizontal, Theme.horizontalPadding)
                }

                // Calories — computed live from the macros, not editable.
                HStack {
                    Text("Calories")
                        .font(.kcBody)
                        .foregroundStyle(Color.kcEel)
                    Spacer()
                    Text("\(Int(kcal))")
                        .font(.kcNumberMedium)
                        .foregroundStyle(Color.kcFeather)
                    Text("kcal")
                        .font(.kcUnit)
                        .foregroundStyle(Color.kcWolf)
                }
                .padding(.horizontal, Theme.cardInnerPadding)
                .padding(.vertical, 14)
                .kcCard()
                .padding(.horizontal, Theme.horizontalPadding)
                .accessibilityElement(children: .combine)

                // Add
                KcPrimaryButton(label: "Ajouter", icon: "plus", enabled: isValid) {
                    onSave(makeEntry())
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .background(Color.kcPolar)
        .navigationTitle("Saisie libre")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Builds a per-100g `FoodEntry` from the absolute portion values.
    /// `grams > 0` is guaranteed by `isValid` before the button can fire, so the
    /// scaling never divides by zero; `kcalPer100g` restores exactly the live kcal.
    private func makeEntry() -> FoodEntry {
        let trimmedName = nameText.trimmingCharacters(in: .whitespaces)
        let scale = FoodEntry.per100gBase / grams
        return FoodEntry(
            name: trimmedName.isEmpty ? Self.defaultName : trimmedName,
            grams: grams,
            kcalPer100g: kcal * scale,
            proteinsPer100g: proteins * scale,
            carbsPer100g: carbs * scale,
            fatPer100g: fat * scale
        )
    }
}

#Preview {
    NavigationStack {
        FreeEntryView { _ in }
    }
}
