import Foundation

enum PreviewData {
    static let goal = NutritionGoal(kcal: 2200, proteins: 140, carbs: 250, fat: 80)

    static let dayLog = DayLog(
        date: .now,
        meals: [
            Meal(type: .breakfast, entries: []),
            Meal(type: .lunch, entries: []),
            Meal(type: .snack, entries: []),
            Meal(type: .dinner, entries: []),
        ]
    )

    static let dayLogWithEntries = DayLog(
        date: .now,
        meals: [
            Meal(type: .breakfast, entries: [
                FoodEntry(name: "Flocons d'avoine", grams: 80, kcalPer100g: 379, proteinsPer100g: 13.5, carbsPer100g: 67.7, fatPer100g: 6.5),
                FoodEntry(name: "Lait demi-écrémé", grams: 200, kcalPer100g: 46, proteinsPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 1.6),
            ]),
            Meal(type: .lunch, entries: [
                FoodEntry(name: "Poulet grillé", grams: 150, kcalPer100g: 165, proteinsPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
                FoodEntry(name: "Riz basmati", grams: 200, kcalPer100g: 130, proteinsPer100g: 2.7, carbsPer100g: 28.2, fatPer100g: 0.3),
            ]),
            Meal(type: .snack, entries: []),
            Meal(type: .dinner, entries: []),
        ]
    )
}
