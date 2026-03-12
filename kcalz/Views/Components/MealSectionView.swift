import SwiftUI

struct MealSectionView: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: meal.type.icon)
                    .foregroundStyle(.kcPrimary)
                Text(meal.type.rawValue)
                    .font(.kcSubheadline)
                Spacer()
                if meal.totalKcal > 0 {
                    Text("\(Int(meal.totalKcal)) kcal")
                        .font(.kcNumberSmall)
                        .foregroundStyle(.kcKcal)
                }
                Button {
                    // TODO: F5 — ajout aliment
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.kcPrimary)
                }
                .buttonStyle(KcBounceButton())
            }

            if meal.entries.isEmpty {
                Text("Aucun aliment")
                    .font(.kcCaption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 28)
            } else {
                ForEach(meal.entries) { entry in
                    HStack {
                        Text(entry.name)
                            .font(.kcBody)
                        Spacer()
                        Text("\(Int(entry.grams))g")
                            .font(.kcCaption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(entry.kcal))")
                            .font(.kcNumberSmall)
                            .foregroundStyle(.kcKcal)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.leading, 28)
                }
            }
        }
        .kcCard()
    }
}
