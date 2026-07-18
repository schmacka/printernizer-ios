import Foundation

/// Shared formatters for currency, weights, and backend timestamps.
/// Costs are displayed in EUR — the backend computes and stores all
/// monetary values in EUR (German business context).
enum Formatters {
    static let eur: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter
    }()

    static func eurString(_ value: Double) -> String {
        eur.string(from: NSNumber(value: value)) ?? String(format: "%.2f €", value)
    }

    /// Formats a weight given in kilograms; values below 1 kg are
    /// shown in grams.
    static func weightKg(_ kilograms: Double) -> String {
        if kilograms < 1 {
            return String(format: "%.0f g", kilograms * 1000)
        }
        return String(format: "%.2f kg", kilograms)
    }

    /// Formats a weight given in grams.
    static func weightGrams(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.2f kg", grams / 1000)
        }
        return String(format: "%.0f g", grams)
    }

    /// Parses a backend ISO8601 timestamp, with and without
    /// fractional seconds, with and without timezone designator.
    static func parseISODate(_ string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: string) {
            return date
        }

        // Backend sometimes emits naive timestamps without a timezone
        // (e.g. "2026-07-18T10:00:00"); treat them as local time.
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = fallback.date(from: string) {
            return date
        }
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return fallback.date(from: string)
    }

    /// Medium date + short time display for a backend timestamp, or
    /// nil when the string can't be parsed.
    static func mediumDateTime(_ string: String?) -> String? {
        guard let string, let date = parseISODate(string) else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func duration(minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}
