import SwiftUI

/// Free-entry form — logs a portion by typing its grams, calories, and macros
/// directly, without selecting a food. A segmented toggle switches whether the
/// entered values read per 100 g or for the whole portion; the entry is always
/// stored as a standard per-100g `FoodEntry`.
struct FreeEntryView: View {
    let mealBaseKcal: Double
    let dayBaseKcal: Double
    let goalKcal: Double?
    let onSave: (FoodEntry) -> Void

    @State private var nameText = ""
    @State private var gramsText = "100"
    @State private var kcalText = ""
    @State private var proteinsText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    /// Whether the entered nutrient values read as per-100g (`true`) or for the
    /// whole portion. Switching reinterprets the typed numbers — it never converts them.
    @State private var isPer100g = true
    @FocusState private var isNameFocused: Bool

    /// Fallback entry name when the name field is left blank.
    private static let defaultName = "Saisie libre"

    /// Portion weight in grams, `0` when the field is empty or invalid.
    private var grams: Double { Double(gramsText) ?? 0 }
    /// Entered calories (per the selected reference), `0` when the field is empty.
    private var kcalValue: Double { Double(kcalText) ?? 0 }
    /// Entered proteins in grams (per the selected reference), `0` when the field is empty.
    private var proteins: Double { Double(proteinsText) ?? 0 }
    /// Entered carbs in grams (per the selected reference), `0` when the field is empty.
    private var carbs: Double { Double(carbsText) ?? 0 }
    /// Entered fat in grams (per the selected reference), `0` when the field is empty.
    private var fat: Double { Double(fatText) ?? 0 }

    /// Calories of the actual portion, whichever reference is selected.
    private var portionKcal: Double { isPer100g ? kcalValue * grams / FoodEntry.per100gBase : kcalValue }

    /// Enabled once a positive weight and positive calories are entered.
    private var isValid: Bool { grams > 0 && kcalValue > 0 }

    /// Calorie equivalent in the other reference, e.g. "soit 450 kcal pour 250 g".
    /// `nil` while the conversion has no meaning (no calories or no weight yet).
    private var conversionHint: String? {
        guard kcalValue > 0, grams > 0 else { return nil }
        if isPer100g {
            return "soit \(Int(portionKcal.rounded())) kcal pour \(grams.kcFormatted) g"
        }
        return "soit \(Int((kcalValue * FoodEntry.per100gBase / grams).rounded())) kcal / 100 g"
    }

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
                        .focused($isNameFocused)
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

                // Nutrients — reference toggle + editable calories and macros
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        segment("Pour 100 g", isActive: isPer100g) { isPer100g = true }
                        segment("Au total", isActive: !isPer100g) { isPer100g = false }
                    }
                    .padding(4)
                    .kcCard(radius: Theme.cornerRadiusM)
                    .padding(.horizontal, Theme.horizontalPadding)

                    VStack(spacing: 0) {
                        EditableNutrientRow(label: "Calories", unit: "kcal", text: $kcalText, color: .kcFeather, required: true)
                        EditableNutrientRow(label: "Protéines", unit: "g", text: $proteinsText, color: .kcCardinal)
                        EditableNutrientRow(label: "Glucides", unit: "g", text: $carbsText, color: .kcMacaw)
                        EditableNutrientRow(label: "Lipides", unit: "g", text: $fatText, color: .kcBee)
                    }
                    .kcCard()
                    .padding(.horizontal, Theme.horizontalPadding)

                    if let conversionHint {
                        Text(conversionHint)
                            .font(.kcCaption)
                            .foregroundStyle(Color.kcHare)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Projected totals — meal + day including this portion's calories.
                ProjectedTotalsRow(mealKcal: mealBaseKcal + portionKcal, dayKcal: dayBaseKcal + portionKcal, goalKcal: goalKcal)
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.top, 8)

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
        .task {
            isNameFocused = true
        }
    }

    /// One half of the reference toggle — filled green with the 3D shadow when active.
    private func segment(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.kcSubheadline)
                .foregroundStyle(isActive ? Color.kcSnow : Color.kcWolf)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isActive ? Color.kcFeather : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: isActive ? Color.kcWing : .clear, radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    /// Builds a per-100g `FoodEntry` from the entered values; in "total" mode they
    /// are scaled down by the portion weight first. `grams > 0` is guaranteed by
    /// `isValid` before the button can fire, so the scaling never divides by zero.
    private func makeEntry() -> FoodEntry {
        let trimmedName = nameText.trimmingCharacters(in: .whitespaces)
        let scale = isPer100g ? 1 : FoodEntry.per100gBase / grams
        return FoodEntry(
            name: trimmedName.isEmpty ? Self.defaultName : trimmedName,
            grams: grams,
            kcalPer100g: kcalValue * scale,
            proteinsPer100g: proteins * scale,
            carbsPer100g: carbs * scale,
            fatPer100g: fat * scale
        )
    }
}

#Preview {
    NavigationStack {
        FreeEntryView(mealBaseKcal: 500, dayBaseKcal: 1200, goalKcal: 2000) { _ in }
    }
}
