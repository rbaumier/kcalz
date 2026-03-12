import Foundation

struct Meal: Identifiable {
    let id = UUID()
    var type: MealType
    var entries: [FoodEntry]

    var totalKcal: Double { entries.reduce(0) { $0 + $1.kcal } }
    var totalProteins: Double { entries.reduce(0) { $0 + $1.proteins } }
    var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { entries.reduce(0) { $0 + $1.fat } }
}
