import Foundation

// MARK: - Tag Models

struct TagResponse: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let color: String?
    let description: String?
    let usageCount: Int?
}

struct TagListResponse: Codable {
    let tags: [TagResponse]
    let total: Int?
}

// MARK: - Tag Service

/// Library tag management: create tags and assign/remove them on
/// library files. Tag assignment uses query parameters (backend
/// contract of /tags/file/{checksum}/assign|remove).
@MainActor
final class TagService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    func listTags() async throws -> [TagResponse] {
        guard let url = APIConfiguration.url("tags") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(TagListResponse.self, from: data).tags
    }

    func createTag(name: String, color: String? = nil) async throws -> TagResponse {
        struct TagCreateRequest: Codable {
            let name: String
            let color: String?
        }

        guard let url = APIConfiguration.url("tags") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(TagCreateRequest(name: name, color: color))

        let (data, response) = try await session.data(for: request)
        try checkStatus(response)
        return try decoder.decode(TagResponse.self, from: data)
    }

    func deleteTag(id: String) async throws {
        guard let url = APIConfiguration.url("tags/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    /// Tags currently assigned to a file, with their IDs.
    func fileTags(checksum: String) async throws -> [TagResponse] {
        struct FileTagsResponse: Codable {
            let tags: [TagResponse]
        }

        guard let url = APIConfiguration.url("tags/file/\(checksum)") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(FileTagsResponse.self, from: data).tags
    }

    func assignTags(checksum: String, tagIds: [String]) async throws {
        try await postWithTagIds("tags/file/\(checksum)/assign", tagIds: tagIds)
    }

    func removeTags(checksum: String, tagIds: [String]) async throws {
        try await postWithTagIds("tags/file/\(checksum)/remove", tagIds: tagIds)
    }

    private func postWithTagIds(_ endpoint: String, tagIds: [String]) async throws {
        guard !tagIds.isEmpty else { return }
        let queryItems = tagIds.map { URLQueryItem(name: "tag_ids", value: $0) }
        guard let url = APIConfiguration.url(endpoint, queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

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
