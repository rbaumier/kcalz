import Foundation

struct WeightEntry: Identifiable, Sendable {
    let id: String // date string "yyyy-MM-dd"
    let date: Date
    let kg: Double
}
