import SwiftUI

struct DashboardView: View {
    let offStore: OFFStore

    @State private var dayLog = PreviewData.dayLog
    private let goal = PreviewData.goal

    @State private var path: [Route] = []
    @State private var headerAppeared = false
    @State private var summaryAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private var dateText: String {
        Self.dateFormatter.string(from: dayLog.date).capitalized
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: - Date navigation
                    HStack {
                        Button { } label: {
                            Image(systemName: "chevron.left")
                                .font(.kcIcon)
                                .foregroundStyle(Color.kcWolf)
                                .frame(width: Theme.buttonSize, height: Theme.buttonSize)
                                .background(Color.kcSnow)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM, style: .continuous))
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
                                .font(.kcIcon)
                                .foregroundStyle(Color.kcWolf)
                                .frame(width: Theme.buttonSize, height: Theme.buttonSize)
                                .background(Color.kcSnow)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM, style: .continuous))
                        }
                        .buttonStyle(Kc3DButton(shadow: Color.kcSwan))
                        .accessibilityLabel("Jour suivant")
                    }
                    .padding(.horizontal, Theme.cardInnerPadding)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                    .opacity(headerAppeared ? 1 : 0)

                    // MARK: - Summary (no card)
                    VStack(spacing: 0) {
                        HStack(spacing: 20) {
                            KcalRingView(consumed: dayLog.totalKcal, goal: goal.kcal)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("CONSOMMÉ")
                                    .font(.kcLabel)
                                    .foregroundStyle(Color.kcWolf)
                                    .kerning(Theme.labelKerning)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(Int(dayLog.totalKcal))")
                                        .font(.kcNumberMedium)
                                        .foregroundStyle(Color.kcFeather)
                                    Text("/ \(Int(goal.kcal)) kcal")
                                        .font(.kcSecondary)
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
                    .padding(.horizontal, Theme.cardInnerPadding)
                    .opacity(summaryAppeared ? 1 : 0)
                    .offset(y: summaryAppeared ? 0 : 16)

                    // MARK: - Meals
                    VStack(spacing: 24) {
                        ForEach(Array(dayLog.meals.enumerated()), id: \.element.id) { i, meal in
                            MealSectionView(meal: meal, index: i) {
                                path.append(.search(meal.type))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.bottom, 44)
                }
            }
            .background(Color.kcPolar)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .search(let mealType):
                    SearchView(store: offStore) { product in
                        path.append(.detail(product, mealType))
                    }
                case .detail(let product, let mealType):
                    ProductDetailView(product: product) { entry in
                        addEntry(entry, to: mealType)
                        path = []
                    }
                }
            }
            .task {
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

    private func addEntry(_ entry: FoodEntry, to mealType: MealType) {
        guard let idx = dayLog.meals.firstIndex(where: { $0.type == mealType }) else { return }
        dayLog.meals[idx].entries.append(entry)
    }
}

#Preview {
    if let store = try? OFFStore() {
        DashboardView(offStore: store)
    }
}
