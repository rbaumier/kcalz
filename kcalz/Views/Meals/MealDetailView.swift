import SwiftUI

struct MealDetailView: View {
    let meal: Meal

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Summary
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(meal.totalKcal))")
                        .font(.kcNumber)
                        .foregroundStyle(Color.kcFeather)
                    Text("kcal")
                        .font(.kcSecondary)
                        .foregroundStyle(Color.kcWolf)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                VStack(spacing: 10) {
                    MacroRow(label: "Protéines", value: meal.totalProteins, color: .kcCardinal)
                    MacroRow(label: "Glucides", value: meal.totalCarbs, color: .kcMacaw)
                    MacroRow(label: "Lipides", value: meal.totalFat, color: .kcBee)
                    if meal.totalSugars > 0 {
                        MacroRow(label: "Sucres", value: meal.totalSugars, color: .kcFox)
                    }
                    if meal.totalSalt > 0 {
                        MacroRow(label: "Sel", value: meal.totalSalt, color: .kcHare)
                    }
                    if meal.totalFiber > 0 {
                        MacroRow(label: "Fibres", value: meal.totalFiber, color: .kcHare)
                    }
                }
                .padding(Theme.cardInnerPadding)
                .kcCard()

                // MARK: - Breakdown
                if !meal.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Détail")
                            .font(.kcHeadline)
                            .foregroundStyle(Color.kcEel)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(meal.entries.enumerated()), id: \.element.id) { i, entry in
                                if i > 0 {
                                    Rectangle()
                                        .fill(Color.kcPolar)
                                        .frame(height: 2)
                                        .padding(.leading, Theme.cardInnerPadding)
                                }
                                EntryBreakdownRow(entry: entry)
                            }
                        }
                        .kcCard()
                    }
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.top, Theme.horizontalPadding)
            .padding(.bottom, 32)
        }
        .background(Color.kcPolar)
        .navigationTitle(meal.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Macro Row

private struct MacroRow: View {
    let label: String
    let value: Double
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

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: label == "Sel" ? "%.2f" : "%.1f", value))
                    .font(.kcNumberSmall)
                    .foregroundStyle(Color.kcEel)
                Text("g")
                    .font(.kcUnit)
                    .foregroundStyle(Color.kcWolf)
            }
        }
    }
}

// MARK: - Entry Breakdown Row

private struct EntryBreakdownRow: View {
    let entry: FoodEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.name)
                    .font(.kcBody)
                    .foregroundStyle(Color.kcEel)
                    .lineLimit(1)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(entry.kcal))")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.kcFeather)
                    Text("kcal / \(Int(entry.grams))g")
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcWolf)
                }
            }

            HStack {
                if let brands = entry.brands, !brands.isEmpty {
                    Text(brands)
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcWolf)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 12) {
                    MacroPill(label: "P", value: entry.proteins, color: .kcCardinal)
                    MacroPill(label: "G", value: entry.carbs, color: .kcMacaw)
                    MacroPill(label: "L", value: entry.fat, color: .kcBee)
                }
            }
        }
        .padding(.horizontal, Theme.cardInnerPadding)
        .padding(.vertical, 12)
    }
}

// MARK: - Macro Pill

private struct MacroPill: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) \(String(format: "%.1f", value))g")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.kcWolf)
        }
    }
}
