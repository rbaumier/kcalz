import SwiftUI

struct MealSectionView: View {
    let meal: Meal
    let index: Int

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var mealColor: Color {
        switch meal.type {
        case .breakfast: Color.kcKcal
        case .lunch: Color.kcPrimary
        case .snack: Color.kcCarbs
        case .dinner: Color.kcSugars
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                // Colored indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(mealColor)
                    .frame(width: 4, height: 28)

                Image(systemName: meal.type.icon)
                    .font(.subheadline)
                    .foregroundStyle(mealColor)

                Text(meal.type.rawValue)
                    .font(.kcSubheadline)
                    .foregroundStyle(Color.kcTextPrimary)

                Spacer()

                if meal.totalKcal > 0 {
                    Text("\(Int(meal.totalKcal))")
                        .font(.kcNumberSmall)
                        .foregroundStyle(mealColor)
                    + Text(" kcal")
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcTextSecondary)
                }

                Button {
                    // TODO: F5
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.kcSurface)
                        .frame(width: 28, height: 28)
                        .background(mealColor)
                        .clipShape(Circle())
                }
                .buttonStyle(KcPressable())
                .accessibilityLabel("Ajouter un aliment à \(meal.type.rawValue)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Entries
            if meal.entries.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(Color.kcTextSecondary.opacity(0.5))
                    Text("Ajouter un aliment")
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcTextSecondary.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
                .padding(.leading, 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(meal.entries.enumerated()), id: \.element.id) { i, entry in
                        if i > 0 {
                            Divider()
                                .foregroundStyle(Color.kcDivider)
                                .padding(.leading, 54)
                        }

                        HStack(spacing: 0) {
                            Text(entry.name)
                                .font(.kcBody)
                                .foregroundStyle(Color.kcTextPrimary)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text("\(Int(entry.grams))g")
                                .font(.kcCaption)
                                .foregroundStyle(Color.kcTextSecondary)
                                .padding(.trailing, 12)

                            Text("\(Int(entry.kcal))")
                                .font(.kcNumberSmall)
                                .foregroundStyle(mealColor)
                                .frame(minWidth: 40, alignment: .trailing)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .padding(.leading, 14)
                    }
                }
            }
        }
        .background(Color.kcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
