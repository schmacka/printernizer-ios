import Foundation

// MARK: - Analytics Models

/// Dashboard overview from GET /analytics/overview. All fields are
/// optional — the backend returns partial data when subsystems fail.
struct AnalyticsOverview: Decodable {
    struct JobStats: Decodable {
        let totalJobs: Int?
        let completedJobs: Int?
        let failedJobs: Int?
        let successRate: Double?
    }

    struct FileStats: Decodable {
        let totalFiles: Int?
        let downloadedFiles: Int?
        let localFiles: Int?
    }

    struct PrinterStats: Decodable {
        let totalPrinters: Int?
        let onlinePrinters: Int?
    }

    let jobs: JobStats?
    let files: FileStats?
    let printers: PrinterStats?
}

/// Aggregate analytics from GET /analytics/summary.
struct AnalyticsSummary: Decodable {
    let totalJobs: Int?
    let completedJobs: Int?
    let failedJobs: Int?
    let totalPrintTimeHours: Double?
    let totalMaterialUsedKg: Double?
    let totalCostEur: Double?
    let averageJobDurationHours: Double?
    let successRatePercent: Double?
}

/// Business analytics from GET /analytics/business.
struct BusinessAnalytics: Decodable {
    let businessJobs: Int?
    let privateJobs: Int?
    let businessRevenueEur: Double?
    let businessMaterialCostEur: Double?
    let businessProfitEur: Double?
}

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

// MARK: - Analytics Service

@MainActor
final class AnalyticsService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
    }

    func overview(period: AnalyticsPeriod = .day) async throws -> AnalyticsOverview {
        try await get("analytics/overview", queryItems: [
            URLQueryItem(name: "period", value: period.rawValue)
        ])
    }

    func summary() async throws -> AnalyticsSummary {
        try await get("analytics/summary")
    }

    func business() async throws -> BusinessAnalytics {
        try await get("analytics/business")
    }

    private func get<T: Decodable>(_ endpoint: String, queryItems: [URLQueryItem] = []) async throws -> T {
        guard let url = APIConfiguration.url(endpoint, queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }
}
