import SwiftUI

struct ProductDetailView: View {
    @State private var viewModel: ProductDetailViewModel
    let onSave: (FoodEntry) -> Void
    var onDelete: (() -> Void)?
    private let userStore: UserStore?

    init(product: OFFProduct, userStore: UserStore, onSave: @escaping (FoodEntry) -> Void) {
        let override = userStore.loadProductOverride(code: product.code)
        _viewModel = State(initialValue: ProductDetailViewModel(product: product, override: override))
        self.onSave = onSave
        self.onDelete = nil
        self.userStore = userStore
    }

    init(recentEntry: FoodEntry, onSave: @escaping (FoodEntry) -> Void) {
        _viewModel = State(initialValue: ProductDetailViewModel(recentEntry: recentEntry))
        self.onSave = onSave
        self.onDelete = nil
        self.userStore = nil
    }

    init(entry: FoodEntry, onSave: @escaping (FoodEntry) -> Void, onDelete: @escaping () -> Void) {
        _viewModel = State(initialValue: ProductDetailViewModel(entry: entry))
        self.onSave = onSave
        self.onDelete = onDelete
        self.userStore = nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.name)
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcEel)

                    if let brands = viewModel.brands, !brands.isEmpty {
                        Text(brands)
                            .font(.kcBody)
                            .foregroundStyle(Color.kcWolf)
                    }
                }
                .padding(.horizontal, Theme.cardInnerPadding)
                .padding(.top, Theme.horizontalPadding)

                // Incomplete product banner
                if viewModel.isIncomplete {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.kcIconMedium)
                            .foregroundStyle(Color.kcFox)
                        Text("Produit incomplet — renseignez les valeurs nutritionnelles pour 100g")
                            .font(.kcCaption)
                            .foregroundStyle(Color.kcEel)
                    }
                    .padding(Theme.cardInnerPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.kcBee.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM, style: .continuous))
                    .padding(.horizontal, Theme.horizontalPadding)
                }

                // Grams input
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUANTITÉ")
                        .font(.kcLabel)
                        .foregroundStyle(Color.kcWolf)
                        .kerning(Theme.labelKerning)

                    HStack(spacing: 8) {
                        KcNumericField(placeholder: "100", text: $viewModel.gramsText)
                            .padding(.vertical, 12)
                            .kcCard(radius: Theme.cornerRadiusM)

                        Text("grammes")
                            .font(.kcBody)
                            .foregroundStyle(Color.kcWolf)
                    }
                }
                .padding(.horizontal, Theme.cardInnerPadding)

                // Nutrients
                if viewModel.isIncomplete {
                    VStack(spacing: 0) {
                        EditableNutrientRow(label: "Calories", unit: "kcal", text: $viewModel.kcalText, color: .kcFeather, required: true)
                        EditableNutrientRow(label: "Protéines", unit: "g", text: $viewModel.proteinsText, color: .kcCardinal)
                        EditableNutrientRow(label: "Glucides", unit: "g", text: $viewModel.carbsText, color: .kcMacaw)
                        EditableNutrientRow(label: "Lipides", unit: "g", text: $viewModel.fatText, color: .kcBee)
                        EditableNutrientRow(label: "Sucres", unit: "g", text: $viewModel.sugarsText, color: .kcFox)
                        EditableNutrientRow(label: "Sel", unit: "g", text: $viewModel.saltText, color: .kcHare)
                    }
                    .kcCard()
                    .padding(.horizontal, Theme.horizontalPadding)
                } else {
                    VStack(spacing: 0) {
                        NutrientDetailRow(label: "Calories", value: "\(Int(viewModel.kcal))", unit: "kcal", color: .kcFeather)
                        NutrientDetailRow(label: "Protéines", value: String(format: "%.1f", viewModel.proteins), unit: "g", color: .kcCardinal)
                        NutrientDetailRow(label: "Glucides", value: String(format: "%.1f", viewModel.carbs), unit: "g", color: .kcMacaw)
                        NutrientDetailRow(label: "Lipides", value: String(format: "%.1f", viewModel.fat), unit: "g", color: .kcBee)
                        NutrientDetailRow(label: "Sucres", value: String(format: "%.1f", viewModel.sugars), unit: "g", color: .kcFox)
                        NutrientDetailRow(label: "Sel", value: String(format: "%.2f", viewModel.salt), unit: "g", color: .kcHare)
                    }
                    .kcCard()
                    .padding(.horizontal, Theme.horizontalPadding)
                }

                // Save button
                KcPrimaryButton(
                    label: viewModel.isEditing ? "Modifier" : "Ajouter",
                    enabled: viewModel.isValidInput
                ) {
                    if viewModel.isIncomplete, let code = viewModel.productCode, let userStore {
                        viewModel.applyOverrideTexts()
                        try? userStore.saveProductOverride(UserStore.ProductOverride(
                            code: code,
                            kcal: viewModel.kcalPer100g,
                            proteins: viewModel.proteinsPer100g,
                            carbs: viewModel.carbsPer100g,
                            fat: viewModel.fatPer100g,
                            sugars: viewModel.sugarsPer100g,
                            salt: viewModel.saltPer100g
                        ))
                    }
                    onSave(viewModel.makeFoodEntry())
                }
                .accessibilityHint(viewModel.isEditing ? "Modifie le grammage" : "Ajoute cet aliment au repas")
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)

                // Delete button (edit mode only)
                if let onDelete {
                    Button {
                        onDelete()
                    } label: {
                        Text("Supprimer")
                            .font(.kcBody)
                            .foregroundStyle(Color.kcCardinal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .padding(.horizontal, Theme.horizontalPadding)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color.kcPolar)
        .navigationTitle(viewModel.isEditing ? "Modifier" : "Détail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NutrientDetailRow: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: Theme.dotSize, height: Theme.dotSize)

            Text(label)
                .font(.kcBody)
                .foregroundStyle(Color.kcEel)

            Spacer()

            Text(value)
                .font(.kcNumberSmall)
                .foregroundStyle(Color.kcEel)

            Text(unit)
                .font(.kcCaption)
                .foregroundStyle(Color.kcWolf)
                .frame(width: 30, alignment: .leading)
        }
        .padding(.horizontal, Theme.cardInnerPadding)
        .padding(.vertical, 12)
    }
}

private struct EditableNutrientRow: View {
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
