import Foundation

/// Date ↔ ISO string (`yyyy-MM-dd`) conversions used as storage keys.
extension Date {
    /// Formats the date as `"yyyy-MM-dd"` for use as a SwiftData / dictionary key.
    var kcDateString: String {
        Self.kcDateFormatter.string(from: self)
    }

    /// Parses a `"yyyy-MM-dd"` string back into a `Date`, returning `nil` on failure.
    static func fromKcDateString(_ s: String) -> Date? {
        kcDateFormatter.date(from: s)
    }

    /// Shared POSIX formatter — locale-proof, uses device time zone.
    private static let kcDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()
}
