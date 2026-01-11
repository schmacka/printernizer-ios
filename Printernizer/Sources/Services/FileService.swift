import Foundation
import SwiftUI

// MARK: - File API Response Models

struct FileResponse: Codable, Identifiable {
    let id: String
    let printerId: String?
    let filename: String
    let source: String
    let status: String
    let fileSize: Int?
    let filePath: String?
    let fileType: String?
    let downloadedAt: String?
    let createdAt: String?
    let watchFolderPath: String?
    let relativePath: String?
    let modifiedTime: String?
    let hasThumbnail: Bool
    let thumbnailWidth: Int?
    let thumbnailHeight: Int?
    let thumbnailFormat: String?
}

struct FilePagination: Codable {
    let page: Int
    let limit: Int
    let totalItems: Int
    let totalPages: Int
}

struct FileListResponse: Codable {
    let files: [FileResponse]
    let totalCount: Int
    let pagination: FilePagination
}

// MARK: - File Service

@MainActor
final class FileService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder

    var baseURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? ""
    }

    init() {
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func listFiles(
        printerId: String? = nil,
        status: String? = nil,
        source: String? = nil,
        hasThumbnail: Bool? = nil,
        search: String? = nil,
        page: Int = 1,
        limit: Int = 50
    ) async throws -> FileListResponse {
        var components = URLComponents(string: "\(baseURL)/api/v1/files")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let printerId {
            queryItems.append(URLQueryItem(name: "printer_id", value: printerId))
        }
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let source {
            queryItems.append(URLQueryItem(name: "source", value: source))
        }
        if let hasThumbnail {
            queryItems.append(URLQueryItem(name: "has_thumbnail", value: String(hasThumbnail)))
        }
        if let search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw FileError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FileError.serverError
        }

        return try decoder.decode(FileListResponse.self, from: data)
    }

    func getFile(id: String) async throws -> FileResponse {
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/files/\(id)") else {
            throw FileError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FileError.serverError
        }

        return try decoder.decode(FileResponse.self, from: data)
    }

    func getThumbnail(fileId: String) async throws -> UIImage {
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/files/\(fileId)/thumbnail") else {
            throw FileError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FileError.serverError
        }

        guard let image = UIImage(data: data) else {
            throw FileError.invalidImageData
        }

        return image
    }

    func deleteFile(id: String) async throws {
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/files/\(id)") else {
            throw FileError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FileError.serverError
        }
    }
}

// MARK: - File Errors

enum FileError: LocalizedError {
    case invalidURL
    case serverError
    case notFound
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .serverError:
            return "Server error"
        case .notFound:
            return "File not found"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

// MARK: - File Helper Extensions

extension FileResponse {
    var formattedFileSize: String {
        guard let size = fileSize else { return "Unknown" }

        if size >= 1_000_000 {
            return String(format: "%.1f MB", Double(size) / 1_000_000)
        } else if size >= 1_000 {
            return String(format: "%.1f KB", Double(size) / 1_000)
        } else {
            return "\(size) B"
        }
    }

    var sourceIcon: String {
        switch source.lowercased() {
        case "printer":
            return "printer"
        case "upload":
            return "arrow.up.doc"
        case "watch_folder":
            return "folder"
        case "library":
            return "books.vertical"
        default:
            return "doc"
        }
    }

    var statusColor: String {
        switch status.lowercased() {
        case "ready", "synced":
            return "green"
        case "downloading", "processing":
            return "blue"
        case "pending":
            return "orange"
        case "error", "failed":
            return "red"
        default:
            return "gray"
        }
    }

    var formattedDate: String? {
        guard let dateString = createdAt ?? downloadedAt else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return nil
    }
}
