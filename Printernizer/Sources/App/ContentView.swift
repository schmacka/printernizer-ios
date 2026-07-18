import SwiftUI

enum AppTab: Hashable {
    case dashboard
    case printers
    case jobs
    case library
    case more
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
                .tag(AppTab.dashboard)

            PrinterListView()
                .tabItem {
                    Label("Printers", systemImage: "printer.fill")
                }
                .tag(AppTab.printers)

            JobListView()
                .tabItem {
                    Label("Jobs", systemImage: "doc.text")
                }
                .tag(AppTab.jobs)

            LibraryListView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(AppTab.library)

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
                .tag(AppTab.more)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(APIService())
        .environmentObject(WebSocketService())
}
