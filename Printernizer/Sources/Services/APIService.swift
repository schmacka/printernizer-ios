import Foundation

// MARK: - API Response Models

/// Current job information from backend
struct APICurrentJob: Decodable {
    let name: String
    let status: String?
    let progress: Int?
    let startedAt: String?
    let estimatedRemaining: Int?
    let layerCurrent: Int?
    let layerTotal: Int?
}

/// Temperature information from backend
struct APITemperatures: Decodable {
    let bed: Double?
    let nozzle: Double?
}

/// Single printer response from backend
struct APIPrinterResponse: Decodable {
    let id: String
    let name: String
    let printerType: String
    let status: String
    let ipAddress: String?
    let location: String?
    let description: String?
    let isEnabled: Bool
    let lastSeen: String?
    let currentJob: APICurrentJob?
    let temperatures: APITemperatures?
    let createdAt: String
    let updatedAt: String
}

/// Pagination info from backend
struct APIPagination: Decodable {
    let page: Int
    let limit: Int
    let totalItems: Int
    let totalPages: Int
}

/// Printer list response from backend
struct APIPrinterListResponse: Decodable {
    let printers: [APIPrinterResponse]
    let totalCount: Int
    let pagination: APIPagination
}

/// Printer details response from backend (GET /printers/{id}/details)
struct APIPrinterDetailsResponse: Decodable {
    let printer: APIPrinterInfo
    let connection: APIConnectionInfo
    let statistics: APIPrinterStatistics
    let recentJobs: [APIRecentJob]
    let currentStatus: APICurrentStatus?
}

struct APIPrinterInfo: Decodable {
    let id: String
    let name: String
    let type: String
    let status: String
    let location: String?
    let description: String?
    let isEnabled: Bool
    let createdAt: String?
    let lastSeen: String?
}

struct APIConnectionInfo: Decodable {
    let isConnected: Bool
    let connectionType: String
    let ipAddress: String?
    let lastSeen: String?
    let firmwareVersion: String?
    let uptime: Int?
}

struct APIPrinterStatistics: Decodable {
    let totalJobs: Int
    let completedJobs: Int
    let failedJobs: Int
    let successRate: Double
    let totalPrintTimeHours: Double
    let totalMaterialKg: Double
}

struct APIRecentJob: Decodable {
    let id: String
    let fileName: String
    let status: String
    let progress: Int?
    let startedAt: String?
    let endedAt: String?
    let printTimeMinutes: Int?
    let materialUsed: Double?
}

struct APICurrentStatus: Decodable {
    let currentJob: String?
    let progress: Int?
    let remainingTime: Int?
    let temperatures: APICurrentTemperatures?
}

struct APICurrentTemperatures: Decodable {
    let bed: APITempReading?
    let nozzle: APITempReading?
}

struct APITempReading: Decodable {
    let current: Double?
    let target: Double?
}

/// Converted printer details for iOS views
struct PrinterDetails {
    let currentJob: PrintJob?
    let hotendTemp: Double
    let hotendTarget: Double
    let bedTemp: Double
    let bedTarget: Double
    let statistics: PrinterStatistics?
    let recentJobs: [RecentJobSummary]
    let isConnected: Bool
}

/// Recent job entry shown on the printer detail screen.
struct RecentJobSummary: Identifiable {
    let id: String
    let fileName: String
    let status: String
    let progress: Int?
    let startedAt: String?
    let printTimeMinutes: Int?
}

struct PrinterStatistics {
    let totalJobs: Int
    let completedJobs: Int
    let failedJobs: Int
    let successRate: Double
    let totalPrintTimeHours: Double
    let totalMaterialKg: Double
}

/// Backend information from GET /api/v1/system/info
struct SystemInfo: Decodable {
    let version: String?
    let environment: String?
    let timezone: String?
    let databaseSizeMb: Double?
    let uptimeSeconds: Double?
}

