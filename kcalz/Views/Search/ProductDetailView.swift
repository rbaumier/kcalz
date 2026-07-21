import os
import SwiftUI

private let logger = Logger(subsystem: "com.kcalz", category: "ProductDetailView")

/// Detail screen for a food product — shows nutrients and lets the user set grams before adding.
struct ProductDetailView: View {
    @State private var viewModel: ProductDetailViewModel
    let onSave: (FoodEntry) -> Void
    var onDelete: (() -> Void)?
    private let userStore: UserStore?
    private let mealBaseKcal: Double
    private let dayBaseKcal: Double
    private let goalKcal: Double?

    /// Creates the detail view from an OFF product, loading any user override.
    init(product: OFFProduct, userStore: UserStore, mealBaseKcal: Double, dayBaseKcal: Double, goalKcal: Double?, onSave: @escaping (FoodEntry) -> Void) {
        let override = userStore.loadProductOverride(code: product.code)
        _viewModel = State(initialValue: ProductDetailViewModel(product: product, override: override))
        self.onSave = onSave
        self.onDelete = nil
        self.userStore = userStore
        self.mealBaseKcal = mealBaseKcal
        self.dayBaseKcal = dayBaseKcal
        self.goalKcal = goalKcal
    }

    /// Creates the detail view from a recent food entry (re-log flow).
    init(recentEntry: FoodEntry, mealBaseKcal: Double, dayBaseKcal: Double, goalKcal: Double?, onSave: @escaping (FoodEntry) -> Void) {
        _viewModel = State(initialValue: ProductDetailViewModel(entry: recentEntry))
        self.onSave = onSave
        self.onDelete = nil
        self.userStore = nil
        self.mealBaseKcal = mealBaseKcal
        self.dayBaseKcal = dayBaseKcal
        self.goalKcal = goalKcal
    }

    /// Creates the detail view in edit mode for an existing logged entry.
    /// Callers pass bases already net of this entry's kcal so the projection reflects a replacement, not a duplicate.
    init(entry: FoodEntry, mealBaseKcal: Double, dayBaseKcal: Double, goalKcal: Double?, onSave: @escaping (FoodEntry) -> Void, onDelete: @escaping () -> Void) {
        _viewModel = State(initialValue: ProductDetailViewModel(entry: entry, editing: true))
        self.onSave = onSave
        self.onDelete = onDelete
        self.userStore = nil
        self.mealBaseKcal = mealBaseKcal
        self.dayBaseKcal = dayBaseKcal
        self.goalKcal = goalKcal
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
                        EditableNutrientRow(label: "Fibres", unit: "g", text: $viewModel.fiberText, color: .kcHare)
                    }
                    .kcCard()
                    .padding(.horizontal, Theme.horizontalPadding)
                } else {
                    VStack(spacing: 0) {
                        NutrientDetailRow(label: "Calories", value: "\(Int(viewModel.kcal))", unit: "kcal", color: .kcFeather)
                        NutrientDetailRow(label: "Protéines", value: String(format: "%.1f", viewModel.proteins), unit: "g", color: .kcCardinal)
                        NutrientDetailRow(label: "Glucides", value: String(format: "%.1f", viewModel.carbs), unit: "g", color: .kcMacaw)
                        NutrientDetailRow(label: "Lipides", value: String(format: "%.1f", viewModel.fat), unit: "g", color: .kcBee)
                        if viewModel.sugarsPer100g != nil {
                            NutrientDetailRow(label: "Sucres", value: String(format: "%.1f", viewModel.sugars), unit: "g", color: .kcFox)
                        }
                        if viewModel.saltPer100g != nil {
                            NutrientDetailRow(label: "Sel", value: String(format: "%.2f", viewModel.salt), unit: "g", color: .kcHare)
                        }
                        if viewModel.fiberPer100g != nil {
                            NutrientDetailRow(label: "Fibres", value: String(format: "%.1f", viewModel.fiber), unit: "g", color: .kcHare)
                        }
                    }
                    .kcCard()
                    .padding(.horizontal, Theme.horizontalPadding)
                }

            }
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                ProjectedTotalsRow(
                    mealKcal: mealBaseKcal + viewModel.kcal,
                    dayKcal: dayBaseKcal + viewModel.kcal,
                    goalKcal: goalKcal
                )
                .padding(.bottom, 10)

                KcPrimaryButton(
                    label: viewModel.isEditing ? "Modifier" : "Ajouter",
                    enabled: viewModel.isValidInput
                ) {
                    if viewModel.isIncomplete, let code = viewModel.productCode, let userStore {
                        viewModel.applyOverrideTexts()
                        do {
                            try userStore.saveProductOverride(UserStore.ProductOverride(
                                code: code,
                                kcal: viewModel.kcalPer100g,
                                proteins: viewModel.proteinsPer100g,
                                carbs: viewModel.carbsPer100g,
                                fat: viewModel.fatPer100g,
                                sugars: viewModel.sugarsPer100g,
                                salt: viewModel.saltPer100g,
                                fiber: viewModel.fiberPer100g
                            ))
                        } catch { logger.error("saveProductOverride failed: \(error)") }
                    }
                    onSave(viewModel.makeFoodEntry())
                }
                .accessibilityHint(viewModel.isEditing ? "Modifie le grammage" : "Ajoute cet aliment au repas")

                if let onDelete {
                    Button {
                        onDelete()
                    } label: {
                        Text("Supprimer")
                            .font(.kcBody)
                            .foregroundStyle(Color.kcCardinal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 8)
            .background(Color.kcPolar)
        }
        .background(Color.kcPolar)
        .navigationTitle(viewModel.isEditing ? "Modifier" : "Détail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Compact footer row showing the projected meal and day calorie totals — including the
/// portion currently being added — so the user can tune grams toward a goal without mental
/// math. Shared by the product-detail and free-entry footers. The day goal is shown only when set.
struct ProjectedTotalsRow: View {
    let mealKcal: Double
    let dayKcal: Double
    let goalKcal: Double?

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr_FR")
        f.maximumFractionDigits = 0
        return f
    }()

    /// Rounds to whole kcal and groups thousands the French way (e.g. `1 450`).
    private static func kcal(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value))"
    }

    var body: some View {
        let meal = Text("Repas ").foregroundStyle(Color.kcWolf)
            + Text(Self.kcal(mealKcal)).foregroundStyle(Color.kcFeather)
            + Text(" kcal").foregroundStyle(Color.kcWolf)
        let day: Text = {
            let total = Text("Journée ").foregroundStyle(Color.kcWolf)
                + Text(Self.kcal(dayKcal)).foregroundStyle(Color.kcFeather)
            if let goalKcal {
                return total + Text(" / \(Self.kcal(goalKcal)) kcal").foregroundStyle(Color.kcWolf)
            }
            return total + Text(" kcal").foregroundStyle(Color.kcWolf)
        }()

        (meal + Text(" · ").foregroundStyle(Color.kcWolf) + day)
            .font(.kcCaption)
            .frame(maxWidth: .infinity)
    }
}

/// Read-only row showing a nutrient label, value, and unit with a colored dot.
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

/// Editable row for a single nutrient — used in both ProductDetailView (incomplete products) and CreateFoodView.
struct EditableNutrientRow: View {
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
