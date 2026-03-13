import Foundation

@Observable
@MainActor
final class ProductDetailViewModel {
    let name: String
    let brands: String?
    let kcalPer100g: Double
    let proteinsPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let sugarsPer100g: Double?
    let saltPer100g: Double?
    let existingEntryId: UUID?

    var gramsText: String

    var isEditing: Bool { existingEntryId != nil }

    init(product: OFFProduct) {
        self.name = product.name
        self.brands = product.brands
        self.kcalPer100g = product.kcal ?? 0
        self.proteinsPer100g = product.proteins ?? 0
        self.carbsPer100g = product.carbs ?? 0
        self.fatPer100g = product.fat ?? 0
        self.sugarsPer100g = product.sugars
        self.saltPer100g = product.salt
        self.existingEntryId = nil
        self.gramsText = "100"
    }

    init(entry: FoodEntry) {
        self.name = entry.name
        self.brands = nil
        self.kcalPer100g = entry.kcalPer100g
        self.proteinsPer100g = entry.proteinsPer100g
        self.carbsPer100g = entry.carbsPer100g
        self.fatPer100g = entry.fatPer100g
        self.sugarsPer100g = entry.sugarsPer100g
        self.saltPer100g = entry.saltPer100g
        self.existingEntryId = entry.id
        self.gramsText = entry.grams.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(entry.grams))
            : String(entry.grams)
    }

    var grams: Double? {
        guard let v = Double(gramsText), v > 0 else { return nil }
        return v
    }

    var isValidInput: Bool { grams != nil }

    var kcal: Double { scaled(kcalPer100g) }
    var proteins: Double { scaled(proteinsPer100g) }
    var carbs: Double { scaled(carbsPer100g) }
    var fat: Double { scaled(fatPer100g) }
    var sugars: Double { scaled(sugarsPer100g) }
    var salt: Double { scaled(saltPer100g) }

    private func scaled(_ valuePer100g: Double?) -> Double {
        (valuePer100g ?? 0) * (grams ?? 0) / 100
    }

    func makeFoodEntry() -> FoodEntry {
        FoodEntry(
            id: existingEntryId ?? UUID(),
            name: name,
            grams: grams ?? 0,
            kcalPer100g: kcalPer100g,
            proteinsPer100g: proteinsPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g,
            sugarsPer100g: sugarsPer100g,
            saltPer100g: saltPer100g
        )
    }
}
