import SwiftUI

@main
struct PrinternizerApp: App {
    @StateObject private var apiService = APIService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(apiService)
        }
    }
}
