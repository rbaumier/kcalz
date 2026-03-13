import Foundation

struct NutritionGoal: Sendable, Equatable {
    var kcal: Double?
    var proteins: Double?
    var carbs: Double?
    var fat: Double?
    var sugars: Double?
    var salt: Double?

    var isEmpty: Bool {
        kcal == nil && proteins == nil && carbs == nil && fat == nil && sugars == nil && salt == nil
    }
}
