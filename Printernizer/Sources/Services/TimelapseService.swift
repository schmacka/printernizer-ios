import SwiftUI

// MARK: - Timelapse Models

struct TimelapseResponse: Codable, Identifiable {
    let id: String
    let folderName: String?
    let status: String?
    let jobId: String?
    let imageCount: Int?
    let videoDuration: Double?
    let fileSizeBytes: Int?
    let errorMessage: String?
    let pinned: Bool?
    let videoExists: Bool?
    let createdAt: String?

    var statusColor: Color {
        switch (status ?? "").lowercased() {
        case "completed": return .green
        case "processing": return .blue
        case "pending", "discovered": return .orange
        case "failed": return .red
        default: return .gray
        }
    }

    var displayName: String {
        folderName ?? id
    }

    var formattedSize: String? {
        guard let bytes = fileSizeBytes, bytes > 0 else { return nil }
        if bytes >= 1_000_000_000 {
            return String(format: "%.2f GB", Double(bytes) / 1_000_000_000)
        }
        return String(format: "%.1f MB", Double(bytes) / 1_000_000)
    }

    var formattedDuration: String? {
        guard let seconds = videoDuration, seconds > 0 else { return nil }
        return String(format: "%.0f s", seconds)
    }
}

struct TimelapseStats: Codable {
    let totalVideos: Int?
    let totalSizeBytes: Int?
    let processingCount: Int?
    let completedCount: Int?
    let failedCount: Int?
    let cleanupCandidatesCount: Int?
    let totalSizeMb: Double?
    let totalSizeGb: Double?
}

// MARK: - Timelapse Service

@MainActor
final class TimelapseService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    func listTimelapses(status: String? = nil, linkedOnly: Bool = false) async throws -> [TimelapseResponse] {
        var queryItems: [URLQueryItem] = []
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if linkedOnly {
            queryItems.append(URLQueryItem(name: "linked_only", value: "true"))
        }

        guard let url = APIConfiguration.url("timelapses", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode([TimelapseResponse].self, from: data)
    }

    func stats() async throws -> TimelapseStats {
        guard let url = APIConfiguration.url("timelapses/stats") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(TimelapseStats.self, from: data)
    }

    /// Streaming URL for the rendered video (inline playback).
    func videoURL(id: String) -> URL? {
        APIConfiguration.url("timelapses/\(id)/video")
    }

    /// Triggers (re)processing of a timelapse's source images.
    func process(id: String) async throws {
        try await post("timelapses/\(id)/process")
    }

    func togglePin(id: String) async throws {
        guard let url = APIConfiguration.url("timelapses/\(id)/pin") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    func linkToJob(id: String, jobId: String) async throws {
        struct LinkRequest: Codable {
            let jobId: String
        }

        guard let url = APIConfiguration.url("timelapses/\(id)/link") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(LinkRequest(jobId: jobId))

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    func delete(id: String) async throws {
        guard let url = APIConfiguration.url("timelapses/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    func bulkDelete(ids: [String]) async throws {
        struct BulkDeleteRequest: Codable {
            let timelapseIds: [String]
        }

        guard let url = APIConfiguration.url("timelapses/bulk-delete") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(BulkDeleteRequest(timelapseIds: ids))

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    private func post(_ endpoint: String) async throws {
        guard let url = APIConfiguration.url(endpoint) else {
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
