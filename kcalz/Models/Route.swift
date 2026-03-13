import Foundation

enum Route: Hashable {
    case search(MealType)
    case detail(OFFProduct, MealType)
    case addRecent(FoodEntry, MealType)
    case edit(FoodEntry, MealType)
    case mealDetail(Meal)
    case goals
    case weight
}
