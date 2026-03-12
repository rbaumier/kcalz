import Foundation

struct FoodEntry: Identifiable {
    let id = UUID()
    var name: String
    var grams: Double
    var kcalPer100g: Double
    var proteinsPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var sugarsPer100g: Double?
    var saltPer100g: Double?

    var kcal: Double { kcalPer100g * grams / 100 }
    var proteins: Double { proteinsPer100g * grams / 100 }
    var carbs: Double { carbsPer100g * grams / 100 }
    var fat: Double { fatPer100g * grams / 100 }
}
