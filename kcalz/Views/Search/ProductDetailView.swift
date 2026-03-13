import SwiftUI

struct ProductDetailView: View {
    @State private var viewModel: ProductDetailViewModel
    let onSave: (FoodEntry) -> Void
    var onDelete: (() -> Void)?

    init(product: OFFProduct, onSave: @escaping (FoodEntry) -> Void) {
        _viewModel = State(initialValue: ProductDetailViewModel(product: product))
        self.onSave = onSave
        self.onDelete = nil
    }

    init(recentEntry: FoodEntry, onSave: @escaping (FoodEntry) -> Void) {
        _viewModel = State(initialValue: ProductDetailViewModel(recentEntry: recentEntry))
        self.onSave = onSave
        self.onDelete = nil
    }

    init(entry: FoodEntry, onSave: @escaping (FoodEntry) -> Void, onDelete: @escaping () -> Void) {
        _viewModel = State(initialValue: ProductDetailViewModel(entry: entry))
        self.onSave = onSave
        self.onDelete = onDelete
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

                // Save button
                KcPrimaryButton(
                    label: viewModel.isEditing ? "Modifier" : "Ajouter",
                    enabled: viewModel.isValidInput
                ) {
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

