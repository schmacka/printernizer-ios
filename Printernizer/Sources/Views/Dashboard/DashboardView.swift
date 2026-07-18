import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Dashboard",
                systemImage: "square.grid.2x2",
                description: Text("An overview of your printers, jobs, and files is coming soon.")
            )
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(APIService())
        .environmentObject(WebSocketService())
}
