import Foundation

// MARK: - Printer Management Models

enum PrinterType: String, Codable, CaseIterable, Identifiable {
    case bambuLab = "bambu_lab"
    case prusaCore = "prusa_core"
    case octoprint = "octoprint"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bambuLab: return "Bambu Lab"
        case .prusaCore: return "Prusa"
        case .octoprint: return "OctoPrint"
        }
    }
}

/// Connection parameters sent to and returned by the backend. Which
/// fields are relevant depends on the printer type: Bambu Lab uses
/// access code + serial number, Prusa and OctoPrint use an API key.
struct PrinterConnectionConfig: Codable, Equatable {
    var ipAddress: String?
    var apiKey: String?
    var accessCode: String?
    var serialNumber: String?
    var webcamUrl: String?
}

struct PrinterCreateRequest: Codable {
    let name: String
    let printerType: PrinterType
    let connectionConfig: PrinterConnectionConfig
    let location: String?
    let description: String?
}

/// All fields optional — omitted fields are left unchanged by the backend.
struct PrinterUpdateRequest: Codable {
    var name: String?
    var printerType: PrinterType?
    var connectionConfig: PrinterConnectionConfig?
    var location: String?
    var description: String?
    var isEnabled: Bool?
}

/// Full printer configuration as returned by GET/POST/PUT /printers
/// endpoints; includes the connection config needed to prefill the
/// edit form. Non-identity fields are optional for schema evolution.
struct PrinterConfigResponse: Decodable, Identifiable {
    let id: String
    let name: String
    let printerType: String?
    let status: String?
    let ipAddress: String?
    let connectionConfig: PrinterConnectionConfig?
    let location: String?
    let description: String?
    let isEnabled: Bool?
    let lastSeen: String?
}

struct DiscoveredPrinter: Decodable, Identifiable {
    let type: String?
    let name: String?
    let ip: String?
    let hostname: String?
    let model: String?
    let serial: String?
    let discoveredAt: String?
    let alreadyAdded: Bool?

    var id: String { ip ?? serial ?? name ?? hostname ?? "unknown" }

    /// Maps the discovery "type" value onto a configurable printer type.
    var printerType: PrinterType? {
        switch type?.lowercased() {
        case "bambu_lab", "bambu": return .bambuLab
        case "prusa", "prusa_core", "prusalink": return .prusaCore
        case "octoprint": return .octoprint
        default: return nil
        }
    }
}

struct DiscoveryResult: Decodable {
    let discovered: [DiscoveredPrinter]
    let scanDurationMs: Double?
    let errors: [String]?
}

struct NetworkInterface: Decodable, Identifiable {
    let name: String
    let ip: String?
    let isDefault: Bool?

    var id: String { name }
}

struct NetworkInterfacesResponse: Decodable {
    let interfaces: [NetworkInterface]
    let `default`: String?
}

struct ConnectionTestResult: Decodable {
    let success: Bool?
    let message: String?
    let responseTimeMs: Double?
}

/// Backend `success_response` envelope: `{"status": ..., "data": ...}`.
private struct SuccessEnvelope<T: Decodable>: Decodable {
    let status: String?
    let data: T
}

// MARK: - Printer Service

/// Printer lifecycle management: create/edit/delete, network discovery,
/// and connection controls. Live status and print controls remain in
/// APIService.
@MainActor
final class PrinterService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    func getPrinter(id: String) async throws -> PrinterConfigResponse {
        try await get("printers/\(id)")
    }

    func createPrinter(_ printer: PrinterCreateRequest) async throws -> PrinterConfigResponse {
        try await send("printers", method: "POST", body: printer)
    }

    func updatePrinter(id: String, update: PrinterUpdateRequest) async throws -> PrinterConfigResponse {
        try await send("printers/\(id)", method: "PUT", body: update)
    }

    func deletePrinter(id: String, force: Bool = false) async throws {
        let queryItems = force ? [URLQueryItem(name: "force", value: "true")] : []
        guard let url = APIConfiguration.url("printers/\(id)", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try Self.checkStatus(response)
    }

    /// Scans the local network for printers. Discovery can take up to
    /// ~30 seconds when subnet scanning is enabled.
    func discoverPrinters(interface: String? = nil, scanSubnet: Bool = true) async throws -> DiscoveryResult {
        var queryItems = [URLQueryItem(name: "scan_subnet", value: scanSubnet ? "true" : "false")]
        if let interface {
            queryItems.append(URLQueryItem(name: "interface", value: interface))
        }
        guard let url = APIConfiguration.url("printers/discover", queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 90

        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response)
        return try decoder.decode(DiscoveryResult.self, from: data)
    }

    func networkInterfaces() async throws -> NetworkInterfacesResponse {
        try await get("printers/discover/interfaces")
    }

    /// Tests connection parameters without creating the printer.
    func testConnection(type: PrinterType, config: PrinterConnectionConfig) async throws -> ConnectionTestResult {
        struct TestRequest: Codable {
            let printerType: PrinterType
            let connectionConfig: PrinterConnectionConfig
        }

        guard let url = APIConfiguration.url("printers/test-connection") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(TestRequest(printerType: type, connectionConfig: config))
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response)
        return try decoder.decode(SuccessEnvelope<ConnectionTestResult>.self, from: data).data
    }

    func connect(printerId: String) async throws {
        try await postCommand("printers/\(printerId)/connect")
    }

    func disconnect(printerId: String) async throws {
        try await postCommand("printers/\(printerId)/disconnect")
    }

    func startMonitoring(printerId: String) async throws {
        try await postCommand("printers/\(printerId)/monitoring/start")
    }

    func stopMonitoring(printerId: String) async throws {
        try await postCommand("printers/\(printerId)/monitoring/stop")
    }

    /// Downloads the currently printing job file on the server side and
    /// queues thumbnail processing for it.
    func downloadCurrentJob(printerId: String) async throws {
        try await postCommand("printers/\(printerId)/download-current-job")
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = APIConfiguration.url(endpoint) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try Self.checkStatus(response)
        return try decoder.decode(T.self, from: data)
    }

    private func send<T: Decodable, Body: Encodable>(_ endpoint: String, method: String, body: Body) async throws -> T {
        guard let url = APIConfiguration.url(endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response)
        return try decoder.decode(T.self, from: data)
    }

    private func postCommand(_ endpoint: String) async throws {
        guard let url = APIConfiguration.url(endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.data(for: request)
        try Self.checkStatus(response)
    }

    private static func checkStatus(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}
