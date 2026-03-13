import Foundation

@Observable
@MainActor
final class ProductDetailViewModel {
    let product: OFFProduct
    var gramsText = "100"

    init(product: OFFProduct) {
        self.product = product
    }

    var grams: Double {
        Double(gramsText) ?? 0
    }

    var kcal: Double { (product.kcal ?? 0) * grams / 100 }
    var proteins: Double { (product.proteins ?? 0) * grams / 100 }
    var carbs: Double { (product.carbs ?? 0) * grams / 100 }
    var fat: Double { (product.fat ?? 0) * grams / 100 }
    var sugars: Double { (product.sugars ?? 0) * grams / 100 }
    var salt: Double { (product.salt ?? 0) * grams / 100 }

    func makeFoodEntry() -> FoodEntry {
        FoodEntry(
            name: product.name,
            grams: grams,
            kcalPer100g: product.kcal ?? 0,
            proteinsPer100g: product.proteins ?? 0,
            carbsPer100g: product.carbs ?? 0,
            fatPer100g: product.fat ?? 0,
            sugarsPer100g: product.sugars,
            saltPer100g: product.salt
        )
    }
}
