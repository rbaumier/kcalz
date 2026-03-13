import Foundation

struct Meal: Identifiable, Sendable, Hashable {
    let id = UUID()
    var type: MealType
    var entries: [FoodEntry]

    var totalKcal: Double { entries.reduce(0) { $0 + $1.kcal } }
    var totalProteins: Double { entries.reduce(0) { $0 + $1.proteins } }
    var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { entries.reduce(0) { $0 + $1.fat } }

    static func == (lhs: Meal, rhs: Meal) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
