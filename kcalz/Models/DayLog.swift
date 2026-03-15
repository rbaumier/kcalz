import Foundation

/// All meals for a single calendar day.
struct DayLog: Identifiable, Sendable, Equatable {
    /// Unique key derived from the date string (yyyy-MM-dd).
    var id: String { date.kcDateString }
    var date: Date
    var meals: [Meal]

    /// Total kcal across all meals for the day.
    var totalKcal: Double { meals.reduce(0) { $0 + $1.totalKcal } }
    /// Total proteins across all meals for the day.
    var totalProteins: Double { meals.reduce(0) { $0 + $1.totalProteins } }
    /// Total carbs across all meals for the day.
    var totalCarbs: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
    /// Total fat across all meals for the day.
    var totalFat: Double { meals.reduce(0) { $0 + $1.totalFat } }
    /// Total sugars across all meals for the day.
    var totalSugars: Double { meals.reduce(0) { $0 + $1.totalSugars } }
    /// Total salt across all meals for the day.
    var totalSalt: Double { meals.reduce(0) { $0 + $1.totalSalt } }
    /// Total fiber across all meals for the day.
    var totalFiber: Double { meals.reduce(0) { $0 + $1.totalFiber } }

    /// Returns the meal matching the given type, if it exists.
    func meal(for type: MealType) -> Meal? {
        meals.first { $0.type == type }
    }

}
