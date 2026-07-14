import SwiftUI

@main
struct PrinternizerApp: App {
    @StateObject private var apiService = APIService()
    @StateObject private var webSocketService = WebSocketService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(apiService)
                .environmentObject(webSocketService)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        if !apiService.baseURL.isEmpty {
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
