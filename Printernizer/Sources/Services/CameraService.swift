import Foundation
import SwiftUI

// MARK: - Camera API Response Models

struct CameraStatus: Codable {
    let hasCamera: Bool
    let hasExternalWebcam: Bool
    let isAvailable: Bool
    let streamUrl: String?
    let externalWebcamUrl: String?
    let externalWebcamType: String?
    let ffmpegAvailable: Bool
    let ffmpegRequired: Bool
    let errorMessage: String?
}

struct SnapshotResponse: Codable, Identifiable {
    let id: Int
    let printerId: String
    let jobId: Int?
    let filename: String
    let fileSize: Int
    let contentType: String
    let capturedAt: String
    let captureTrigger: String
    let width: Int?
    let height: Int?
    let isValid: Bool
    let notes: String?
    let jobName: String?
    let jobStatus: String?
    let printerName: String?
    let printerType: String?
}

struct SnapshotCreateRequest: Codable {
    let printerId: String
    let jobId: Int?
    let captureTrigger: String
    let notes: String?

    init(printerId: String, jobId: Int? = nil, notes: String? = nil) {
        self.printerId = printerId
        self.jobId = jobId
        self.captureTrigger = "manual"
        self.notes = notes
    }
}

// MARK: - Camera Service

@MainActor
final class CameraService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    var baseURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? ""
    }

    init() {
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Camera Status

    func getCameraStatus(printerId: String) async throws -> CameraStatus {
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/printers/\(printerId)/camera/status") else {
            throw CameraError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CameraError.serverError
        }

        return try decoder.decode(CameraStatus.self, from: data)
    }

    // MARK: - Camera Preview

    func getPreviewImage(printerId: String, useExternal: Bool = false) async throws -> UIImage {
        let endpoint = useExternal ? "external-preview" : "preview"
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/printers/\(printerId)/camera/\(endpoint)") else {
            throw CameraError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CameraError.serverError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 400 {
                throw CameraError.cameraNotAvailable
            }
            throw CameraError.serverError
        }

        guard let image = UIImage(data: data) else {
            throw CameraError.invalidImageData
        }

        return image
    }

    // MARK: - Snapshots

    func takeSnapshot(printerId: String, notes: String? = nil) async throws -> SnapshotResponse {
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/printers/\(printerId)/camera/snapshot") else {
            throw CameraError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = SnapshotCreateRequest(printerId: printerId, notes: notes)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CameraError.serverError
        }

        return try decoder.decode(SnapshotResponse.self, from: data)
    }

    func listSnapshots(printerId: String, limit: Int = 50, offset: Int = 0) async throws -> [SnapshotResponse] {
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/printers/\(printerId)/snapshots?limit=\(limit)&offset=\(offset)") else {
            throw CameraError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CameraError.serverError
        }

        return try decoder.decode([SnapshotResponse].self, from: data)
    }

    func getSnapshotImageURL(snapshotId: Int) -> URL? {
        guard !baseURL.isEmpty else { return nil }
        return URL(string: "\(baseURL)/api/v1/snapshots/\(snapshotId)/download")
    }

    func downloadSnapshotImage(snapshotId: Int) async throws -> UIImage {
        guard let url = getSnapshotImageURL(snapshotId: snapshotId) else {
            throw CameraError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CameraError.serverError
        }

        guard let image = UIImage(data: data) else {
            throw CameraError.invalidImageData
        }

        return image
    }
}

// MARK: - Camera Errors

enum CameraError: LocalizedError {
    case invalidURL
    case serverError
    case cameraNotAvailable
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .serverError:
            return "Server error"
        case .cameraNotAvailable:
            return "Camera not available"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

// MARK: - Camera Status View Model

@MainActor
final class CameraStatusViewModel: ObservableObject {
    @Published var cameraStatus: CameraStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let cameraService = CameraService()

    func loadCameraStatus(printerId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            cameraStatus = try await cameraService.getCameraStatus(printerId: printerId)
        } catch {
            // Camera not available - this is expected for some printers
            cameraStatus = nil
        }
    }
}
