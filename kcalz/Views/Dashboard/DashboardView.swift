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
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.kcWolf)
                            .frame(width: 44, height: 44)
                            .background(Color.kcSnow)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(Kc3DButton(shadow: Color.kcSwan))
                    .accessibilityLabel("Jour précédent")

                    Spacer()

                    Text(dateText)
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcEel)

                    Spacer()

                    Button { } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.kcWolf)
                            .frame(width: 44, height: 44)
                            .background(Color.kcSnow)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(Kc3DButton(shadow: Color.kcSwan))
                    .accessibilityLabel("Jour suivant")
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 16)
                .opacity(headerAppeared ? 1 : 0)

                // MARK: - Summary (no card)
                VStack(spacing: 0) {
                    HStack(spacing: 20) {
                        KcalRingView(consumed: dayLog.totalKcal, goal: goal.kcal)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("CONSOMMÉ")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.kcWolf)
                                .kerning(0.8)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(dayLog.totalKcal))")
                                    .font(.kcNumberMedium)
                                    .foregroundStyle(Color.kcFeather)
                                Text("/ \(goal.kcal) kcal")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color.kcWolf)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 28)

                    // Macros — compact inline
                    VStack(spacing: 12) {
                        NutrientBarView(label: "Protéines", current: dayLog.totalProteins, goal: goal.proteins, color: .kcCardinal, index: 0)
                        NutrientBarView(label: "Glucides", current: dayLog.totalCarbs, goal: goal.carbs, color: .kcMacaw, index: 1)
                        NutrientBarView(label: "Lipides", current: dayLog.totalFat, goal: goal.fat, color: .kcBee, index: 2)
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
                .opacity(summaryAppeared ? 1 : 0)
                .offset(y: summaryAppeared ? 0 : 16)

                // MARK: - Meals
                VStack(spacing: 24) {
                    ForEach(Array(dayLog.meals.enumerated()), id: \.element.id) { i, meal in
                        MealSectionView(meal: meal, index: i)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 44)
            }
        }
        .background(Color.kcPolar)
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
