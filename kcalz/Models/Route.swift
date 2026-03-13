import Foundation

enum Route: Hashable {
    case search(MealType)
    case detail(OFFProduct, MealType)
    case edit(FoodEntry, MealType)
    case goals
    case weight
}
