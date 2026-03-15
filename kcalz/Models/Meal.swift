import Foundation

/// A group of food entries under one meal type (breakfast, lunch, etc.).
struct Meal: Identifiable, Sendable, Hashable {
    var id: String { type.rawValue }
    var type: MealType
    var entries: [FoodEntry]

    /// Sum of kcal across all entries in this meal.
    var totalKcal: Double { entries.reduce(0) { $0 + $1.kcal } }
    /// Sum of proteins across all entries.
    var totalProteins: Double { entries.reduce(0) { $0 + $1.proteins } }
    /// Sum of carbs across all entries.
    var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    /// Sum of fat across all entries.
    var totalFat: Double { entries.reduce(0) { $0 + $1.fat } }
    /// Sum of sugars across all entries.
    var totalSugars: Double { entries.reduce(0) { $0 + $1.sugars } }
    /// Sum of salt across all entries.
    var totalSalt: Double { entries.reduce(0) { $0 + $1.salt } }
    /// Sum of fiber across all entries.
    var totalFiber: Double { entries.reduce(0) { $0 + $1.fiber } }

}
