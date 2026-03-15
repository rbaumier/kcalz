import SwiftUI

/// Form for creating a custom food with name and per-100g nutrient values.
struct CreateFoodView: View {
    let userStore: UserStore
    let onCreated: (UserStore.ProductOverride) -> Void

    @State private var name: String
    @State private var kcalText = ""
    @State private var proteinsText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var fiberText = ""

    /// Creates the view with a pre-filled name and persistence dependencies.
    init(initialName: String, userStore: UserStore, onCreated: @escaping (UserStore.ProductOverride) -> Void) {
        _name = State(initialValue: initialName)
        self.userStore = userStore
        self.onCreated = onCreated
    }

    /// Returns `true` when the form has a non-empty name and a valid kcal value.
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Double(kcalText) != nil
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

                    TextField("Nom de l'aliment", text: $name)
                        .font(.kcBody)
                        .padding(.horizontal, Theme.cardInnerPadding)
                        .padding(.vertical, 14)
                        .kcCard(radius: Theme.cornerRadiusM)
                }
                .padding(.horizontal, Theme.cardInnerPadding)
                .padding(.top, Theme.horizontalPadding)

                // Nutrients
                VStack(alignment: .leading, spacing: 8) {
                    Text("NUTRIMENTS POUR 100G")
                        .font(.kcLabel)
                        .foregroundStyle(Color.kcWolf)
                        .kerning(Theme.labelKerning)
                        .padding(.horizontal, Theme.cardInnerPadding)

                    VStack(spacing: 0) {
                        EditableNutrientRow(label: "Calories", unit: "kcal", text: $kcalText, color: .kcFeather, required: true)
                        EditableNutrientRow(label: "Protéines", unit: "g", text: $proteinsText, color: .kcCardinal)
                        EditableNutrientRow(label: "Glucides", unit: "g", text: $carbsText, color: .kcMacaw)
                        EditableNutrientRow(label: "Lipides", unit: "g", text: $fatText, color: .kcBee)
                        EditableNutrientRow(label: "Fibres", unit: "g", text: $fiberText, color: .kcHare)
                    }
                    .kcCard()
                    .padding(.horizontal, Theme.horizontalPadding)
                }

                // Create button
                KcPrimaryButton(label: "Créer", icon: "plus", enabled: isValid) {
                    let override = userStore.saveCustomFood(
                        name: name.trimmingCharacters(in: .whitespaces),
                        kcal: Double(kcalText) ?? 0,
                        proteins: Double(proteinsText),
                        carbs: Double(carbsText),
                        fat: Double(fatText),
                        fiber: Double(fiberText)
                    )
                    onCreated(override)
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .background(Color.kcPolar)
        .navigationTitle("Créer un aliment")
        .navigationBarTitleDisplayMode(.inline)
    }
}
