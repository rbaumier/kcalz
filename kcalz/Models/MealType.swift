import Foundation

/// The four meal slots available in a day.
enum MealType: String, CaseIterable, Identifiable, Sendable {
    case breakfast
    case lunch
    case snack
    case dinner

    var id: String { rawValue }

    /// Localized display name shown in the UI.
    var displayName: String {
        switch self {
        case .breakfast: "Petit déjeuner"
        case .lunch: "Déjeuner"
        case .snack: "Goûter"
        case .dinner: "Dîner"
        }
    }

    /// SF Symbol name for the meal type icon.
    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .snack: "cup.and.saucer.fill"
        case .dinner: "moon.fill"
        }
    }
}
