import Foundation

/// Central configuration for talking to the Printernizer backend.
/// All services build URLs and JSON coders through this type so the
/// server URL, API version, and snake_case conversion live in one place.
enum APIConfiguration {
    static let apiBasePath = "/api/v1"

    static var serverURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? ""
    }

    /// Absolute URL for an API endpoint, e.g. `url("printers")` →
    /// `http://host:8000/api/v1/printers`. Returns nil when no server
    /// URL is configured or the path is invalid.
    static func url(_ path: String, queryItems: [URLQueryItem] = []) -> URL? {
        guard !serverURL.isEmpty else { return nil }
        var components = URLComponents(string: "\(serverURL)\(apiBasePath)/\(path)")
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }

    /// WebSocket endpoint derived from the configured server URL.
    static func websocketURL() -> URL? {
        guard !serverURL.isEmpty else { return nil }
        let wsBase = serverURL
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
