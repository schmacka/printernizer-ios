import Foundation

// MARK: - Job API Response Models

struct JobResponse: Codable, Identifiable {
    let id: String
    let printerId: String
    let printerType: String
    let jobName: String
    let filename: String?
    let status: String
    let startTime: String?
    let endTime: String?
    let estimatedDuration: Int?
    let actualDuration: Int?
    let progress: Double?
    let materialUsed: Double?
    let materialCost: Double?
    let powerCost: Double?
    let isBusiness: Bool
    let createdAt: String
    let updatedAt: String
    let progressPercent: Double?
    let costEur: Double?
    let startedAt: String?
    let completedAt: String?
}

struct JobPagination: Codable {
    let page: Int
    let limit: Int
    let totalItems: Int
    let totalPages: Int
}

struct JobListResponse: Codable {
    let jobs: [JobResponse]
    let totalCount: Int
    let pagination: JobPagination
}

// MARK: - Job Service

@MainActor
final class JobService: ObservableObject {
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

    func listJobs(
        printerId: String? = nil,
        status: String? = nil,
        isBusiness: Bool? = nil,
        page: Int = 1,
        limit: Int = 50
    ) async throws -> JobListResponse {
        var components = URLComponents(string: "\(baseURL)/api/v1/jobs")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let printerId {
            queryItems.append(URLQueryItem(name: "printer_id", value: printerId))
        }
        if let status {
            queryItems.append(URLQueryItem(name: "job_status", value: status))
        }
        if let isBusiness {
            queryItems.append(URLQueryItem(name: "is_business", value: String(isBusiness)))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw JobError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JobError.serverError
        }

        return try decoder.decode(JobListResponse.self, from: data)
    }

    func getJob(id: String) async throws -> JobResponse {
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/jobs/\(id)") else {
            throw JobError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JobError.serverError
        }

        return try decoder.decode(JobResponse.self, from: data)
    }

    func cancelJob(id: String) async throws {
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/jobs/\(id)/cancel") else {
            throw JobError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JobError.serverError
        }
    }
}

// MARK: - Job Errors

enum JobError: LocalizedError {
    case invalidURL
    case serverError
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .serverError:
            return "Server error"
        case .notFound:
            return "Job not found"
        }
    }
}

// MARK: - Job Helper Extensions

extension JobResponse {
    var statusColor: String {
        switch status.lowercased() {
        case "completed":
            return "green"
        case "running", "printing":
            return "blue"
        case "pending", "queued":
            return "orange"
        case "failed", "cancelled":
            return "red"
        default:
            return "gray"
        }
    }

    var formattedDuration: String? {
        guard let duration = actualDuration ?? estimatedDuration else { return nil }
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedDate: String? {
        guard let dateString = startedAt ?? createdAt.isEmpty ? nil : createdAt else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return nil
    }

    var totalCost: Double {
        (materialCost ?? 0) + (powerCost ?? 0)
    }
}
