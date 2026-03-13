import SwiftUI

struct GoalsView: View {
    let current: NutritionGoal
    let onSave: (NutritionGoal) -> Void

    @State private var kcalText: String
    @State private var proteinsText: String
    @State private var carbsText: String
    @State private var fatText: String
    @State private var sugarsText: String
    @State private var saltText: String

    @Environment(\.dismiss) private var dismiss

    init(current: NutritionGoal, onSave: @escaping (NutritionGoal) -> Void) {
        self.current = current
        self.onSave = onSave
        _kcalText = State(initialValue: current.kcal.map { String(Int($0)) } ?? "")
        _proteinsText = State(initialValue: current.proteins.map { String(Int($0)) } ?? "")
        _carbsText = State(initialValue: current.carbs.map { String(Int($0)) } ?? "")
        _fatText = State(initialValue: current.fat.map { String(Int($0)) } ?? "")
        _sugarsText = State(initialValue: current.sugars.map { String(Int($0)) } ?? "")
        _saltText = State(initialValue: current.salt.map { String(Int($0)) } ?? "")
    }

    private func parseGoal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    private var goal: NutritionGoal {
        NutritionGoal(
            kcal: parseGoal(kcalText),
            proteins: parseGoal(proteinsText),
            carbs: parseGoal(carbsText),
            fat: parseGoal(fatText),
            sugars: parseGoal(sugarsText),
            salt: parseGoal(saltText)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Hero kcal card
                VStack(spacing: 12) {
                    Text("CALORIES")
                        .font(.kcLabel)
                        .foregroundStyle(Color.kcWolf)
                        .kerning(Theme.labelKerning)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        KcNumericField(placeholder: "2000", text: $kcalText, font: .kcNumberLarge, color: .kcFeather, width: 110, decimals: false)

                        Text("kcal")
                            .font(.kcSecondary)
                            .foregroundStyle(Color.kcWolf)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .kcCard()

                // MARK: - Macros grid
                Text("MACRONUTRIMENTS")
                    .font(.kcLabel)
                    .foregroundStyle(Color.kcWolf)
                    .kerning(Theme.labelKerning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    MacroCard(label: "Protéines", unit: "g", text: $proteinsText, color: .kcCardinal)
                    MacroCard(label: "Glucides", unit: "g", text: $carbsText, color: .kcMacaw)
                    MacroCard(label: "Lipides", unit: "g", text: $fatText, color: .kcBee)
                    MacroCard(label: "Sucres", unit: "g", text: $sugarsText, color: .kcFox)
                    MacroCard(label: "Sel", unit: "g", text: $saltText, color: .kcHare)
                }

                // MARK: - Save
                KcPrimaryButton(label: "Enregistrer") {
                    onSave(goal)
                    dismiss()
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.top, Theme.horizontalPadding)
            .padding(.bottom, 32)
        }
        .background(Color.kcPolar)
        .navigationTitle("Objectifs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Macro card

private struct MacroCard: View {
    let label: String
    let unit: String
    @Binding var text: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: Theme.dotSize, height: Theme.dotSize)
                Text(label)
                    .font(.kcSmallLabel)
                    .foregroundStyle(Color.kcEel)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                KcNumericField(placeholder: "—", text: $text, font: .kcNumberSmall, width: 50, decimals: false)

                Text(unit)
                    .font(.kcUnit)
                    .foregroundStyle(Color.kcWolf)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .kcCard(radius: Theme.cornerRadiusL)
    }
}
