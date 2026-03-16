import os
import SwiftUI

private let logger = Logger(subsystem: "com.kcalz", category: "DashboardView")

/// Main daily tracker screen showing calorie summary, macros, and meal sections.
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
    @State private var checkpoint: UserStore.WeightCheckpoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Nutrient bar data for a single macro row in the summary section.
    private struct MacroBarData {
        let label: String
        let current: Double
        let goal: Double?
        let color: Color
    }

    /// Fiber recommendation: grams per 1 000 kcal.
    private static let fiberPer1000Kcal: Double = 15

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    /// Whether `currentDate` is today.
    private var isToday: Bool {
        Calendar.current.isDateInToday(currentDate)
    }

    /// Human-readable label for `currentDate` (e.g. "Aujourd'hui", "Hier", or full date).
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
                        path.append(.detail(product: product, mealType: mealType))
                    }, onSelectRecent: { entry in
                        path.append(.addRecent(entry: entry, mealType: mealType))
                    }, onScan: {
                        path.append(.scan(mealType: mealType))
                    }, onCreateFood: { query in
                        path.append(.createFood(query: query, mealType: mealType))
                    }, onSelectCustom: { custom in
                        path.append(.addRecent(entry: foodEntry(from: custom), mealType: mealType))
                    })
                case .createFood(let query, let mealType):
                    CreateFoodView(initialName: query, userStore: userStore) { custom in
                        path.append(.addRecent(entry: foodEntry(from: custom), mealType: mealType))
                    }
                case .scan(let mealType):
                    BarcodeScannerView(offStore: offStore) { product in
                        // Replace scanner with detail so back goes to SearchView, not scanner.
                        path.removeLast()
                        path.append(.detail(product: product, mealType: mealType))
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
                        do { try userStore.saveGoals(newGoal) }
                        catch { logger.error("saveGoals failed: \(error)") }
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

    /// Main scrollable content for the day: date nav, summary ring, macros, and meal sections.
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
                                            Text(kg.kcFormatted)
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
                                                Text("\(sign)\(diff.kcFormatted)")
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
                            onTitleTap: { path.append(.mealDetail(meal: meal)) },
                            onAdd: { path.append(.search(mealType: meal.type)) },
                            onTap: { entry in path.append(.edit(entry: entry, mealType: meal.type)) },
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

    /// Horizontal progress bars for each macro that has a goal set.
    @ViewBuilder
    private func macrosBars(_ dayLog: DayLog) -> some View {
        let bars: [MacroBarData] = [
            MacroBarData(label: "Protéines", current: dayLog.totalProteins, goal: goal.proteins, color: .kcCardinal),
            MacroBarData(label: "Glucides", current: dayLog.totalCarbs, goal: goal.carbs, color: .kcMacaw),
            MacroBarData(label: "Lipides", current: dayLog.totalFat, goal: goal.fat, color: .kcBee),
            MacroBarData(label: "Sucres", current: dayLog.totalSugars, goal: goal.sugars, color: .kcFox),
            MacroBarData(label: "Sel", current: dayLog.totalSalt, goal: goal.salt, color: .kcHare),
            MacroBarData(label: "Fibres", current: dayLog.totalFiber,
                         goal: goal.kcal.map { $0 / 1000 * Self.fiberPer1000Kcal }, color: .kcHare),
        ]
        let active = bars.enumerated().filter { $0.element.goal != nil }
        if !active.isEmpty {
            VStack(spacing: 12) {
                ForEach(active, id: \.offset) { index, bar in
                    if let goalValue = bar.goal {
                        NutrientBarView(label: bar.label, current: bar.current, goal: goalValue, color: bar.color, index: index)
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }

    /// Moves `currentDate` forward or backward by `offset` days.
    private func navigateDay(_ offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: currentDate) else { return }
        currentDate = newDate
    }

    /// Loads the `DayLog` and previous-meal hints for the given date.
    private func loadDay(_ date: Date) {
        dayLog = try? userStore.loadDayLog(for: date)
        loadPreviousMeals(date)
    }

    /// Finds the most recent entries for each empty meal slot to offer "copy previous".
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

    /// Persists a new food entry and refreshes the day.
    private func addEntry(_ entry: FoodEntry, to mealType: MealType) {
        do { try userStore.addEntry(entry, date: currentDate, mealType: mealType) }
        catch { logger.error("addEntry failed: \(error)") }
        loadDay(currentDate)
    }

    /// Updates the gram amount of an existing entry and refreshes the day.
    private func updateEntry(_ entry: FoodEntry, in mealType: MealType) {
        do { try userStore.updateEntryGrams(id: entry.id, grams: entry.grams) }
        catch { logger.error("updateEntry failed: \(error)") }
        loadDay(currentDate)
    }

    /// Deletes a single entry and refreshes the day.
    private func removeEntry(_ entry: FoodEntry, from mealType: MealType) {
        do { try userStore.deleteEntry(id: entry.id) }
        catch { logger.error("removeEntry failed: \(error)") }
        loadDay(currentDate)
    }

    /// Clears multi-select state and deselects all entries.
    private func exitSelectionMode() {
        selectingMealType = nil
        selectedEntryIds = []
    }

    /// Batch-deletes all currently selected entries.
    private func deleteSelectedEntries() {
        do { try userStore.deleteEntries(ids: selectedEntryIds) }
        catch { logger.error("deleteSelectedEntries failed: \(error)") }
        exitSelectionMode()
        loadDay(currentDate)
    }

    /// Refreshes today's weight and the latest checkpoint from the store.
    private func loadWeight() {
        todayWeight = try? userStore.loadWeight(for: currentDate)
        checkpoint = userStore.latestCheckpoint()
    }

    /// Duplicates entries from the most recent occurrence of `mealType` into today.
    private func copyPreviousMeal(_ mealType: MealType) {
        guard let prev = previousMeals[mealType] else { return }
        let copies = prev.entries.map { entry in
            FoodEntry(name: entry.name, brands: entry.brands, grams: entry.grams,
                      kcalPer100g: entry.kcalPer100g, proteinsPer100g: entry.proteinsPer100g,
                      carbsPer100g: entry.carbsPer100g, fatPer100g: entry.fatPer100g,
                      sugarsPer100g: entry.sugarsPer100g, saltPer100g: entry.saltPer100g,
                      fiberPer100g: entry.fiberPer100g)
        }
        do { try userStore.addEntries(copies, date: currentDate, mealType: mealType) }
        catch { logger.error("copyPreviousMeal failed: \(error)") }
        loadDay(currentDate)
    }

    /// Copies the selected entries to a different date and meal, then navigates there.
    private func copySelectedEntries(to date: Date, mealType: MealType) {
        do { try userStore.copyEntries(ids: selectedEntryIds, toDate: date, mealType: mealType) }
        catch { logger.error("copySelectedEntries failed: \(error)") }
        exitSelectionMode()
        currentDate = date
        loadDay(currentDate)
    }

    /// Converts a custom product override into a `FoodEntry` with 100 g default weight.
    private func foodEntry(from custom: UserStore.ProductOverride) -> FoodEntry {
        FoodEntry(
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
    }
}

#Preview {
    if let offStore = try? OFFStore(), let userStore = try? UserStore() {
        DashboardView(offStore: offStore, userStore: userStore)
    } else {
        Text("Preview unavailable — missing database files")
    }
}
