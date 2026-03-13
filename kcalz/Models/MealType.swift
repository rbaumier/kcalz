import Foundation

enum MealType: String, CaseIterable, Identifiable, Sendable {
    case breakfast
    case lunch
    case snack
    case dinner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: "Petit déjeuner"
        case .lunch: "Déjeuner"
        case .snack: "Goûter"
        case .dinner: "Dîner"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .snack: "cup.and.saucer.fill"
        case .dinner: "moon.fill"
        }
    }
}
