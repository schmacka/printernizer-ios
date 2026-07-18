import Foundation

// MARK: - Slicing Models

struct SlicerConfig: Codable, Identifiable {
    let id: String
    let name: String
    let slicerType: String?
    let isAvailable: Bool?
}

struct SlicerProfileResponse: Codable, Identifiable {
    let id: String
    let slicerId: String?
    let profileName: String
    let profileType: String?
    let printerModel: String?
    let isDefault: Bool?
}

struct SlicingJobResponse: Codable, Identifiable {
    let id: String
    let fileChecksum: String?
    let filename: String?
    let slicerName: String?
    let profileName: String?
    let targetPrinterId: String?
    let status: String
    let progress: Int?
    let estimatedPrintTime: Int?
    let filamentUsed: Double?
    let errorMessage: String?

    var isFinished: Bool {
        ["completed", "failed", "cancelled"].contains(status.lowercased())
    }

    var isSuccessful: Bool {
        status.lowercased() == "completed"
    }
}

private struct SlicerListResponse: Codable {
    let slicers: [SlicerConfig]
}

private struct ProfileListResponse: Codable {
    let profiles: [SlicerProfileResponse]
}

// MARK: - Slicing Service

/// Server-side slicing: slice library models with a configured slicer
/// profile, optionally uploading to and starting a printer.
@MainActor
final class SlicingService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    func listSlicers(availableOnly: Bool = true) async throws -> [SlicerConfig] {
        let queryItems = [URLQueryItem(name: "available_only", value: String(availableOnly))]
        guard let url = APIConfiguration.url("slicing", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(SlicerListResponse.self, from: data).slicers
    }

    func listProfiles(slicerId: String) async throws -> [SlicerProfileResponse] {
        guard let url = APIConfiguration.url("slicing/\(slicerId)/profiles") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(ProfileListResponse.self, from: data).profiles
    }

    /// Queues a slicing job for a library model. When `printerId` is
    /// set, the result is uploaded to that printer; `autoStart` also
    /// starts the print (slice-and-print flow).
    func slice(
        checksum: String,
        slicerId: String,
        profileId: String,
        printerId: String? = nil,
        autoStart: Bool = false
    ) async throws -> SlicingJobResponse {
        if let printerId {
            struct SliceAndPrintRequest: Codable {
                let fileChecksum: String
                let slicerId: String
                let profileId: String
                let printerId: String
                let autoStart: Bool
            }
            return try await post("slicing/slice-and-print", body: SliceAndPrintRequest(
                fileChecksum: checksum,
                slicerId: slicerId,
                profileId: profileId,
                printerId: printerId,
                autoStart: autoStart
            ))
        }

        struct SliceRequest: Codable {
            let fileChecksum: String
            let slicerId: String
            let profileId: String
        }
        return try await post("slicing/library/\(checksum)/slice", body: SliceRequest(
            fileChecksum: checksum,
            slicerId: slicerId,
            profileId: profileId
        ))
    }

    func getJob(id: String) async throws -> SlicingJobResponse {
        guard let url = APIConfiguration.url("slicing/jobs/\(id)") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
        return try decoder.decode(SlicingJobResponse.self, from: data)
    }

    func cancelJob(id: String) async throws {
        guard let url = APIConfiguration.url("slicing/jobs/\(id)/cancel") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    private func post<T: Decodable, Body: Encodable>(_ endpoint: String, body: Body) async throws -> T {
        guard let url = APIConfiguration.url(endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try checkStatus(response)
        return try decoder.decode(T.self, from: data)
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
