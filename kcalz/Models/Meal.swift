import Foundation

struct Meal: Identifiable, Sendable, Hashable {
    var id: String { type.rawValue }
    var type: MealType
    var entries: [FoodEntry]

    var totalKcal: Double { entries.reduce(0) { $0 + $1.kcal } }
    var totalProteins: Double { entries.reduce(0) { $0 + $1.proteins } }
    var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { entries.reduce(0) { $0 + $1.fat } }
    var totalSugars: Double { entries.reduce(0) { $0 + $1.sugars } }
    var totalSalt: Double { entries.reduce(0) { $0 + $1.salt } }
    var totalFiber: Double { entries.reduce(0) { $0 + $1.fiber } }

    static func == (lhs: Meal, rhs: Meal) -> Bool { lhs.type == rhs.type }
    func hash(into hasher: inout Hasher) { hasher.combine(type) }
}
