import Foundation

extension Date {
    var relativeDate: String {
        if #available(iOS 13.0, *) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            formatter.dateTimeStyle = .named
            return formatter.localizedString(for: self, relativeTo: Date())
        } else {
            // Fallback on earlier versions
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat="hh:mm a"
            return dateFormatter.string(from: self)
        }
    }
}

extension DateFormatter {
    static var utcTimestampFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat="yyyy-MM-dd'T'HH:mm:ssZZZZ"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter
    }
}

extension String {
    func toDate(dateFormatter: DateFormatter = .utcTimestampFormatter) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat="yyyy-MM-dd'T'HH:mm:ssZZZZ"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.date(from: self)
    }
}
