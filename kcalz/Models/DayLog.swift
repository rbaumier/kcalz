import Foundation

struct DayLog: Identifiable, Sendable, Equatable {
    let id = UUID()
    var date: Date
    var meals: [Meal]

    var totalKcal: Double { meals.reduce(0) { $0 + $1.totalKcal } }
    var totalProteins: Double { meals.reduce(0) { $0 + $1.totalProteins } }
    var totalCarbs: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double { meals.reduce(0) { $0 + $1.totalFat } }

    func meal(for type: MealType) -> Meal? {
        meals.first { $0.type == type }
    }

    static func == (lhs: DayLog, rhs: DayLog) -> Bool { lhs.id == rhs.id }
}
