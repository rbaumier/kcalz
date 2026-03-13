import Foundation

enum PreviewData {
    static let goal = (kcal: 2200, proteins: 140.0, carbs: 250.0, fat: 80.0)

    static let dayLog = DayLog(
        date: .now,
        meals: [
            Meal(type: .breakfast, entries: []),
            Meal(type: .lunch, entries: []),
            Meal(type: .snack, entries: []),
            Meal(type: .dinner, entries: []),
        ]
    )
}
