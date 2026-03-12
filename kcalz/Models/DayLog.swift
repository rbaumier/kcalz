import Foundation

struct DayLog: Identifiable {
    let id = UUID()
    var date: Date
    var meals: [Meal]
    var weight: Double?

    var totalKcal: Double { meals.reduce(0) { $0 + $1.totalKcal } }
    var totalProteins: Double { meals.reduce(0) { $0 + $1.totalProteins } }
    var totalCarbs: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double { meals.reduce(0) { $0 + $1.totalFat } }

    func meal(for type: MealType) -> Meal? {
        meals.first { $0.type == type }
    }
}
