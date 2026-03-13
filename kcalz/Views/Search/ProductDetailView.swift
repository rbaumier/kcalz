import SwiftUI

struct ProductDetailView: View {
    @State private var viewModel: ProductDetailViewModel
    let onAdd: (FoodEntry) -> Void

    init(product: OFFProduct, onAdd: @escaping (FoodEntry) -> Void) {
        _viewModel = State(initialValue: ProductDetailViewModel(product: product))
        self.onAdd = onAdd
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.product.name)
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcEel)

                    if let brands = viewModel.product.brands, !brands.isEmpty {
                        Text(brands)
                            .font(.kcBody)
                            .foregroundStyle(Color.kcWolf)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Grams input
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUANTITÉ")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.kcWolf)
                        .kerning(0.8)

                    HStack(spacing: 8) {
                        TextField("100", text: $viewModel.gramsText)
                            .font(.kcNumberMedium)
                            .foregroundStyle(Color.kcEel)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .background(Color.kcSnow)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)

                        Text("grammes")
                            .font(.kcBody)
                            .foregroundStyle(Color.kcWolf)
                    }
                }
                .padding(.horizontal, 20)

                // Nutrients
                VStack(spacing: 0) {
                    NutrientDetailRow(label: "Calories", value: "\(Int(viewModel.kcal))", unit: "kcal", color: .kcFeather)
                    NutrientDetailRow(label: "Protéines", value: String(format: "%.1f", viewModel.proteins), unit: "g", color: .kcCardinal)
                    NutrientDetailRow(label: "Glucides", value: String(format: "%.1f", viewModel.carbs), unit: "g", color: .kcMacaw)
                    NutrientDetailRow(label: "Lipides", value: String(format: "%.1f", viewModel.fat), unit: "g", color: .kcBee)
                    NutrientDetailRow(label: "Sucres", value: String(format: "%.1f", viewModel.sugars), unit: "g", color: .kcFox)
                    NutrientDetailRow(label: "Sel", value: String(format: "%.2f", viewModel.salt), unit: "g", color: .kcHare)
                }
                .background(Color.kcSnow)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
                .padding(.horizontal, 16)

                // Add button
                Button {
                    onAdd(viewModel.makeFoodEntry())
                } label: {
                    Text("Ajouter")
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcSnow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.kcFeather)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(Kc3DButton(shadow: .kcWing, depth: 5))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .background(Color.kcPolar)
        .navigationTitle("Détail")
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
                .frame(width: 10, height: 10)

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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
