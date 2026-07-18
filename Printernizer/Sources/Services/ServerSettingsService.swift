import Foundation

// MARK: - Server Settings Models

/// Application settings from GET /settings/application. Only the
/// fields surfaced in the iOS UI are decoded; all optional so backend
/// evolution doesn't break the screen.
struct ServerSettings: Codable {
    let logLevel: String?
    let monitoringInterval: Int?
    let connectionTimeout: Int?
    let vatRate: Double?
    let currency: String?
    let jobCreationAutoCreate: Bool?
    let gcodeOptimizePrintOnly: Bool?
    let gcodeOptimizationMaxLines: Int?
    let gcodeRenderMaxLines: Int?
    let enableUpload: Bool?
    let maxUploadSizeMb: Int?
    let libraryEnabled: Bool?
    let libraryAutoOrganize: Bool?
    let libraryAutoExtractMetadata: Bool?
    let libraryAutoDeduplicate: Bool?
    let libraryPreserveOriginals: Bool?
    let timelapseEnabled: Bool?
    let timelapseCleanupAgeDays: Int?
}

/// Update payload for PUT /settings/application; omitted fields are
/// left unchanged by the backend.
struct ServerSettingsUpdate: Codable {
    var logLevel: String?
    var monitoringInterval: Int?
    var connectionTimeout: Int?
    var vatRate: Double?
    var jobCreationAutoCreate: Bool?
    var gcodeOptimizePrintOnly: Bool?
    var gcodeOptimizationMaxLines: Int?
    var gcodeRenderMaxLines: Int?
    var enableUpload: Bool?
    var maxUploadSizeMb: Int?
    var libraryEnabled: Bool?
    var libraryAutoOrganize: Bool?
    var libraryAutoExtractMetadata: Bool?
    var libraryAutoDeduplicate: Bool?
    var libraryPreserveOriginals: Bool?
    var timelapseEnabled: Bool?
    var timelapseCleanupAgeDays: Int?
}

struct FfmpegCheckResult: Codable {
    let installed: Bool?
    let version: String?
    let message: String?
}

// MARK: - Server Settings Service

/// Server-side application settings (the web app's Settings page).
/// Device-local preferences remain in @AppStorage.
@MainActor
final class ServerSettingsService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    func getSettings() async throws -> ServerSettings {
        guard let url = APIConfiguration.url("settings/application") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(ServerSettings.self, from: data)
    }

    func updateSettings(_ update: ServerSettingsUpdate) async throws {
        guard let url = APIConfiguration.url("settings/application") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(update)

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    func checkFfmpeg() async throws -> FfmpegCheckResult {
        guard let url = APIConfiguration.url("settings/ffmpeg-check") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(FfmpegCheckResult.self, from: data)
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
