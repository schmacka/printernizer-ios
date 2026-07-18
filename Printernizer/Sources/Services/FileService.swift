import SwiftUI

// MARK: - Printer File Models

/// A file known to the backend's file manager: discovered on a
/// printer, found in a watch folder, or uploaded.
struct PrinterFileResponse: Codable, Identifiable {
    let id: String
    let printerId: String?
    let filename: String
    let source: String?
    let status: String?
    let fileSize: Int?
    let fileType: String?
    let downloadedAt: String?
    let watchFolderPath: String?
    let hasThumbnail: Bool?

    var isDownloadable: Bool {
        (status ?? "").lowercased() == "available" && printerId != nil
    }

    var statusColor: Color {
        switch (status ?? "").lowercased() {
        case "available": return .blue
        case "downloading": return .orange
        case "downloaded", "local": return .green
        case "error": return .red
        default: return .gray
        }
    }

    var sourceIcon: String {
        switch (source ?? "").lowercased() {
        case "printer": return "printer"
        case "local_watch": return "folder"
        case "upload": return "square.and.arrow.up"
        default: return "doc"
        }
    }

    var formattedSize: String? {
        guard let size = fileSize, size > 0 else { return nil }
        if size >= 1_000_000 {
            return String(format: "%.1f MB", Double(size) / 1_000_000)
        }
        return String(format: "%.0f KB", Double(size) / 1_000)
    }
}

struct PrinterFileListResponse: Codable {
    struct Pagination: Codable {
        let page: Int?
        let totalPages: Int?
    }

    let files: [PrinterFileResponse]
    let totalCount: Int?
    let pagination: Pagination?
}

/// A configured watch folder on the server.
struct WatchFolderItem: Codable, Identifiable {
    let id: String?
    let folderPath: String
    let isActive: Bool?
    let folderName: String?
    let fileCount: Int?
    let isValid: Bool?
    let validationError: String?

    var itemId: String { id ?? folderPath }
}

struct WatchFolderSettings: Codable {
    let watchFolders: [WatchFolderItem]
    let enabled: Bool?
    let recursive: Bool?
}

// MARK: - File Service

/// Printer file discovery/downloads and watch folder management
/// (the web app's "Files" page).
@MainActor
final class FileService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
    }

    func listFiles(
        printerId: String? = nil,
        status: String? = nil,
        source: String? = nil,
        search: String? = nil,
        page: Int = 1,
        limit: Int = 50
    ) async throws -> PrinterFileListResponse {
        var queryItems = [
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
        if let search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }

        guard let url = APIConfiguration.url("files", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(PrinterFileListResponse.self, from: data)
    }

    /// Downloads a printer file to the server's local storage. The
    /// backend performs the transfer and returns when it finishes.
    func downloadFile(id: String) async throws {
        var request = try makeRequest("files/\(id)/download", method: "POST")
        request.timeoutInterval = 300
        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    /// Re-syncs the file list with printers.
    func syncFiles(printerId: String? = nil) async throws {
        var queryItems: [URLQueryItem] = []
        if let printerId {
            queryItems.append(URLQueryItem(name: "printer_id", value: printerId))
        }
        guard let url = APIConfiguration.url("files/sync", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    func deleteFile(id: String) async throws {
        let request = try makeRequest("files/\(id)", method: "DELETE")
        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    // MARK: - Watch Folders

    func watchFolderSettings() async throws -> WatchFolderSettings {
        guard let url = APIConfiguration.url("files/watch-folders/settings") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(WatchFolderSettings.self, from: data)
    }

    func addWatchFolder(path: String) async throws {
        try await postWithFolderPath("files/watch-folders/add", path: path)
    }

    func removeWatchFolder(path: String) async throws {
        let queryItems = [URLQueryItem(name: "folder_path", value: path)]
        guard let url = APIConfiguration.url("files/watch-folders/remove", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    func setWatchFolderActive(path: String, isActive: Bool) async throws {
        let queryItems = [
            URLQueryItem(name: "folder_path", value: path),
            URLQueryItem(name: "is_active", value: String(isActive))
        ]
        guard let url = APIConfiguration.url("files/watch-folders/update", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    func rescanWatchFolder(path: String) async throws {
        try await postWithFolderPath("files/watch-folders/rescan", path: path)
    }

    // MARK: - Private Helpers

    private func postWithFolderPath(_ endpoint: String, path: String) async throws {
        let queryItems = [URLQueryItem(name: "folder_path", value: path)]
        guard let url = APIConfiguration.url(endpoint, queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    private func makeRequest(_ endpoint: String, method: String) throws -> URLRequest {
        guard let url = APIConfiguration.url(endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
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
