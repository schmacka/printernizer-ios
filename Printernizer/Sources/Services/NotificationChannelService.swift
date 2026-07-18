import Foundation

// MARK: - Notification Channel Models

enum NotificationChannelType: String, Codable, CaseIterable, Identifiable {
    case discord
    case slack
    case ntfy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .discord: return "Discord"
        case .slack: return "Slack"
        case .ntfy: return "ntfy"
        }
    }

    var urlFieldLabel: String {
        self == .ntfy ? "Server URL" : "Webhook URL"
    }
}

struct NotificationChannel: Codable, Identifiable {
    let id: String
    let name: String
    let channelType: NotificationChannelType
    let webhookUrl: String
    let topic: String?
    let isEnabled: Bool
    let subscribedEvents: [String]
}

struct NotificationEventType: Codable, Identifiable {
    let id: String
    let label: String?
    let description: String?
}

struct ChannelCreateRequest: Codable {
    let name: String
    let channelType: NotificationChannelType
    let webhookUrl: String
    let topic: String?
    let isEnabled: Bool
    let subscribedEvents: [String]
}

struct ChannelUpdateRequest: Codable {
    var name: String?
    var webhookUrl: String?
    var topic: String?
    var isEnabled: Bool?
}

private struct ChannelListResponse: Codable {
    let channels: [NotificationChannel]
}

private struct EventListResponse: Codable {
    let events: [NotificationEventType]
}

// MARK: - Notification Channel Service

/// Server-side notification channels (Discord/Slack/ntfy webhooks).
/// Distinct from the on-device NotificationService, which posts local
/// notifications from live WebSocket status transitions.
@MainActor
final class NotificationChannelService: ObservableObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        self.session = URLSession.shared
        self.decoder = APIConfiguration.makeDecoder()
        self.encoder = APIConfiguration.makeEncoder()
    }

    func listChannels() async throws -> [NotificationChannel] {
        let response: ChannelListResponse = try await get("notifications")
        return response.channels
    }

    func listEventTypes() async throws -> [NotificationEventType] {
        let response: EventListResponse = try await get("notifications/events")
        return response.events
    }

    func createChannel(_ channel: ChannelCreateRequest) async throws -> NotificationChannel {
        try await send("notifications", method: "POST", body: channel)
    }

    func updateChannel(id: String, update: ChannelUpdateRequest) async throws -> NotificationChannel {
        try await send("notifications/\(id)", method: "PUT", body: update)
    }

    func updateSubscriptions(id: String, events: [String]) async throws {
        struct SubscriptionUpdate: Codable {
            let subscribedEvents: [String]
        }

        guard let url = APIConfiguration.url("notifications/\(id)/subscriptions") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(SubscriptionUpdate(subscribedEvents: events))

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    func deleteChannel(id: String) async throws {
        guard let url = APIConfiguration.url("notifications/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    /// Sends a test notification through the channel.
    func testChannel(id: String) async throws {
        guard let url = APIConfiguration.url("notifications/\(id)/test") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = APIConfiguration.url(endpoint) else {
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

    private func checkStatus(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}