/// Update availability from GET /api/v1/update-check.
struct UpdateCheckResult: Decodable {
    let currentVersion: String?
    let latestVersion: String?
    let updateAvailable: Bool?
    let releaseUrl: String?
    let checkFailed: Bool?
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
final class APIService: ObservableObject {
    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "serverURL")
        }
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        self.baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
    }

    func fetchPrinters() async throws -> [Printer] {
        let response: APIPrinterListResponse = try await request("printers")
        return response.printers.map { apiPrinter in
            Printer(
                id: apiPrinter.id,
                name: apiPrinter.name,
                status: PrinterStatus(apiValue: apiPrinter.status),
                model: formatPrinterType(apiPrinter.printerType),
                currentJobProgress: apiPrinter.currentJob?.progress.map { Double($0) / 100.0 }
            )
        }
    }

    func fetchPrinterDetails(printerId: String) async throws -> PrinterDetails {
        let response: APIPrinterDetailsResponse = try await request("printers/\(printerId)/details")

        // Extract temperature data
        let hotendTemp = response.currentStatus?.temperatures?.nozzle?.current ?? 0
        let hotendTarget = response.currentStatus?.temperatures?.nozzle?.target ?? 0
        let bedTemp = response.currentStatus?.temperatures?.bed?.current ?? 0
        let bedTarget = response.currentStatus?.temperatures?.bed?.target ?? 0

        // Convert current job if present
        var currentJob: PrintJob? = nil
        if let jobName = response.currentStatus?.currentJob,
           let progress = response.currentStatus?.progress {
            let progressDouble = Double(progress) / 100.0
            let remainingMinutes = response.currentStatus?.remainingTime

            currentJob = PrintJob(
                id: printerId,
                fileName: jobName,
                progress: progressDouble,
                elapsedSeconds: 0,
                estimatedTotalSeconds: remainingMinutes.map { $0 * 60 },
                currentLayer: nil,
                totalLayers: nil,
                filamentUsedMm: 0
            )
        }

        // Convert statistics
        let stats = PrinterStatistics(
            totalJobs: response.statistics.totalJobs,
            completedJobs: response.statistics.completedJobs,
            failedJobs: response.statistics.failedJobs,
            successRate: response.statistics.successRate,
            totalPrintTimeHours: response.statistics.totalPrintTimeHours,
            totalMaterialKg: response.statistics.totalMaterialKg
        )

        let recentJobs = response.recentJobs.map { job in
            RecentJobSummary(
                id: job.id,
                fileName: job.fileName,
                status: job.status,
                progress: job.progress,
                startedAt: job.startedAt,
                printTimeMinutes: job.printTimeMinutes
            )
        }

        return PrinterDetails(
            currentJob: currentJob,
            hotendTemp: hotendTemp,
            hotendTarget: hotendTarget,
            bedTemp: bedTemp,
            bedTarget: bedTarget,
            statistics: stats,
            recentJobs: recentJobs,
            isConnected: response.connection.isConnected
        )
    }

    func pausePrint(printerId: String) async throws {
        try await postCommand("printers/\(printerId)/pause")
    }

    func resumePrint(printerId: String) async throws {
        try await postCommand("printers/\(printerId)/resume")
    }

    func stopPrint(printerId: String) async throws {
        try await postCommand("printers/\(printerId)/stop")
    }

    func fetchSystemInfo() async throws -> SystemInfo {
        try await request("system/info")
    }

    func checkForUpdates() async throws -> UpdateCheckResult {
        try await request("update-check")
    }

    /// Triggers a server-side backup; returns the backup path.
    func createBackup() async throws {
        try await postCommand("system/backup")
    }

    func testConnection() async throws -> Bool {
        guard let url = APIConfiguration.url("health") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private func postCommand(_ endpoint: String) async throws {
        guard let url = APIConfiguration.url(endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func formatPrinterType(_ type: String) -> String {
        switch type.lowercased() {
        case "bambu_lab":
            return "Bambu Lab"
        case "prusa_core":
            return "Prusa"
        case "octoprint":
            return "OctoPrint"
        default:
            return type
        }
    }

    private func request<T: Decodable>(_ endpoint: String, method: String = "GET") async throws -> T {
        guard let url = APIConfiguration.url(endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode)
            }

            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
