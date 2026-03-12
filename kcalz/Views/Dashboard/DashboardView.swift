import SwiftUI

struct DashboardView: View {
    let dayLog = PreviewData.dayLog
    let goal = PreviewData.goal

    @State private var headerAppeared = false
    @State private var summaryAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: dayLog.date).capitalized
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: - Date navigation
                HStack {
                    Button { } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.kcTextSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.kcSurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(KcPressable())

                    Spacer()

                    Text(dateText)
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcTextPrimary)

                    Spacer()

                    Button { } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.kcTextSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.kcSurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(KcPressable())
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .opacity(headerAppeared ? 1 : 0)

                // MARK: - Summary hero
                VStack(spacing: 24) {
                    // Ring + weight side by side
                    HStack(spacing: 28) {
                        KcalRingView(consumed: dayLog.totalKcal, goal: goal.kcal)

                        VStack(alignment: .leading, spacing: 16) {
                            // Weight block
                            if let weight = dayLog.weight {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Poids")
                                        .font(.kcCaption)
                                        .foregroundStyle(Color.kcTextSecondary)
                                        .textCase(.uppercase)
                                        .kerning(0.5)
                                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                                        Text(String(format: "%.1f", weight))
                                            .font(.kcNumberMedium)
                                            .foregroundStyle(Color.kcTextPrimary)
                                        Text("kg")
                                            .font(.kcCaption)
                                            .foregroundStyle(Color.kcTextSecondary)
                                    }
                                }
                            }

                            // Consumed summary
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Consommé")
                                    .font(.kcCaption)
                                    .foregroundStyle(Color.kcTextSecondary)
                                    .textCase(.uppercase)
                                    .kerning(0.5)
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text("\(Int(dayLog.totalKcal))")
                                        .font(.kcNumberMedium)
                                        .foregroundStyle(Color.kcKcal)
                                    Text("/ \(goal.kcal)")
                                        .font(.kcCaption)
                                        .foregroundStyle(Color.kcTextSecondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Macro bars — no card wrapper, just inline
                    VStack(spacing: 14) {
                        NutrientBarView(label: "Protéines", current: dayLog.totalProteins, goal: goal.proteins, color: .kcProteins, index: 0)
                        NutrientBarView(label: "Glucides", current: dayLog.totalCarbs, goal: goal.carbs, color: .kcCarbs, index: 1)
                        NutrientBarView(label: "Lipides", current: dayLog.totalFat, goal: goal.fat, color: .kcFat, index: 2)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .background(Color.kcSurface)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 16)
                .opacity(summaryAppeared ? 1 : 0)
                .offset(y: summaryAppeared ? 0 : 16)

                // MARK: - Meals
                VStack(spacing: 10) {
                    ForEach(Array(dayLog.meals.enumerated()), id: \.element.id) { i, meal in
                        MealSectionView(meal: meal, index: i)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color.kcBackground)
        .onAppear {
            if reduceMotion {
                headerAppeared = true
                summaryAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    headerAppeared = true
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    summaryAppeared = true
                }
            }
        }
    }
}

#Preview {
    DashboardView()
}
