import Foundation

// MARK: - Search Models

struct SearchResultItem: Codable, Identifiable {
    let id: String
    let source: String?
    let resultType: String?
    let title: String
    let description: String?
    let relevanceScore: Double?
    let externalUrl: String?
    let fileSize: Int?
    let printTimeMinutes: Int?
    let costEur: Double?
}

struct SearchResultGroup: Codable {
    let source: String
    let results: [SearchResultItem]
    let totalCount: Int?
    let hasMore: Bool?
}

struct SearchResults: Codable {
    let query: String?
    let groups: [SearchResultGroup]
    let totalResults: Int?
    let searchTimeMs: Int?
}

struct SearchSuggestion: Codable, Identifiable {
    let text: String
    let type: String?

    var id: String { text }
}

// MARK: - Search Service

/// Unified search across library files and ideas (GET /api/v1/search).
@MainActor
final class SearchService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
    }

    func search(query: String, page: Int = 1, limit: Int = 50) async throws -> SearchResults {
        let queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = APIConfiguration.url("search", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(SearchResults.self, from: data)
    }

    func suggestions(prefix: String) async throws -> [SearchSuggestion] {
        let queryItems = [URLQueryItem(name: "q", value: prefix)]
        guard let url = APIConfiguration.url("search/suggestions", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode([SearchSuggestion].self, from: data)
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
