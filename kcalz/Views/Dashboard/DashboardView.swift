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
    @State private var selectingMealType: MealType?
    @State private var selectedEntryIds: Set<UUID> = []
    @State private var showCopySheet = false
    @State private var showDatePicker = false
    @State private var previousMeals: [MealType: (date: Date, entries: [FoodEntry])] = [:]
    @State private var todayWeight: Double?
    @State private var weightTrend: WeightTrend = .stable
    @State private var checkpoint: UserStore.WeightCheckpoint?
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
        if Calendar.current.isDateInYesterday(currentDate) { return "Hier" }
        if Calendar.current.isDateInTomorrow(currentDate) { return "Demain" }
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
                    SearchView(store: offStore, userStore: userStore, onSelect: { product in
                        path.append(.detail(product, mealType))
                    }, onSelectRecent: { entry in
                        path.append(.addRecent(entry, mealType))
                    }, onScan: {
                        path.append(.scan(mealType))
                    }, onCreateFood: { query in
                        path.append(.createFood(query, mealType))
                    }, onSelectCustom: { custom in
                        let entry = FoodEntry(
                            name: custom.name ?? "",
                            brands: custom.brands,
                            grams: 100,
                            kcalPer100g: custom.kcal,
                            proteinsPer100g: custom.proteins ?? 0,
                            carbsPer100g: custom.carbs ?? 0,
                            fatPer100g: custom.fat ?? 0,
                            sugarsPer100g: custom.sugars,
                            saltPer100g: custom.salt,
                            fiberPer100g: custom.fiber
                        )
                        path.append(.addRecent(entry, mealType))
                    })
                case .createFood(let query, let mealType):
                    CreateFoodView(initialName: query, userStore: userStore) { custom in
                        let entry = FoodEntry(
                            name: custom.name ?? "",
                            brands: custom.brands,
                            grams: 100,
                            kcalPer100g: custom.kcal,
                            proteinsPer100g: custom.proteins ?? 0,
                            carbsPer100g: custom.carbs ?? 0,
                            fatPer100g: custom.fat ?? 0,
                            sugarsPer100g: custom.sugars,
                            saltPer100g: custom.salt,
                            fiberPer100g: custom.fiber
                        )
                        path.append(.addRecent(entry, mealType))
                    }
                case .scan(let mealType):
                    BarcodeScannerView(offStore: offStore) { product in
                        path.append(.detail(product, mealType))
                    }
                case .detail(let product, let mealType):
                    ProductDetailView(product: product, userStore: userStore, onSave: { entry in
                        addEntry(entry, to: mealType)
                        path = []
                    })
                case .addRecent(let entry, let mealType):
                    ProductDetailView(recentEntry: entry, onSave: { newEntry in
                        addEntry(newEntry, to: mealType)
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
                case .mealDetail(let meal):
                    MealDetailView(meal: meal)
                case .goals:
                    GoalsView(current: goal, onSave: { newGoal in
                        try? userStore.saveGoals(newGoal)
                        goal = newGoal
                    }, userStore: userStore)
                case .weight:
                    WeightView(userStore: userStore, currentDate: currentDate)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selectingMealType != nil {
                    SelectionActionBar(
                        count: selectedEntryIds.count,
                        onDelete: { deleteSelectedEntries() },
                        onCopy: { showCopySheet = true },
                        onCancel: { exitSelectionMode() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.bottom, 8)
                }
            }
            .animation(.easeOut(duration: 0.2), value: selectingMealType)
            .sheet(isPresented: $showCopySheet) {
                CopySheet { date, mealType in
                    copySelectedEntries(to: date, mealType: mealType)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showDatePicker) {
                VStack(spacing: 16) {
                    DatePicker("", selection: $currentDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                        .tint(Color.kcFeather)
                        .onChange(of: currentDate) {
                            showDatePicker = false
                        }
                }
                .padding()
                .presentationDetents([.medium])
            }
            .onChange(of: currentDate) {
                loadDay(currentDate)
                loadWeight()
            }
            .onChange(of: path) {
                if path.isEmpty { loadWeight() }
            }
            .task {
                loadDay(currentDate)
                loadWeight()
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

                    Button { showDatePicker = true } label: {
                        Text(dateText)
                            .font(.kcHeadline)
                            .foregroundStyle(Color.kcEel)
                    }

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
                        KcPrimaryButton(label: "Définir mes objectifs", icon: "target") {
                            path.append(.goals)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                        .padding(.horizontal, -4)
                    } else {
                        HStack(spacing: 20) {
                            if let kcalGoal = goal.kcal {
                                KcalRingView(consumed: dayLog.totalKcal, goal: kcalGoal)
                            }

                            VStack(alignment: .leading, spacing: 4) {
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

                                Button { path.append(.weight) } label: {
                                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                                        if let kg = todayWeight {
                                            Text(formatWeight(kg))
                                                .font(.system(size: 20, weight: .black, design: .rounded))
                                                .foregroundStyle(Color.kcEel)
                                            Text("kg")
                                                .font(.kcUnit)
                                                .foregroundStyle(Color.kcHare)

                                            if let cp = checkpoint {
                                                let diff = kg - cp.weightKg
                                                let sign = diff >= 0 ? "+" : ""
                                                let color: Color = switch cp.goal {
                                                case .loss: diff <= 0 ? .kcFeather : .kcCardinal
                                                case .gain: diff >= 0 ? .kcFeather : .kcCardinal
                                                case .maintain: .kcHare
                                                }
                                                Text("\(sign)\(formatWeight(diff))")
                                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                                    .foregroundStyle(color)
                                                    .padding(.leading, 3)
                                            }
                                        } else {
                                            Text("— kg")
                                                .font(.system(size: 20, weight: .black, design: .rounded))
                                                .foregroundStyle(Color.kcHare)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
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
                        MealSectionView(
                            meal: meal,
                            onTitleTap: { path.append(.mealDetail(meal)) },
                            onAdd: { path.append(.search(meal.type)) },
                            onTap: { entry in path.append(.edit(entry, meal.type)) },
                            isSelecting: selectingMealType == meal.type,
                            selectedIds: $selectedEntryIds,
                            onLongPress: { selectingMealType = meal.type },
                            currentDate: currentDate,
                            previousMeal: previousMeals[meal.type],
                            onCopyPrevious: { copyPreviousMeal(meal.type) }
                        )
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
            ("Fibres", dayLog.totalFiber, goal.kcal.map { $0 / 1000 * 15 }, .kcHare),
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
        loadWeight()
    }

    private func loadDay(_ date: Date) {
        dayLog = try? userStore.loadDayLog(for: date)
        loadPreviousMeals(date)
    }

    private func loadPreviousMeals(_ date: Date) {
        var result: [MealType: (date: Date, entries: [FoodEntry])] = [:]
        guard let dayLog else { previousMeals = result; return }
        for meal in dayLog.meals where meal.entries.isEmpty {
            if let prev = userStore.findLastMealEntries(type: meal.type, before: date) {
                result[meal.type] = prev
            }
        }
        previousMeals = result
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

    private func exitSelectionMode() {
        selectingMealType = nil
        selectedEntryIds = []
    }

    private func deleteSelectedEntries() {
        try? userStore.deleteEntries(ids: selectedEntryIds)
        exitSelectionMode()
        loadDay(currentDate)
    }

    private func loadWeight() {
        todayWeight = try? userStore.loadWeight(for: currentDate)
        checkpoint = userStore.latestCheckpoint()
        let recent = (try? userStore.latestWeights(limit: 7)) ?? []
        if recent.count >= 2, let first = recent.first, let last = recent.last {
            let diff = last.kg - first.kg
            if diff < -0.2 { weightTrend = .down }
            else if diff > 0.2 { weightTrend = .up }
            else { weightTrend = .stable }
        } else {
            weightTrend = .stable
        }
    }

    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg))" : String(format: "%.1f", kg)
    }

    private func copyPreviousMeal(_ mealType: MealType) {
        guard let prev = previousMeals[mealType] else { return }
        for entry in prev.entries {
            let copy = FoodEntry(
                name: entry.name,
                brands: entry.brands,
                grams: entry.grams,
                kcalPer100g: entry.kcalPer100g,
                proteinsPer100g: entry.proteinsPer100g,
                carbsPer100g: entry.carbsPer100g,
                fatPer100g: entry.fatPer100g,
                sugarsPer100g: entry.sugarsPer100g,
                saltPer100g: entry.saltPer100g,
                fiberPer100g: entry.fiberPer100g
            )
            try? userStore.addEntry(copy, date: currentDate, mealType: mealType)
        }
        loadDay(currentDate)
    }

    private func copySelectedEntries(to date: Date, mealType: MealType) {
        try? userStore.copyEntries(ids: selectedEntryIds, toDate: date, mealType: mealType)
        exitSelectionMode()
        currentDate = date
        loadDay(currentDate)
    }
}

enum WeightTrend {
    case up, down, stable

    var systemImage: String {
        switch self {
        case .down: "arrow.down"
        case .up: "arrow.up"
        case .stable: "arrow.forward"
        }
    }

    var color: Color {
        switch self {
        case .down: .kcFeather
        case .up: .kcCardinal
        case .stable: .kcHare
        }
    }
}

#Preview {
    if let offStore = try? OFFStore(), let userStore = try? UserStore() {
        DashboardView(offStore: offStore, userStore: userStore)
    }
}
