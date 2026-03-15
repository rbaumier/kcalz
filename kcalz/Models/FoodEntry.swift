import Foundation

struct FoodEntry: Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var brands: String?
    var grams: Double
    var kcalPer100g: Double
    var proteinsPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var sugarsPer100g: Double?
    var saltPer100g: Double?
    var fiberPer100g: Double?
    var sortOrder: Int

    var kcal: Double { kcalPer100g * grams / 100 }
    var proteins: Double { proteinsPer100g * grams / 100 }
    var carbs: Double { carbsPer100g * grams / 100 }
    var fat: Double { fatPer100g * grams / 100 }
    var sugars: Double { (sugarsPer100g ?? 0) * grams / 100 }
    var salt: Double { (saltPer100g ?? 0) * grams / 100 }
    var fiber: Double { (fiberPer100g ?? 0) * grams / 100 }

    init(
        id: UUID = UUID(),
        name: String,
        brands: String? = nil,
        grams: Double,
        kcalPer100g: Double,
        proteinsPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        sugarsPer100g: Double? = nil,
        saltPer100g: Double? = nil,
        fiberPer100g: Double? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.brands = brands
        self.grams = grams
        self.kcalPer100g = kcalPer100g
        self.proteinsPer100g = proteinsPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.sugarsPer100g = sugarsPer100g
        self.saltPer100g = saltPer100g
        self.fiberPer100g = fiberPer100g
        self.sortOrder = sortOrder
    }

}
