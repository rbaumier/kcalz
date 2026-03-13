import SwiftUI

struct DashboardView: View {
    let offStore: OFFStore
    let userStore: UserStore

    @State private var currentDate = Date.now
    @State private var dayLog: DayLog?
    @State private var goal = NutritionGoal()

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

    private var isToday: Bool {
        Calendar.current.isDateInToday(currentDate)
    }

    private var dateText: String {
        if isToday { return "Aujourd'hui" }
        return Self.dateFormatter.string(from: currentDate).capitalized
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let dayLog {
                    dayContent(dayLog)
                } else {
                    Color.kcPolar.ignoresSafeArea()
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
                    ProductDetailView(product: product, onSave: { entry in
                        addEntry(entry, to: mealType)
                        path = []
                    })
                case .edit(let entry, let mealType):
                    ProductDetailView(entry: entry, onSave: { updated in
                        updateEntry(updated, in: mealType)
                        path = []
                    }, onDelete: {
                        removeEntry(entry, from: mealType)
                        path = []
                    })
                case .goals:
                    GoalsView(current: goal) { newGoal in
                        try? userStore.saveGoals(newGoal)
                        goal = newGoal
                    }
                }
            }
            .task {
                loadDay(currentDate)
                goal = (try? userStore.loadGoals()) ?? NutritionGoal()
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

    @ViewBuilder
    private func dayContent(_ dayLog: DayLog) -> some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: - Date navigation
                HStack {
                    Button { navigateDay(-1) } label: {
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

                    Button { navigateDay(1) } label: {
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

                // MARK: - Summary
                VStack(spacing: 0) {
                    if goal.isEmpty {
                        Button { path.append(.goals) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "target")
                                    .font(.kcIconMedium)
                                    .foregroundStyle(Color.kcSnow)
                                Text("Définir mes objectifs")
                                    .font(.kcHeadline)
                                    .foregroundStyle(Color.kcSnow)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.kcFeather)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL, style: .continuous))
                        }
                        .buttonStyle(Kc3DButton(shadow: .kcWing, depth: 5))
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                        .padding(.horizontal, -4)
                    } else {
                        HStack(spacing: 20) {
                            if let kcalGoal = goal.kcal {
                                KcalRingView(consumed: dayLog.totalKcal, goal: kcalGoal)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("CONSOMMÉ")
                                    .font(.kcLabel)
                                    .foregroundStyle(Color.kcWolf)
                                    .kerning(Theme.labelKerning)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(Int(dayLog.totalKcal))")
                                        .font(.kcNumberMedium)
                                        .foregroundStyle(Color.kcFeather)
                                    if let kcalGoal = goal.kcal {
                                        Text("/ \(Int(kcalGoal)) kcal")
                                            .font(.kcSecondary)
                                            .foregroundStyle(Color.kcWolf)
                                    } else {
                                        Text("kcal")
                                            .font(.kcSecondary)
                                            .foregroundStyle(Color.kcWolf)
                                    }
                                }
                            }
                            .frame(minWidth: 200, alignment: .leading)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 28)

                        macrosBars(dayLog)
                    }
                }
                .padding(.horizontal, Theme.cardInnerPadding)
                .contentShape(Rectangle())
                .onTapGesture { path.append(.goals) }
                .opacity(summaryAppeared ? 1 : 0)
                .offset(y: summaryAppeared ? 0 : 16)

                // MARK: - Meals
                VStack(spacing: 24) {
                    ForEach(dayLog.meals) { meal in
                        MealSectionView(meal: meal, onAdd: {
                            path.append(.search(meal.type))
                        }, onTap: { entry in
                            path.append(.edit(entry, meal.type))
                        }, onDelete: { entry in
                            removeEntry(entry, from: meal.type)
                        })
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.bottom, 44)
            }
        }
    }

    @ViewBuilder
    private func macrosBars(_ dayLog: DayLog) -> some View {
        let bars: [(String, Double, Double?, Color)] = [
            ("Protéines", dayLog.totalProteins, goal.proteins, .kcCardinal),
            ("Glucides", dayLog.totalCarbs, goal.carbs, .kcMacaw),
            ("Lipides", dayLog.totalFat, goal.fat, .kcBee),
            ("Sucres", dayLog.totalSugars, goal.sugars, .kcFox),
            ("Sel", dayLog.totalSalt, goal.salt, .kcHare),
        ]
        let active = bars.enumerated().filter { $0.element.2 != nil }
        if !active.isEmpty {
            VStack(spacing: 12) {
                ForEach(active, id: \.offset) { index, bar in
                    NutrientBarView(label: bar.0, current: bar.1, goal: bar.2!, color: bar.3, index: index)
                }
            }
            .padding(.bottom, 32)
        }
    }

    private func navigateDay(_ offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: currentDate) else { return }
        currentDate = newDate
        loadDay(newDate)
    }

    private func loadDay(_ date: Date) {
        dayLog = try? userStore.loadDayLog(for: date)
    }

    private func addEntry(_ entry: FoodEntry, to mealType: MealType) {
        try? userStore.addEntry(entry, date: currentDate, mealType: mealType)
        loadDay(currentDate)
    }

    private func updateEntry(_ entry: FoodEntry, in mealType: MealType) {
        try? userStore.updateEntryGrams(id: entry.id, grams: entry.grams)
        loadDay(currentDate)
    }

    private func removeEntry(_ entry: FoodEntry, from mealType: MealType) {
        try? userStore.deleteEntry(id: entry.id)
        loadDay(currentDate)
    }
}

#Preview {
    if let offStore = try? OFFStore(), let userStore = try? UserStore() {
        DashboardView(offStore: offStore, userStore: userStore)
    }
}
