import SwiftUI

// MARK: - Idea Models

enum IdeaStatus: String, Codable, CaseIterable, Identifiable {
    case idea
    case planned
    case printing
    case completed
    case archived

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .idea: return "Idea"
        case .planned: return "Planned"
        case .printing: return "Printing"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }

    var color: Color {
        switch self {
        case .idea: return .purple
        case .planned: return .orange
        case .printing: return .blue
        case .completed: return .green
        case .archived: return .gray
        }
    }
}

struct IdeaResponse: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let sourceType: String?
    let sourceUrl: String?
    let thumbnailPath: String?
    let category: String?
    let priority: Int?
    let status: String?
    let isBusiness: Bool?
    let estimatedPrintTime: Int?
    let materialNotes: String?
    let customerInfo: String?
    let plannedDate: String?
    let completedDate: String?
    let tags: [String]?
    let createdAt: String?
    let updatedAt: String?

    var ideaStatus: IdeaStatus {
        status.flatMap(IdeaStatus.init(rawValue:)) ?? .idea
    }
}

struct IdeaListResponse: Codable {
    let ideas: [IdeaResponse]
    let page: Int?
    let pageSize: Int?
    let hasMore: Bool?
}

struct IdeaCreateRequest: Codable {
    let title: String
    let description: String?
    let category: String?
    let priority: Int
    let isBusiness: Bool
    let estimatedPrintTime: Int?
    let materialNotes: String?
    let customerInfo: String?
    let plannedDate: String?
    let tags: [String]
}

struct IdeaUpdateRequest: Codable {
    let title: String?
    let description: String?
    let category: String?
    let priority: Int?
    let isBusiness: Bool?
    let estimatedPrintTime: Int?
    let materialNotes: String?
    let customerInfo: String?
    let plannedDate: String?
    let tags: [String]?
}

struct IdeaImportRequest: Codable {
    let url: String
    let title: String?
    let description: String?
    let category: String?
    let priority: Int
    let isBusiness: Bool
    let tags: [String]
}

struct UrlPreviewResponse: Codable {
    struct Preview: Codable {
        let title: String?
        let platform: String?
        let creator: String?
    }

    let url: String?
    let preview: Preview?
}

// MARK: - Idea Service

/// Idea board: print ideas and bookmarks, including URL import from
/// model platforms (MakerWorld, Printables, ...).
@MainActor
final class IdeaService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    func listIdeas(
        status: IdeaStatus? = nil,
        isBusiness: Bool? = nil,
        sourceType: String? = nil,
        page: Int = 1,
        pageSize: Int = 50
    ) async throws -> IdeaListResponse {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let isBusiness {
            queryItems.append(URLQueryItem(name: "is_business", value: String(isBusiness)))
        }
        if let sourceType {
            queryItems.append(URLQueryItem(name: "source_type", value: sourceType))
        }

        guard let url = APIConfiguration.url("ideas", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(IdeaListResponse.self, from: data)
    }

    func getIdea(id: String) async throws -> IdeaResponse {
        guard let url = APIConfiguration.url("ideas/\(id)") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(IdeaResponse.self, from: data)
    }

    func createIdea(_ idea: IdeaCreateRequest) async throws {
        try await send("ideas", method: "POST", body: idea)
    }

    func updateIdea(id: String, update: IdeaUpdateRequest) async throws {
        try await send("ideas/\(id)", method: "PUT", body: update)
    }

    func updateStatus(id: String, status: IdeaStatus) async throws {
        struct StatusUpdate: Codable {
            let status: String
        }
        try await send("ideas/\(id)/status", method: "PATCH", body: StatusUpdate(status: status.rawValue))
    }

    func deleteIdea(id: String) async throws {
        guard let url = APIConfiguration.url("ideas/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    func importIdea(_ importRequest: IdeaImportRequest) async throws {
        try await send("ideas/import", method: "POST", body: importRequest)
    }

    /// Previews the metadata the backend would extract from a model
    /// platform URL, for auto-filling the idea form.
    func previewUrl(_ urlString: String) async throws -> UrlPreviewResponse {
        struct PreviewRequest: Codable {
            let url: String
        }

        guard let url = APIConfiguration.url("ideas/url/preview") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(PreviewRequest(url: urlString))

        let (data, response) = try await session.data(for: request)
        try checkStatus(response)
        return try decoder.decode(UrlPreviewResponse.self, from: data)
    }

    // MARK: - Private Helpers

    private func send<Body: Encodable>(_ endpoint: String, method: String, body: Body) async throws {
        guard let url = APIConfiguration.url(endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

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

extension IdeaResponse {
    static let preview = IdeaResponse(
        id: "idea-1",
        title: "Articulated Dragon",
        description: "Flexible print-in-place dragon",
        sourceType: "makerworld",
        sourceUrl: "https://makerworld.com/models/12345",
        thumbnailPath: nil,
        category: "Toys",
        priority: 4,
        status: "planned",
        isBusiness: false,
        estimatedPrintTime: 240,
        materialNotes: "PLA Silk, ~80 g",
        customerInfo: nil,
        plannedDate: nil,
        completedDate: nil,
        tags: ["dragon", "flexi"],
        createdAt: "2026-07-18T10:00:00",
        updatedAt: "2026-07-18T10:00:00"
    )
}
