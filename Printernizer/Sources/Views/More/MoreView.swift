import SwiftUI

/// Destinations reachable from the More tab. New feature areas get a case
/// here instead of a new root tab, keeping the tab bar at five items.
enum MoreDestination: Hashable {
    case materials
    case ideas
    case timelapses
    case generator
    case settings
}

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(value: MoreDestination.materials) {
                        Label("Materials", systemImage: "cylinder")
                    }

                    NavigationLink(value: MoreDestination.ideas) {
                        Label("Ideas", systemImage: "lightbulb")
                    }

                    NavigationLink(value: MoreDestination.timelapses) {
                        Label("Timelapses", systemImage: "video")
                    }

                    NavigationLink(value: MoreDestination.generator) {
                        Label("Generator", systemImage: "cube.transparent")
                    }
                }

                Section {
                    NavigationLink(value: MoreDestination.settings) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("More")
            .navigationDestination(for: MoreDestination.self) { destination in
                switch destination {
                case .materials:
                    MaterialListView()
                case .ideas:
                    IdeaListView()
                case .timelapses:
                    TimelapseListView()
                case .generator:
                    GeneratorView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    MoreView()
        .environmentObject(APIService())
        .environmentObject(WebSocketService())
}
