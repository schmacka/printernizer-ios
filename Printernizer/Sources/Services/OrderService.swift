import SwiftUI

// MARK: - Order Models

enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case new
    case planned
    case printed
    case delivered
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new: return "New"
        case .planned: return "Planned"
        case .printed: return "Printed"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .new: return .blue
        case .planned: return .orange
        case .printed: return .teal
        case .delivered: return .green
        case .cancelled: return .red
        }
    }

    /// The next status in the fulfilment flow, mirroring the web app's
    /// "advance status" action.
    var next: OrderStatus? {
        switch self {
        case .new: return .planned
        case .planned: return .printed
        case .printed: return .delivered
        case .delivered, .cancelled: return nil
        }
    }
}

enum PaymentStatus: String, Codable, CaseIterable, Identifiable {
    case unpaid
    case partial
    case paid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unpaid: return "Unpaid"
        case .partial: return "Partially Paid"
        case .paid: return "Paid"
        }
    }

    var color: Color {
        switch self {
        case .unpaid: return .red
        case .partial: return .orange
        case .paid: return .green
        }
    }
}

struct CustomerResponse: Codable, Identifiable {
    let id: String
    let name: String
    let email: String?
    let phone: String?
    let address: String?
    let notes: String?
    let orderCount: Int?
}

struct CustomerCreateRequest: Codable {
    let name: String
    let email: String?
    let phone: String?
    let address: String?
    let notes: String?
}

struct OrderSourceResponse: Codable, Identifiable {
    let id: String
    let name: String
    let isActive: Bool?
}

struct OrderFileResponse: Codable, Identifiable {
    let id: String
    let orderId: String?
    let fileId: String?
    let url: String?
    let filename: String
    let fileType: String?
}

/// Job entry nested inside an order. The backend embeds raw job rows
/// here (not the transformed JobResponse), so every field is optional.
struct OrderJobSummary: Codable, Identifiable {
    let id: String
    let jobName: String?
    let name: String?
    let filename: String?
    let status: String?

    var displayName: String {
        jobName ?? name ?? filename ?? id
    }
}

struct OrderResponse: Codable, Identifiable {
    let id: String
    let title: String
    let customerId: String?
    let sourceId: String?
    let status: OrderStatus
    let quotedPrice: Double?
    let paymentStatus: PaymentStatus?
    let notes: String?
    let dueDate: String?
    let customer: CustomerResponse?
    let source: OrderSourceResponse?
    let jobs: [OrderJobSummary]?
    let files: [OrderFileResponse]?
    let materialCostEur: Double?
    let energyCostEur: Double?
    let createdAt: String?
    let updatedAt: String?
}

struct OrderListResponse: Codable {
    let orders: [OrderResponse]
    let totalCount: Int
}

struct OrderCreateRequest: Codable {
    let title: String
    let customerId: String?
    let sourceId: String?
    let quotedPrice: Double?
    let paymentStatus: PaymentStatus
    let notes: String?
    let dueDate: String?
}

struct OrderUpdateRequest: Codable {
    var title: String?
    var customerId: String?
    var sourceId: String?
    var status: OrderStatus?
    var quotedPrice: Double?
    var paymentStatus: PaymentStatus?
    var notes: String?
    var dueDate: String?
}

// MARK: - Order Service

/// Customer order management (Porcus3D business features): orders,
/// customers, and order sources.
@MainActor
final class OrderService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    // MARK: Orders

    func listOrders(status: OrderStatus? = nil) async throws -> [OrderResponse] {
        var queryItems: [URLQueryItem] = []
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        let response: OrderListResponse = try await get("orders", queryItems: queryItems)
        return response.orders
    }

    func getOrder(id: String) async throws -> OrderResponse {
        try await get("orders/\(id)")
    }

    func createOrder(_ order: OrderCreateRequest) async throws -> OrderResponse {
        try await send("orders", method: "POST", body: order)
    }

    func updateOrder(id: String, update: OrderUpdateRequest) async throws -> OrderResponse {
        try await send("orders/\(id)", method: "PUT", body: update)
    }

    func deleteOrder(id: String) async throws {
        try await delete("orders/\(id)")
    }

    func linkJob(orderId: String, jobId: String) async throws {
        struct LinkRequest: Codable {
            let jobId: String
        }
        let _: EmptyResponse = try await send(
            "orders/\(orderId)/jobs",
            method: "POST",
            body: LinkRequest(jobId: jobId)
        )
    }

    func unlinkJob(orderId: String, jobId: String) async throws {
        try await delete("orders/\(orderId)/jobs/\(jobId)")
    }

    func attachLibraryFile(orderId: String, fileChecksum: String, filename: String?) async throws {
        struct AttachRequest: Codable {
            let fileId: String
            let filename: String?
        }
        let _: EmptyResponse = try await send(
            "orders/\(orderId)/files",
            method: "POST",
            body: AttachRequest(fileId: fileChecksum, filename: filename)
        )
    }

    func detachFile(orderId: String, orderFileId: String) async throws {
        try await delete("orders/\(orderId)/files/\(orderFileId)")
    }

    // MARK: Customers

    func listCustomers() async throws -> [CustomerResponse] {
        try await get("customers")
    }

    func createCustomer(_ customer: CustomerCreateRequest) async throws -> CustomerResponse {
        try await send("customers", method: "POST", body: customer)
    }

    func updateCustomer(id: String, customer: CustomerCreateRequest) async throws -> CustomerResponse {
        try await send("customers/\(id)", method: "PUT", body: customer)
    }

    func deleteCustomer(id: String) async throws {
        try await delete("customers/\(id)")
    }

    // MARK: Order Sources

    func listOrderSources() async throws -> [OrderSourceResponse] {
        try await get("order-sources")
    }

    func createOrderSource(name: String) async throws -> OrderSourceResponse {
        struct CreateRequest: Codable {
            let name: String
        }
        return try await send("order-sources", method: "POST", body: CreateRequest(name: name))
    }

    func deleteOrderSource(id: String) async throws {
        try await delete("order-sources/\(id)")
    }

    // MARK: - Private Helpers

    /// Decoded stand-in for endpoints whose response body is ignored.
    private struct EmptyResponse: Decodable {
        init(from decoder: Decoder) throws { }
    }

    private func get<T: Decodable>(_ endpoint: String, queryItems: [URLQueryItem] = []) async throws -> T {
        guard let url = APIConfiguration.url(endpoint, queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try checkStatus(response)
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
        try checkStatus(response)
        return try decoder.decode(T.self, from: data)
    }

    private func delete(_ endpoint: String) async throws {
        guard let url = APIConfiguration.url(endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
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

extension OrderResponse {
    static let preview = OrderResponse(
        id: "order-1",
        title: "Vase Set for Anna",
        customerId: "cust-1",
        sourceId: nil,
        status: .planned,
        quotedPrice: 45.0,
        paymentStatus: .unpaid,
        notes: "Deliver before the weekend",
        dueDate: "2026-07-25",
        customer: CustomerResponse(
            id: "cust-1",
            name: "Anna Beispiel",
            email: "anna@example.com",
            phone: nil,
            address: nil,
            notes: nil,
            orderCount: 3
        ),
        source: nil,
        jobs: [],
        files: [],
        materialCostEur: 6.5,
        energyCostEur: 1.2,
        createdAt: "2026-07-18T10:00:00Z",
        updatedAt: "2026-07-18T10:00:00Z"
    )
}
