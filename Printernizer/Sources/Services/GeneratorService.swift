import Foundation

// MARK: - Generator Models

struct GeneratorStatus: Decodable {
    let available: Bool?
    let engine: String?
}

/// Saved parameter preset; the `parameters` payload is only consumed
/// by the web generator, so it isn't decoded here.
struct GeneratorPreset: Decodable, Identifiable {
    let id: String
    let templateId: String
    let name: String
    let createdAt: String?
}

// MARK: - Generator Service

/// The generator's geometry engine runs client-side in the web app
/// (JSCAD); this service only exposes status and saved presets. The
/// full generator UI is embedded via WKWebView (GeneratorView).
@MainActor
final class GeneratorService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
    }

    func status() async throws -> GeneratorStatus {
        try await get("generator/status")
    }

    func listPresets() async throws -> [GeneratorPreset] {
        try await get("generator/presets")
    }

    func deletePreset(id: String) async throws {
        guard let url = APIConfiguration.url("generator/presets/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }

    private func get<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = APIConfiguration.url(endpoint) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        return try decoder.decode(T.self, from: data)
    }
}
