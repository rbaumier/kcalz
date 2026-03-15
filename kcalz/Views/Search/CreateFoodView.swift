import SwiftUI

struct CreateFoodView: View {
    let userStore: UserStore
    let onCreated: (UserStore.ProductOverride) -> Void

    @State private var name: String
    @State private var kcalText = ""
    @State private var proteinsText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var fiberText = ""

    init(initialName: String, userStore: UserStore, onCreated: @escaping (UserStore.ProductOverride) -> Void) {
        _name = State(initialValue: initialName)
        self.userStore = userStore
        self.onCreated = onCreated
    }

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
                        NutrientInputRow(label: "Calories", unit: "kcal", text: $kcalText, color: .kcFeather, required: true)
                        NutrientInputRow(label: "Protéines", unit: "g", text: $proteinsText, color: .kcCardinal)
                        NutrientInputRow(label: "Glucides", unit: "g", text: $carbsText, color: .kcMacaw)
                        NutrientInputRow(label: "Lipides", unit: "g", text: $fatText, color: .kcBee)
                        NutrientInputRow(label: "Fibres", unit: "g", text: $fiberText, color: .kcHare)
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

private struct NutrientInputRow: View {
    let label: String
    let unit: String
    @Binding var text: String
    let color: Color
    var required: Bool = false

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: Theme.dotSize, height: Theme.dotSize)

            Text(label)
                .font(.kcBody)
                .foregroundStyle(Color.kcEel)

            if required {
                Text("*")
                    .font(.kcBody)
                    .foregroundStyle(Color.kcCardinal)
            }

            Spacer()

            KcNumericField(placeholder: "0", text: $text, font: .kcNumberSmall, width: 70)

            Text(unit)
                .font(.kcCaption)
                .foregroundStyle(Color.kcWolf)
                .frame(width: 30, alignment: .leading)
        }
        .padding(.horizontal, Theme.cardInnerPadding)
        .padding(.vertical, 12)
    }
}
