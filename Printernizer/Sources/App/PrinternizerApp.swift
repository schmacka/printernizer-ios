import SwiftUI

@main
struct PrinternizerApp: App {
    @StateObject private var apiService = APIService()
    @StateObject private var webSocketService = WebSocketService()
    @StateObject private var notificationService = NotificationService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(apiService)
                .environmentObject(webSocketService)
                .onAppear {
                    notificationService.bind(to: webSocketService)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        if APIConfiguration.isConfigured {
                            webSocketService.connect()
                        }
                    case .background:
                        webSocketService.disconnect()
                    default:
                        break
                    }
                }
        }
    }
}
