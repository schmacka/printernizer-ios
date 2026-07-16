import Foundation

/// Central configuration for talking to the Printernizer backend.
/// All services build URLs and JSON coders through this type so the
/// server URL, API version, and snake_case conversion live in one place.
enum APIConfiguration {
    static let apiBasePath = "/api/v1"

    static var serverURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? ""
    }

    /// Whether a usable server URL has been configured.
    static var isConfigured: Bool {
        normalizedServerURL != nil
    }

    /// Sanitized base URL: trimmed, no trailing slash, with `http://`
    /// prepended when the scheme is missing. Returns nil when the URL
    /// is empty or can't produce a valid http(s) URL — callers must not
    /// build requests from it (URLSession raises an Objective-C
    /// exception for WebSocket tasks with unsupported schemes).
    static var normalizedServerURL: String? {
        var base = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return nil }
        while base.hasSuffix("/") { base.removeLast() }

        let lowercased = base.lowercased()
        if !lowercased.hasPrefix("http://") && !lowercased.hasPrefix("https://") {
            base = "http://\(base)"
        }

        guard let url = URL(string: base),
              let host = url.host, !host.isEmpty else { return nil }
        return base
    }

    /// Absolute URL for an API endpoint, e.g. `url("printers")` →
    /// `http://host:8000/api/v1/printers`. Returns nil when no server
    /// URL is configured or the path is invalid.
    static func url(_ path: String, queryItems: [URLQueryItem] = []) -> URL? {
        guard let base = normalizedServerURL else { return nil }
        var components = URLComponents(string: "\(base)\(apiBasePath)/\(path)")
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }

    /// WebSocket endpoint derived from the configured server URL.
    static func websocketURL() -> URL? {
        guard let base = normalizedServerURL else { return nil }
        let wsBase = base
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        return URL(string: "\(wsBase)/ws")
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
