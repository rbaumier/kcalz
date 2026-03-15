import Foundation

/// Daily macro targets set by the user (nil = no target for that nutrient).
struct NutritionGoal: Sendable, Equatable {
    var kcal: Double?
    var proteins: Double?
    var carbs: Double?
    var fat: Double?
    var sugars: Double?
    var salt: Double?

    init(kcal: Double? = nil, proteins: Double? = nil, carbs: Double? = nil, fat: Double? = nil, sugars: Double? = nil, salt: Double? = nil) {
        self.kcal = kcal
        self.proteins = proteins
        self.carbs = carbs
        self.fat = fat
        self.sugars = sugars
        self.salt = salt
    }

    /// True when the user hasn't configured any target yet.
    var isEmpty: Bool {
        kcal == nil && proteins == nil && carbs == nil && fat == nil && sugars == nil && salt == nil
    }
}
