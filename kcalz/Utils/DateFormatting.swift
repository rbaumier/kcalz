import Foundation

extension Date {
    var kcDateString: String {
        Self.kcDateFormatter.string(from: self)
    }

    static func fromKcDateString(_ s: String) -> Date? {
        kcDateFormatter.date(from: s)
    }

    private static let kcDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()
}
