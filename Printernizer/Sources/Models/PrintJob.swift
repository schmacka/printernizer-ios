import Foundation

struct PrintJob: Identifiable, Codable, Equatable {
    let id: String
    let fileName: String
    let progress: Double
    let elapsedSeconds: Int
    let estimatedTotalSeconds: Int?
    let currentLayer: Int?
    let totalLayers: Int?
    let filamentUsedMm: Double

    var remainingSeconds: Int? {
        guard let total = estimatedTotalSeconds else { return nil }
        return max(0, total - elapsedSeconds)
    }

    var formattedElapsedTime: String {
        formatDuration(elapsedSeconds)
    }

    var formattedTimeRemaining: String? {
        guard let remaining = remainingSeconds else { return nil }
        return formatDuration(remaining)
    }

    var formattedFilamentUsed: String {
        let meters = filamentUsedMm / 1000
        if meters >= 1 {
            return String(format: "%.1fm", meters)
        } else {
            return String(format: "%.0fmm", filamentUsedMm)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

extension PrintJob {
    static let preview = PrintJob(
        id: "job-1",
        fileName: "benchy.gcode",
        progress: 0.65,
        elapsedSeconds: 3600,
        estimatedTotalSeconds: 5400,
        currentLayer: 130,
        totalLayers: 200,
        filamentUsedMm: 2500
    )
}
