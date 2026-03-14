import Foundation

enum Route: Hashable {
    case search(MealType)
    case scan(MealType)
    case createFood(String, MealType)
    case detail(OFFProduct, MealType)
    case addRecent(FoodEntry, MealType)
    case edit(FoodEntry, MealType)
    case mealDetail(Meal)
    case goals
    case weight
}
