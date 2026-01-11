import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PrinterListView()
                .tabItem {
                    Label("Printers", systemImage: "printer.fill")
                }
                .tag(0)

            JobListView()
                .tabItem {
                    Label("Jobs", systemImage: "doc.text")
                }
                .tag(1)

            FileListView()
                .tabItem {
                    Label("Files", systemImage: "folder")
                }
                .tag(2)

            MaterialListView()
                .tabItem {
                    Label("Materials", systemImage: "cylinder")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(APIService())
}
