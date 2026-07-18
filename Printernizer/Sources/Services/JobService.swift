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
    let customerName: String?
    let orderId: String?
    let createdAt: String
    let updatedAt: String
    let progressPercent: Double?
    let costEur: Double?
    let startedAt: String?
    let completedAt: String?
}

/// Create request for POST /jobs.
struct JobCreateRequest: Codable {
    let printerId: String
    let jobName: String
    let filename: String?
    let fileId: String?
    let estimatedDuration: Int?
    let materialCost: Double?
    let isBusiness: Bool
    let customerName: String?
}

/// Update request for PUT /jobs/{id}; omitted fields stay unchanged.
struct JobUpdateRequest: Codable {
    var jobName: String?
    var status: String?
    var isBusiness: Bool?
    var customerName: String?
    var notes: String?
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
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    func listJobs(
        printerId: String? = nil,
        status: String? = nil,
        isBusiness: Bool? = nil,
        page: Int = 1,
        limit: Int = 50
    ) async throws -> JobListResponse {
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

        guard let url = APIConfiguration.url("jobs", queryItems: queryItems) else {
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
        guard let url = APIConfiguration.url("jobs/\(id)") else {
            throw JobError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JobError.serverError
        }

        return try decoder.decode(JobResponse.self, from: data)
    }

    func createJob(_ job: JobCreateRequest) async throws -> JobResponse {
        guard let url = APIConfiguration.url("jobs") else {
            throw JobError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(job)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JobError.serverError
        }

        return try decoder.decode(JobResponse.self, from: data)
    }

    func updateJob(id: String, update: JobUpdateRequest) async throws -> JobResponse {
        guard let url = APIConfiguration.url("jobs/\(id)") else {
            throw JobError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(update)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JobError.serverError
        }

        return try decoder.decode(JobResponse.self, from: data)
    }

    func deleteJob(id: String) async throws {
        guard let url = APIConfiguration.url("jobs/\(id)") else {
            throw JobError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JobError.serverError
        }
    }

    /// Downloads the CSV export to a temporary file for the share sheet.
    func exportJobs(
        printerId: String? = nil,
        status: String? = nil,
        isBusiness: Bool? = nil
    ) async throws -> URL {
        var queryItems: [URLQueryItem] = []
        if let printerId {
            queryItems.append(URLQueryItem(name: "printer_id", value: printerId))
        }
        if let status {
            queryItems.append(URLQueryItem(name: "job_status", value: status))
        }
        if let isBusiness {
            queryItems.append(URLQueryItem(name: "is_business", value: String(isBusiness)))
        }

        guard let url = APIConfiguration.url("jobs/export", queryItems: queryItems) else {
            throw JobError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JobError.serverError
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("jobs-export.csv")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func cancelJob(id: String) async throws {
        guard let url = APIConfiguration.url("jobs/\(id)/cancel") else {
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
        guard let dateString = startedAt ?? (createdAt.isEmpty ? nil : createdAt) else { return nil }

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
