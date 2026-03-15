import Foundation

struct DayLog: Identifiable, Sendable, Equatable {
    var id: String { date.kcDateString }
    var date: Date
    var meals: [Meal]

    var totalKcal: Double { meals.reduce(0) { $0 + $1.totalKcal } }
    var totalProteins: Double { meals.reduce(0) { $0 + $1.totalProteins } }
    var totalCarbs: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double { meals.reduce(0) { $0 + $1.totalFat } }
    var totalSugars: Double { meals.reduce(0) { $0 + $1.totalSugars } }
    var totalSalt: Double { meals.reduce(0) { $0 + $1.totalSalt } }
    var totalFiber: Double { meals.reduce(0) { $0 + $1.totalFiber } }

    func meal(for type: MealType) -> Meal? {
        meals.first { $0.type == type }
    }

    static func == (lhs: DayLog, rhs: DayLog) -> Bool { lhs.id == rhs.id }
}
