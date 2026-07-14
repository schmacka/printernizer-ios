import SwiftUI

struct Printer: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let status: PrinterStatus
    let model: String
    var currentJobProgress: Double?

    var statusColor: Color {
        status.color
    }
}

enum PrinterStatus: String, Codable, CaseIterable {
    case idle
    case printing
    case paused
    case error
    case offline

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .printing: return "Printing"
        case .paused: return "Paused"
        case .error: return "Error"
        case .offline: return "Offline"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .green
        case .printing: return .blue
        case .paused: return .orange
        case .error: return .red
        case .offline: return .gray
        }
    }
}

extension PrinterStatus {
    /// Maps a backend status value (online, offline, printing, paused,
    /// error, unknown) to the app's status.
    init(apiValue: String) {
        switch apiValue.lowercased() {
        case "online", "idle":
            self = .idle
        case "printing":
            self = .printing
        case "paused":
            self = .paused
        case "error":
            self = .error
        default:
            self = .offline
        }
    }
}

extension Printer {
    static let preview = Printer(
        id: "1",
        name: "Ender 3 V2",
        status: .printing,
        model: "Creality Ender 3 V2",
        currentJobProgress: 0.65
    )
}
