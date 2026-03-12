import SwiftUI

struct MealSectionView: View {
    let meal: Meal
    let index: Int

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: meal.type.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.kcEel)
                    .frame(width: 32, height: 32)
                    .background(Color.kcPolar)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(meal.type.rawValue)
                    .font(.kcSubheadline)
                    .foregroundStyle(Color.kcEel)

                Spacer()

                if meal.totalKcal > 0 {
                    Text("\(Int(meal.totalKcal))")
                        .font(.kcNumberSmall)
                        .foregroundStyle(Color.kcFeather)
                    Text("kcal")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kcWolf)
                }

                Button {
                    // TODO: F5
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.kcSnow)
                        .frame(width: 44, height: 36)
                        .background(Color.kcFeather)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(Kc3DButton(shadow: .kcWing))
                .accessibilityLabel("Ajouter un aliment à \(meal.type.rawValue)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // Entries
            if meal.entries.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.kcHare)
                    Text("Aucun aliment")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kcHare)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.bottom, 4)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.kcPolar)
                        .frame(height: 2)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(meal.entries.enumerated()), id: \.element.id) { _, entry in
                        HStack(spacing: 0) {
                            Text(entry.name)
                                .font(.kcBody)
                                .foregroundStyle(Color.kcEel)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text("\(Int(entry.grams))g")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.kcHare)
                                .padding(.trailing, 14)

                            Text("\(Int(entry.kcal))")
                                .font(.kcNumberSmall)
                                .foregroundStyle(Color.kcFeather)
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(Color.kcPolar)
                                .frame(height: 2)
                        }
                    }
                }
            }
        }
        .background(Color.kcSnow)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
        .padding(.bottom, 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.kcStagger(index + 3)) {
                    appeared = true
                }
            }
        }
    }
}
