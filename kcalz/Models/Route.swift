import Foundation

/// Navigation routes for the main NavigationStack.
enum Route: Hashable {
    case search(mealType: MealType)
    case scan(mealType: MealType)
    case createFood(query: String, mealType: MealType)
    case freeEntry(mealType: MealType)
    case detail(product: OFFProduct, mealType: MealType)
    case addRecent(entry: FoodEntry, mealType: MealType)
    case edit(entry: FoodEntry, mealType: MealType)
    case mealDetail(meal: Meal)
    case goals
    case weight
}
