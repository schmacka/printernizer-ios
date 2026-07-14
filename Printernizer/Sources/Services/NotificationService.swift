import Foundation
import Combine
import UserNotifications

/// Posts local notifications for print completion, print failure, and
/// printer-offline transitions, driven by live printer_status events
/// while the app is running. Honors the notification toggles in
/// Settings (which use @AppStorage defaults of true).
@MainActor
final class NotificationService: ObservableObject {
    private var cancellable: AnyCancellable?
    private var lastStatusByPrinter: [String: PrinterStatus] = [:]
    private var lastJobByPrinter: [String: String] = [:]
    private var hasRequestedAuthorization = false

    func bind(to webSocketService: WebSocketService) {
        cancellable = webSocketService.$lastMessage
            .compactMap { message -> (String, PrinterStatusData)? in
                if case .printerStatus(let printerId, let data) = message {
                    return (printerId, data)
                }
                return nil
            }
            .sink { [weak self] printerId, data in
                self?.handle(printerId: printerId, data: data)
            }
    }

    // MARK: - Settings

    /// Matches @AppStorage defaults: unset means enabled.
    private func setting(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    // MARK: - Event Handling

    private func handle(printerId: String, data: PrinterStatusData) {
        guard let statusValue = data.status else { return }

        let newStatus = PrinterStatus(apiValue: statusValue)
        let previousStatus = lastStatusByPrinter[printerId]
        lastStatusByPrinter[printerId] = newStatus

        if let job = data.currentJob, !job.isEmpty {
            lastJobByPrinter[printerId] = job
        }

        guard setting("notificationsEnabled"), let previousStatus, previousStatus != newStatus else {
            return
        }

        let jobName = lastJobByPrinter[printerId]

        switch (previousStatus, newStatus) {
        case (.printing, .idle):
            if setting("notifyPrintCompleted") {
                post(
                    title: "Print Completed",
                    body: jobName.map { "\"\($0)\" finished printing." } ?? "A print job finished."
                )
            }

        case (_, .error):
            if setting("notifyPrintFailed") {
                post(
                    title: "Print Failed",
                    body: data.message ?? jobName.map { "\"\($0)\" reported an error." } ?? "A printer reported an error."
                )
            }

        case (_, .offline):
            if setting("notifyPrinterOffline") {
                post(
                    title: "Printer Offline",
                    body: data.message ?? "A printer went offline."
                )
            }

        default:
            break
        }
    }

    // MARK: - Posting

    private func post(title: String, body: String) {
        requestAuthorizationIfNeeded { granted in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()

        if hasRequestedAuthorization {
            center.getNotificationSettings { settings in
                completion(settings.authorizationStatus == .authorized)
            }
            return
        }

        hasRequestedAuthorization = true
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            completion(granted)
        }
    }
}
