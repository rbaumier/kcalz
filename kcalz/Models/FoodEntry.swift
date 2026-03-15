import Foundation

/// A single food item added to a meal, with nutrients stored per 100g.
struct FoodEntry: Identifiable, Sendable, Hashable {
    /// Reference base for per-100g nutrient calculations.
    static let per100gBase: Double = 100

    let id: UUID
    var name: String
    var brands: String?
    /// Portion weight in grams as entered by the user.
    var grams: Double
    var kcalPer100g: Double
    var proteinsPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var sugarsPer100g: Double?
    var saltPer100g: Double?
    var fiberPer100g: Double?
    /// Position within its parent meal for stable ordering.
    var sortOrder: Int

    /// Calories for the actual portion (grams x kcalPer100g / 100).
    var kcal: Double { kcalPer100g * grams / Self.per100gBase }
    /// Proteins in grams for the actual portion.
    var proteins: Double { proteinsPer100g * grams / Self.per100gBase }
    /// Carbs in grams for the actual portion.
    var carbs: Double { carbsPer100g * grams / Self.per100gBase }
    /// Fat in grams for the actual portion.
    var fat: Double { fatPer100g * grams / Self.per100gBase }
    /// Sugars in grams for the actual portion, defaults to 0 if unknown.
    var sugars: Double { (sugarsPer100g ?? 0) * grams / Self.per100gBase }
    /// Salt in grams for the actual portion, defaults to 0 if unknown.
    var salt: Double { (saltPer100g ?? 0) * grams / Self.per100gBase }
    /// Fiber in grams for the actual portion, defaults to 0 if unknown.
    var fiber: Double { (fiberPer100g ?? 0) * grams / Self.per100gBase }

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
