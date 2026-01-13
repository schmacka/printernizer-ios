import Foundation
import Combine

// MARK: - WebSocket Message Types

enum WebSocketMessage: Equatable {
    case printerStatus(printerId: String, data: PrinterStatusData)
    case jobUpdate(jobId: String, data: JobUpdateData)
    case systemEvent(eventType: String, data: SystemEventData)
    case subscribed(printerId: String)
    case unsubscribed(printerId: String)
    case pong
    case error(message: String)
    case connectionStatus(Bool)
}

struct PrinterStatusData: Codable, Equatable {
    let status: String?
    let progress: Int?
    let currentJob: String?
    let temperatureBed: Double?
    let temperatureNozzle: Double?
    let remainingTimeMinutes: Int?
}

struct JobUpdateData: Codable, Equatable {
    let status: String?
    let progress: Int?
    let fileName: String?
}

struct SystemEventData: Codable, Equatable {
    let printerId: String?
    let message: String?
}

// MARK: - WebSocket Protocol Messages

private struct WSIncomingMessage: Codable {
    let type: String
    let printerId: String?
    let jobId: String?
    let eventType: String?
    let data: WSMessageData?
    let message: String?
}

private struct WSMessageData: Codable {
    let status: String?
    let progress: Int?
    let currentJob: String?
    let temperatureBed: Double?
    let temperatureNozzle: Double?
    let remainingTimeMinutes: Int?
    let fileName: String?
    let printerId: String?
    let message: String?
}

private struct WSOutgoingMessage: Codable {
    let type: String
    let printerId: String?

    init(type: String, printerId: String? = nil) {
        self.type = type
        self.printerId = printerId
    }
}

final class WebSocketService: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var lastMessage: WebSocketMessage?

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var baseURL: String = ""
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    init() {
        self.session = URLSession(configuration: .default)
    }

    func connect(to url: String) {
        baseURL = url
        reconnectAttempts = 0
        establishConnection()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func establishConnection() {
        guard !baseURL.isEmpty else { return }

        let wsURL = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let url = URL(string: "\(wsURL)/ws") else { return }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        isConnected = true
        lastMessage = .connectionStatus(true)
        receiveMessage()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()

            case .failure:
                self.handleDisconnection()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseMessage(text)
            }
        @unknown default:
            break
        }
    }

    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let message = try decoder.decode(WSIncomingMessage.self, from: data)
            let parsed = convertToWebSocketMessage(message)

            DispatchQueue.main.async { [weak self] in
                self?.lastMessage = parsed
            }
        } catch {
            // JSON parsing failed, ignore malformed message
        }
    }

    private func convertToWebSocketMessage(_ msg: WSIncomingMessage) -> WebSocketMessage {
        switch msg.type {
        case "printer_status":
            let statusData = PrinterStatusData(
                status: msg.data?.status,
                progress: msg.data?.progress,
                currentJob: msg.data?.currentJob,
                temperatureBed: msg.data?.temperatureBed,
                temperatureNozzle: msg.data?.temperatureNozzle,
                remainingTimeMinutes: msg.data?.remainingTimeMinutes
            )
            return .printerStatus(printerId: msg.printerId ?? "", data: statusData)

        case "job_update":
            let jobData = JobUpdateData(
                status: msg.data?.status,
                progress: msg.data?.progress,
                fileName: msg.data?.fileName
            )
            return .jobUpdate(jobId: msg.jobId ?? "", data: jobData)

        case "system_event":
            let eventData = SystemEventData(
                printerId: msg.data?.printerId,
                message: msg.data?.message
            )
            return .systemEvent(eventType: msg.eventType ?? "", data: eventData)

        case "subscribed":
            return .subscribed(printerId: msg.printerId ?? "")

        case "unsubscribed":
            return .unsubscribed(printerId: msg.printerId ?? "")

        case "pong":
            return .pong

        case "error":
            return .error(message: msg.message ?? "Unknown error")

        default:
            return .error(message: "Unknown message type: \(msg.type)")
        }
    }

    // MARK: - Subscription Management

    func subscribeToPrinter(_ printerId: String) {
        let message = WSOutgoingMessage(type: "subscribe_printer", printerId: printerId)
        sendJSON(message)
    }

    func unsubscribeFromPrinter(_ printerId: String) {
        let message = WSOutgoingMessage(type: "unsubscribe_printer", printerId: printerId)
        sendJSON(message)
    }

    func sendPing() {
        let message = WSOutgoingMessage(type: "ping")
        sendJSON(message)
    }

    private func sendJSON<T: Encodable>(_ object: T) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let data = try? encoder.encode(object),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        send(text)
    }

    private func handleDisconnection() {
        isConnected = false
        lastMessage = .connectionStatus(false)

        guard reconnectAttempts < maxReconnectAttempts else {
            return
        }

        reconnectAttempts += 1
        let delay = Double(reconnectAttempts) * 2

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.establishConnection()
        }
    }

    func send(_ message: String) {
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(wsMessage) { _ in }
    }
}
