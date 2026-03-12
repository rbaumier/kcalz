import Foundation

enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "Petit déjeuner"
    case lunch = "Déjeuner"
    case snack = "Goûter"
    case dinner = "Dîner"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .snack: "cup.and.saucer.fill"
        case .dinner: "moon.fill"
        }
    }
}
