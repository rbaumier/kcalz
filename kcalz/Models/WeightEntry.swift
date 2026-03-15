import Foundation

/// A single body weight measurement for a given day.
struct WeightEntry: Identifiable, Sendable {
    /// Date string "yyyy-MM-dd" used as unique key.
    let id: String
    let date: Date
    /// Body weight in kilograms.
    let kg: Double
}
