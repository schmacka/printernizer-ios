import Foundation
import SwiftUI

// MARK: - Material API Response Models

struct MaterialResponse: Codable, Identifiable {
    let id: String
    let materialType: String
    let brand: String
    let color: String
    let diameter: Double
    let weight: Double
    let remainingWeight: Double
    let remainingPercentage: Double
    let costPerKg: Double
    let remainingValue: Double
    let vendor: String
    let batchNumber: String?
    let notes: String?
    let printerId: String?
    let colorHex: String?
    let location: String?
    let isActive: Bool
    let createdAt: String
    let updatedAt: String
}

/// Inventory statistics from GET /materials/stats. Weights are in kg;
/// `lowStock` is the list of material IDs below 20% remaining.
struct MaterialStats: Codable {
    let totalSpools: Int
    let totalWeight: Double
    let totalRemaining: Double?
    let totalValue: Double?
    let remainingValue: Double?
    let byColor: [String: Int]?
    let lowStock: [String]?
    /// Capital `D` is deliberate: `.convertFromSnakeCase` capitalizes each
    /// component after an underscore, and `"30d".capitalized` is `"30D"`, so
    /// the backend's `consumption_30d` arrives as `consumption30D`. Spelling
    /// this with a lowercase `d` makes it silently decode to nil.
    let consumption30D: Double?
}

struct MaterialTypes: Codable {
    let types: [String]
    let brands: [String]
    let colors: [String]
}

/// Create request for POST /materials. Weights are kilograms;
/// type/brand/color must be backend enum values (see /materials/types).
struct MaterialCreateRequest: Codable {
    let materialType: String
    let brand: String
    let color: String
    let diameter: Double
    let weight: Double
    let remainingWeight: Double
    let costPerKg: Double
    let vendor: String
    let batchNumber: String?
    let notes: String?
    let colorHex: String?
    let location: String?
    let isActive: Bool
}

/// Update request for PATCH /materials/{id}. The backend only allows
/// these fields to change; type/brand/color/weight are immutable.
struct MaterialUpdateRequest: Codable {
    var remainingWeight: Double?
    var costPerKg: Double?
    var notes: String?
    var colorHex: String?
    var location: String?
    var isActive: Bool?
}

/// Request body for POST /materials/consumption. Weight is grams.
struct ConsumptionRequest: Codable {
    let jobId: String
    let materialId: String
    let weightGrams: Double
    let printerId: String
    let fileName: String?
    let printTimeHours: Double?
}

struct ConsumptionHistoryItem: Codable, Identifiable {
    let id: String
    let jobId: String
    let materialId: String
    let materialType: String
    let brand: String
    let color: String
    let weightUsed: Double
    let cost: Double
    let timestamp: String
    let printerId: String
    let fileName: String?
    let printTimeHours: Double?
}

struct ConsumptionHistoryResponse: Codable {
    let items: [ConsumptionHistoryItem]
    let totalCount: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}

// MARK: - Material Service

@MainActor
final class MaterialService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    func listMaterials(
        materialType: String? = nil,
        brand: String? = nil,
        lowStock: Bool = false
    ) async throws -> [MaterialResponse] {
        var queryItems: [URLQueryItem] = []

        if let materialType {
            queryItems.append(URLQueryItem(name: "material_type", value: materialType))
        }
        if let brand {
            queryItems.append(URLQueryItem(name: "brand", value: brand))
        }
        if lowStock {
            queryItems.append(URLQueryItem(name: "low_stock", value: "true"))
        }

        guard let url = APIConfiguration.url("materials", queryItems: queryItems) else {
            throw MaterialError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MaterialError.serverError
        }

        return try decoder.decode([MaterialResponse].self, from: data)
    }

    func getMaterial(id: String) async throws -> MaterialResponse {
        guard let url = APIConfiguration.url("materials/\(id)") else {
            throw MaterialError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MaterialError.serverError
        }

        return try decoder.decode(MaterialResponse.self, from: data)
    }

    func getStats() async throws -> MaterialStats {
        guard let url = APIConfiguration.url("materials/stats") else {
            throw MaterialError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MaterialError.serverError
        }

        return try decoder.decode(MaterialStats.self, from: data)
    }

    func getTypes() async throws -> MaterialTypes {
        guard let url = APIConfiguration.url("materials/types") else {
            throw MaterialError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MaterialError.serverError
        }

        return try decoder.decode(MaterialTypes.self, from: data)
    }

    func createMaterial(_ material: MaterialCreateRequest) async throws -> MaterialResponse {
        guard let url = APIConfiguration.url("materials") else {
            throw MaterialError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(material)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MaterialError.serverError
        }

        return try decoder.decode(MaterialResponse.self, from: data)
    }

    func updateMaterial(id: String, update: MaterialUpdateRequest) async throws -> MaterialResponse {
        guard let url = APIConfiguration.url("materials/\(id)") else {
            throw MaterialError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(update)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MaterialError.serverError
        }

        return try decoder.decode(MaterialResponse.self, from: data)
    }

    /// Downloads the inventory export (csv or excel) to a temporary
    /// file suitable for the share sheet.
    func exportMaterials(format: MaterialExportFormat) async throws -> URL {
        let queryItems = [URLQueryItem(name: "format", value: format.rawValue)]
        guard let url = APIConfiguration.url("materials/export", queryItems: queryItems) else {
            throw MaterialError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MaterialError.serverError
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("materials-export.\(format.fileExtension)")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func recordConsumption(_ consumption: ConsumptionRequest) async throws {
        guard let url = APIConfiguration.url("materials/consumption") else {
            throw MaterialError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(consumption)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MaterialError.serverError
        }
    }

    func consumptionHistory(
        materialId: String? = nil,
        days: Int = 30,
        page: Int = 1,
        limit: Int = 50
    ) async throws -> ConsumptionHistoryResponse {
        var queryItems = [
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let materialId {
            queryItems.append(URLQueryItem(name: "material_id", value: materialId))
        }

        guard let url = APIConfiguration.url("materials/consumption/history", queryItems: queryItems) else {
            throw MaterialError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MaterialError.serverError
        }

        return try decoder.decode(ConsumptionHistoryResponse.self, from: data)
    }

    func deleteMaterial(id: String) async throws {
        guard let url = APIConfiguration.url("materials/\(id)") else {
            throw MaterialError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MaterialError.serverError
        }
    }
}

enum MaterialExportFormat: String {
    case csv
    case excel

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .excel: return "xlsx"
        }
    }

    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .excel: return "Excel"
        }
    }
}

// MARK: - Material Errors

enum MaterialError: LocalizedError {
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
            return "Material not found"
        }
    }
}

// MARK: - Material Helper Extensions

extension MaterialResponse {
    var displayColor: Color {
        if let hex = colorHex {
            return Color(hex: hex) ?? .gray
        }
        return colorFromName
    }

    private var colorFromName: Color {
        switch color.lowercased() {
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "gray", "grey": return .gray
        case "brown": return .brown
        default: return .gray
        }
    }

    // Backend weights are kilograms.
    var formattedWeight: String {
        Formatters.weightKg(remainingWeight)
    }

    var formattedTotalWeight: String {
        Formatters.weightKg(weight)
    }

    var isLowStock: Bool {
        remainingPercentage < 20
    }

    var statusColor: Color {
        if !isActive {
            return .gray
        }
        if isLowStock {
            return .orange
        }
        return .green
    }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
