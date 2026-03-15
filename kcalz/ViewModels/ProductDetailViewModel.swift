import Foundation

/// Holds nutritional data for a product and computes scaled values for a given portion.
@Observable
@MainActor
final class ProductDetailViewModel {
    let name: String
    let brands: String?
    let productCode: String?
    var kcalPer100g: Double
    var proteinsPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var sugarsPer100g: Double?
    var saltPer100g: Double?
    var fiberPer100g: Double?
    let existingEntryId: UUID?
    let isIncomplete: Bool

    var kcalText: String
    var proteinsText: String
    var carbsText: String
    var fatText: String
    var sugarsText: String
    var saltText: String
    var fiberText: String

    var gramsText: String

    private static let defaultPortionGrams: Double = 100

    /// True when editing an existing diary entry (vs. creating a new one).
    var isEditing: Bool { existingEntryId != nil }

    /// Initializes from an OFF product, optionally applying a user override for nutritional values.
    init(product: OFFProduct, override: UserStore.ProductOverride? = nil) {
        self.name = product.name
        self.brands = product.brands
        self.productCode = product.code
        self.existingEntryId = nil

        if let existingOverride = override {
            self.kcalPer100g = existingOverride.kcal
            self.proteinsPer100g = existingOverride.proteins ?? 0
            self.carbsPer100g = existingOverride.carbs ?? 0
            self.fatPer100g = existingOverride.fat ?? 0
            self.sugarsPer100g = existingOverride.sugars
            self.saltPer100g = existingOverride.salt
            self.fiberPer100g = existingOverride.fiber
            self.isIncomplete = false
        } else if product.kcal != nil {
            self.kcalPer100g = product.kcal ?? 0
            self.proteinsPer100g = product.proteins ?? 0
            self.carbsPer100g = product.carbs ?? 0
            self.fatPer100g = product.fat ?? 0
            self.sugarsPer100g = product.sugars
            self.saltPer100g = product.salt
            self.fiberPer100g = product.fiber
            self.isIncomplete = false
        } else {
            self.kcalPer100g = 0
            self.proteinsPer100g = 0
            self.carbsPer100g = 0
            self.fatPer100g = 0
            self.sugarsPer100g = nil
            self.saltPer100g = nil
            self.fiberPer100g = nil
            self.isIncomplete = true
        }

        self.kcalText = ""
        self.proteinsText = ""
        self.carbsText = ""
        self.fatText = ""
        self.sugarsText = ""
        self.saltText = ""
        self.fiberText = ""

        let defaultGrams = Self.defaultGrams(product: product)
        self.gramsText = defaultGrams.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(defaultGrams))
            : String(defaultGrams)
    }

    /// Initializes from an existing food entry, optionally in editing mode.
    init(entry: FoodEntry, editing: Bool = false) {
        self.name = entry.name
        self.brands = entry.brands
        self.productCode = nil
        self.isIncomplete = false
        self.kcalPer100g = entry.kcalPer100g
        self.proteinsPer100g = entry.proteinsPer100g
        self.carbsPer100g = entry.carbsPer100g
        self.fatPer100g = entry.fatPer100g
        self.sugarsPer100g = entry.sugarsPer100g
        self.saltPer100g = entry.saltPer100g
        self.fiberPer100g = entry.fiberPer100g
        self.existingEntryId = editing ? entry.id : nil
        self.kcalText = ""
        self.proteinsText = ""
        self.carbsText = ""
        self.fatText = ""
        self.sugarsText = ""
        self.saltText = ""
        self.fiberText = ""
        self.gramsText = entry.grams.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(entry.grams))
            : String(entry.grams)
    }

    /// Parsed portion weight in grams, nil if invalid.
    var grams: Double? {
        guard let value = Double(gramsText), value > 0 else { return nil }
        return value
    }

    /// True when all required fields are filled (grams + kcal for incomplete products).
    var isValidInput: Bool {
        guard grams != nil else { return false }
        if isIncomplete {
            return Double(kcalText) != nil
        }
        return true
    }

    /// Scaled kcal for the current portion.
    var kcal: Double { scaled(kcalPer100g) }
    /// Scaled proteins for the current portion.
    var proteins: Double { scaled(proteinsPer100g) }
    /// Scaled carbs for the current portion.
    var carbs: Double { scaled(carbsPer100g) }
    /// Scaled fat for the current portion.
    var fat: Double { scaled(fatPer100g) }
    /// Scaled sugars for the current portion.
    var sugars: Double { scaled(sugarsPer100g) }
    /// Scaled salt for the current portion.
    var salt: Double { scaled(saltPer100g) }
    /// Scaled fiber for the current portion.
    var fiber: Double { scaled(fiberPer100g) }

    /// Scales a per-100g value to the current portion size.
    private func scaled(_ valuePer100g: Double?) -> Double {
        (valuePer100g ?? 0) * (grams ?? 0) / Self.defaultPortionGrams
    }

    /// Commits user-typed nutritional overrides into the per-100g fields.
    /// Must be called before `makeFoodEntry()` so the entry captures edited values.
    func applyOverrideTexts() {
        if isIncomplete {
            kcalPer100g = Double(kcalText) ?? 0
            proteinsPer100g = Double(proteinsText) ?? 0
            carbsPer100g = Double(carbsText) ?? 0
            fatPer100g = Double(fatText) ?? 0
            sugarsPer100g = Double(sugarsText)
            saltPer100g = Double(saltText)
            fiberPer100g = Double(fiberText)
        }
    }

    /// Derives the default portion from the product's declared quantity.
    static func defaultGrams(product: OFFProduct) -> Double {
        guard let value = product.product_quantity, value > 0 else { return defaultPortionGrams }
        let unit = product.product_quantity_unit?.lowercased() ?? "g"
        let grams = switch unit {
        case "kg": value * 1000
        case "l": value * 1000
        case "cl": value * 10
        // ml → 1:1 with grams — density ≈ 1 for most beverages.
        case "ml": value
        default: value // "g"
        }
        return grams > 0 ? grams : defaultPortionGrams
    }

    /// Builds a `FoodEntry` from the current state; reuses `existingEntryId` when editing.
    func makeFoodEntry() -> FoodEntry {
        FoodEntry(
            id: existingEntryId ?? UUID(),
            name: name,
            brands: brands,
            grams: grams ?? 0,
            kcalPer100g: kcalPer100g,
            proteinsPer100g: proteinsPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g,
            sugarsPer100g: sugarsPer100g,
            saltPer100g: saltPer100g,
            fiberPer100g: fiberPer100g
        )
    }
}
