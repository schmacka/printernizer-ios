import SwiftUI

// MARK: - Log Models

struct LogEntry: Codable, Identifiable {
    let id: String
    let source: String?
    let timestamp: String?
    let level: String?
    let category: String?
    let message: String

    var levelColor: Color {
        switch (level ?? "").lowercased() {
        case "debug": return .gray
        case "info": return .blue
        case "warn", "warning": return .orange
        case "error", "critical": return .red
        default: return .secondary
        }
    }
}

struct LogQueryResult: Codable {
    struct Pagination: Codable {
        let page: Int?
        let totalPages: Int?
    }

    let data: [LogEntry]
    let pagination: Pagination?
}

// MARK: - Log Service

/// Unified server log viewer (GET/DELETE /logs).
@MainActor
final class LogService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
    }

    func queryLogs(
        source: String? = nil,
        level: String? = nil,
        search: String? = nil,
        page: Int = 1,
        perPage: Int = 50
    ) async throws -> LogQueryResult {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        if let source {
            queryItems.append(URLQueryItem(name: "source", value: source))
        }
        if let level {
            queryItems.append(URLQueryItem(name: "level", value: level))
        }
        if let search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }

        guard let url = APIConfiguration.url("logs", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(LogQueryResult.self, from: data)
    }

    func clearLogs() async throws {
        guard let url = APIConfiguration.url("logs") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    private func checkStatus(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}
