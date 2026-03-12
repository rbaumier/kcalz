import SwiftUI

struct DashboardView: View {
    let dayLog = PreviewData.dayLog
    let goal = PreviewData.goal

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Date header
                HStack {
                    Button { } label: {
                        Image(systemName: "chevron.left")
                            .font(.kcSubheadline)
                    }
                    Spacer()
                    Text(dateFormatter.string(from: dayLog.date).capitalized)
                        .font(.kcHeadline)
                    Spacer()
                    Button { } label: {
                        Image(systemName: "chevron.right")
                            .font(.kcSubheadline)
                    }
                }
                .foregroundStyle(.primary)
                .padding(.horizontal)

                // Kcal ring + poids
                HStack(spacing: 24) {
                    KcalRingView(consumed: dayLog.totalKcal, goal: goal.kcal)

                    VStack(alignment: .leading, spacing: 12) {
                        if let weight = dayLog.weight {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Poids")
                                    .font(.kcCaption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(String(format: "%.1f", weight))
                                        .font(.kcNumber)
                                    Text("kg")
                                        .font(.kcCaption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(dayLog.totalKcal)) consommées")
                                .font(.kcCaption)
                                .foregroundStyle(.secondary)
                            Text("sur \(goal.kcal) kcal")
                                .font(.kcCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .kcCard()

                // Barres macros
                VStack(spacing: 12) {
                    NutrientBarView(label: "Protéines", current: dayLog.totalProteins, goal: goal.proteins, color: .kcProteins)
                    NutrientBarView(label: "Glucides", current: dayLog.totalCarbs, goal: goal.carbs, color: .kcCarbs)
                    NutrientBarView(label: "Lipides", current: dayLog.totalFat, goal: goal.fat, color: .kcFat)
                }
                .kcCard()

                // Repas
                ForEach(dayLog.meals) { meal in
                    MealSectionView(meal: meal)
                }
            }
            .padding()
        }
        .background(Color.kcBackground)
    }
}

#Preview {
    DashboardView()
}
