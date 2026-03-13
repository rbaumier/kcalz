import Foundation

@Observable
@MainActor
final class ProductDetailViewModel {
    let product: OFFProduct
    var gramsText = "100"

    init(product: OFFProduct) {
        self.product = product
    }

    var grams: Double? {
        guard let v = Double(gramsText), v > 0 else { return nil }
        return v
    }

    var isValidInput: Bool { grams != nil }

    var kcal: Double { scaled(product.kcal) }
    var proteins: Double { scaled(product.proteins) }
    var carbs: Double { scaled(product.carbs) }
    var fat: Double { scaled(product.fat) }
    var sugars: Double { scaled(product.sugars) }
    var salt: Double { scaled(product.salt) }

    private func scaled(_ valuePer100g: Double?) -> Double {
        (valuePer100g ?? 0) * (grams ?? 0) / 100
    }

    func makeFoodEntry() -> FoodEntry {
        FoodEntry(
            name: product.name,
            grams: grams ?? 0,
            kcalPer100g: product.kcal ?? 0,
            proteinsPer100g: product.proteins ?? 0,
            carbsPer100g: product.carbs ?? 0,
            fatPer100g: product.fat ?? 0,
            sugarsPer100g: product.sugars,
            saltPer100g: product.salt
        )
    }
}
