import SwiftUI

struct MealSectionView: View {
    let meal: Meal
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header — outside the card
            HStack(spacing: 12) {
                Text(meal.type.displayName)
                    .font(.kcHeadline)
                    .foregroundStyle(Color.kcEel)

                Spacer()

                if meal.totalKcal > 0 {
                    Text("\(Int(meal.totalKcal))")
                        .font(.kcNumberSmall)
                        .foregroundStyle(Color.kcFeather)
                    Text("kcal")
                        .font(.kcUnit)
                        .foregroundStyle(Color.kcWolf)
                }

                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                        .font(.kcIconMedium)
                        .foregroundStyle(Color.kcSnow)
                        .frame(width: Theme.buttonSize, height: 36)
                        .background(Color.kcFeather)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusS, style: .continuous))
                }
                .buttonStyle(Kc3DButton(shadow: .kcWing))
                .accessibilityLabel("Ajouter un aliment à \(meal.type.displayName)")
            }
            .padding(.horizontal, 4)

            // Card body — entries only
            if meal.entries.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                        .font(.kcIcon)
                        .foregroundStyle(Color.kcHare)
                    Text("Aucun aliment")
                        .font(.kcEmptyText)
                        .foregroundStyle(Color.kcHare)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.cardInnerPadding)
                .background(Color.kcSnow)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXL, style: .continuous))
                .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(meal.entries.enumerated()), id: \.element.id) { i, entry in
                        if i > 0 {
                            Rectangle()
                                .fill(Color.kcPolar)
                                .frame(height: 2)
                                .padding(.leading, Theme.cardInnerPadding)
                        }

                        HStack(spacing: 0) {
                            Text(entry.name)
                                .font(.kcBody)
                                .foregroundStyle(Color.kcEel)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text("\(Int(entry.grams))g")
                                .font(.kcBadge)
                                .foregroundStyle(Color.kcHare)
                                .padding(.trailing, 14)

                            Text("\(Int(entry.kcal))")
                                .font(.kcNumberSmall)
                                .foregroundStyle(Color.kcFeather)
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                        .padding(.horizontal, Theme.cardInnerPadding)
                        .padding(.vertical, 14)
                        .accessibilityElement(children: .combine)
                    }
                }
                .background(Color.kcSnow)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXL, style: .continuous))
                .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
            }
        }
        .padding(.bottom, 4)
    }
}
