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

struct MaterialStats: Codable {
    let totalSpools: Int
    let activeSpools: Int
    let lowStockSpools: Int
    let totalWeight: Double
    let totalValue: Double
    let byType: [String: Int]
    let byBrand: [String: Int]
}

struct MaterialTypes: Codable {
    let types: [String]
    let brands: [String]
    let colors: [String]
}

struct MaterialCreateRequest: Codable {
    let materialType: String
    let brand: String
    let color: String
    let diameter: Double
    let weight: Double
    let costPerKg: Double
    let vendor: String
    let batchNumber: String?
    let notes: String?
    let colorHex: String?
    let location: String?
}

struct MaterialUpdateRequest: Codable {
    let remainingWeight: Double?
    let notes: String?
    let location: String?
    let isActive: Bool?
}

// MARK: - Material Service

@MainActor
final class MaterialService: ObservableObject {
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

    func listMaterials(
        materialType: String? = nil,
        brand: String? = nil,
        lowStock: Bool = false
    ) async throws -> [MaterialResponse] {
        var components = URLComponents(string: "\(baseURL)/api/v1/materials")
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

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
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
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/materials/\(id)") else {
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
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/materials/stats") else {
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
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/materials/types") else {
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
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/materials") else {
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
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/materials/\(id)") else {
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

    func deleteMaterial(id: String) async throws {
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/api/v1/materials/\(id)") else {
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

    var formattedWeight: String {
        if remainingWeight >= 1000 {
            return String(format: "%.1f kg", remainingWeight / 1000)
        }
        return String(format: "%.0f g", remainingWeight)
    }

    var formattedTotalWeight: String {
        if weight >= 1000 {
            return String(format: "%.1f kg", weight / 1000)
        }
        return String(format: "%.0f g", weight)
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
