import Foundation
import SwiftUI

// MARK: - Library API Response Models

/// A file in the backend's unified library (checksum-addressed).
/// The backend returns many more metadata fields; only the ones the app
/// displays are decoded here, all optionally so that schema evolution
/// on the backend doesn't break the list.
struct LibraryFile: Codable, Identifiable, Equatable {
    let checksum: String
    let filename: String
    let displayName: String?
    let fileSize: Int?
    let fileType: String?
    let status: String?
    let role: String?
    let parentChecksum: String?
    let analysisError: String?
    let hasThumbnail: Bool?
    let addedToLibrary: String?
    let lastModified: String?
    let modelWidth: Double?
    let modelDepth: Double?
    let modelHeight: Double?
    let totalFilamentWeight: Double?
    let materialCost: Double?
    let totalCost: Double?
    let slicerName: String?
    let profileName: String?
    let sources: String?

    var id: String { checksum }

    var isModel: Bool { role == nil || role == "model" }
    var isPrintFile: Bool { role == "printfile" }
}

/// A print file derived from a model, enriched with slicing job details.
struct LibraryPrintFile: Codable, Identifiable {
    let checksum: String
    let filename: String
    let displayName: String?
    let fileSize: Int?
    let fileType: String?
    let status: String?
    let hasThumbnail: Bool?
    let profileId: String?
    let targetPrinterId: String?
    let estimatedPrintTime: Double?
    let filamentUsed: Double?
    let slicedAt: String?
    let profileName: String?

    var id: String { checksum }
}

struct LibraryPagination: Codable {
    let page: Int?
    let limit: Int?
    let totalItems: Int?
    let totalPages: Int?
}

struct LibraryFileListResponse: Codable {
    let files: [LibraryFile]
    let pagination: LibraryPagination?
}

struct LibraryPrintFilesResponse: Codable {
    let printfiles: [LibraryPrintFile]
    let count: Int?
}

private struct LibraryPrintRequest: Codable {
    let printerId: String
}

/// A tag assigned to a library file. Only name/color are decoded;
/// tag ids are not needed by the app.
struct LibraryTag: Codable, Identifiable, Equatable {
    let name: String
    let color: String?

    var id: String { name }
}

private struct FileTagsResponse: Codable {
    let tags: [LibraryTag]
}

// MARK: - Library Service

@MainActor
final class LibraryService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    /// Lists library files. `search` must be at least 2 characters —
    /// the backend rejects shorter queries.
    func listFiles(
        search: String? = nil,
        fileType: String? = nil,
        sourceType: String? = nil,
        hasThumbnail: Bool? = nil,
        page: Int = 1,
        limit: Int = 50
    ) async throws -> LibraryFileListResponse {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let search, search.count >= 2 {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let fileType {
            queryItems.append(URLQueryItem(name: "file_type", value: fileType))
        }
        if let sourceType {
            queryItems.append(URLQueryItem(name: "source_type", value: sourceType))
        }
        if let hasThumbnail {
            queryItems.append(URLQueryItem(name: "has_thumbnail", value: String(hasThumbnail)))
        }

        guard let url = APIConfiguration.url("library/files", queryItems: queryItems) else {
            throw LibraryError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validate(response)
        return try decoder.decode(LibraryFileListResponse.self, from: data)
    }

    func getFile(checksum: String) async throws -> LibraryFile {
        guard let url = APIConfiguration.url("library/files/\(checksum)") else {
            throw LibraryError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validate(response)
        return try decoder.decode(LibraryFile.self, from: data)
    }

    /// Print files derived from a model via slicing.
    func getPrintFiles(checksum: String) async throws -> [LibraryPrintFile] {
        guard let url = APIConfiguration.url("library/files/\(checksum)/printfiles") else {
            throw LibraryError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validate(response)
        return try decoder.decode(LibraryPrintFilesResponse.self, from: data).printfiles
    }

    func getThumbnail(checksum: String) async throws -> UIImage {
        guard let url = APIConfiguration.url("library/files/\(checksum)/thumbnail") else {
            throw LibraryError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validate(response)

        guard let image = UIImage(data: data) else {
            throw LibraryError.invalidImageData
        }
        return image
    }

    func downloadURL(checksum: String) -> URL? {
        APIConfiguration.url("library/files/\(checksum)/download")
    }

    /// Tags assigned to a library file (served by the tags router).
    func getTags(checksum: String) async throws -> [LibraryTag] {
        guard let url = APIConfiguration.url("tags/file/\(checksum)") else {
            throw LibraryError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validate(response)
        return try decoder.decode(FileTagsResponse.self, from: data).tags
    }

    /// Sends the file to a printer and starts the print.
    func printFile(checksum: String, printerId: String) async throws {
        guard let url = APIConfiguration.url("library/files/\(checksum)/print") else {
            throw LibraryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(LibraryPrintRequest(printerId: printerId))

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    func deleteFile(checksum: String) async throws {
        guard let url = APIConfiguration.url("library/files/\(checksum)") else {
            throw LibraryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LibraryError.serverError
        }
    }
}

// MARK: - Library Errors

enum LibraryError: LocalizedError {
    case invalidURL
    case serverError
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .serverError:
            return "Server error"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

// MARK: - Display Helpers

extension LibraryFile {
    var displayTitle: String {
        displayName?.isEmpty == false ? displayName! : filename
    }

    var formattedFileSize: String {
        guard let size = fileSize else { return "Unknown" }
        if size >= 1_000_000 {
            return String(format: "%.1f MB", Double(size) / 1_000_000)
        } else if size >= 1_000 {
            return String(format: "%.1f KB", Double(size) / 1_000)
        }
        return "\(size) B"
    }

    var formattedDimensions: String? {
        guard let width = modelWidth, let depth = modelDepth, let height = modelHeight else {
            return nil
        }
        return String(format: "%.0f × %.0f × %.0f mm", width, depth, height)
    }

    var roleIcon: String {
        isPrintFile ? "doc.badge.gearshape" : "cube"
    }

    var statusColor: Color {
        switch (status ?? "").lowercased() {
        case "ready", "available", "processed":
            return .green
        case "processing", "analyzing":
            return .blue
        case "error", "failed":
            return .red
        default:
            return analysisError == nil ? .gray : .red
        }
    }

    var formattedDate: String? {
        guard let dateString = addedToLibrary ?? lastModified else { return nil }
        return LibraryDateFormatting.format(dateString)
    }
}

extension LibraryPrintFile {
    var displayTitle: String {
        displayName?.isEmpty == false ? displayName! : filename
    }

    var formattedPrintTime: String? {
        guard let seconds = estimatedPrintTime, seconds > 0 else { return nil }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

enum LibraryDateFormatting {
    static func format(_ dateString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }
        guard let date else { return nil }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}
