import SwiftUI

/// Curated external 3D-printing tools — mirrors the web app's static
/// Tools page (frontend/js/tools.js). Links open in the browser.
struct ToolsView: View {
    struct Tool: Identifiable {
        let id: String
        let title: String
        let description: String
        let url: String
        let icon: String
        let category: String
    }

    static let tools: [Tool] = [
        Tool(
            id: "gridfinity-layout",
            title: "Gridfinity Layout Tool",
            description: "Design and plan Gridfinity storage layouts with an interactive visual editor.",
            url: "https://www.gridfinitylayouttool.com/l/G3rQIfJ2eXsu/untitled-layout",
            icon: "square.grid.3x3",
            category: "Gridfinity"
        ),
        Tool(
            id: "bento3d-gridfinity",
            title: "Bento3D Gridfinity",
            description: "Create custom 3D-printable Gridfinity boxes in minutes.",
            url: "https://bento3d.design/gridfinity",
            icon: "shippingbox",
            category: "Gridfinity"
        ),
        Tool(
            id: "gridfinity-rebuilt-openscad",
            title: "Gridfinity Rebuilt OpenSCAD",
            description: "Parametric Gridfinity bin generator with dividers, magnets, and custom dimensions.",
            url: "https://github.com/kennetek/gridfinity-rebuilt-openscad",
            icon: "square.grid.3x3.fill",
            category: "Gridfinity"
        ),
        Tool(
            id: "tooltrace-ai",
            title: "ToolTrace AI",
            description: "AI-powered assistant for print settings, troubleshooting, and model optimization.",
            url: "https://www.tooltrace.ai/",
            icon: "brain",
            category: "AI Assistant"
        ),
        Tool(
            id: "3dbenchy",
            title: "Official 3DBenchy",
            description: "The gold-standard torture test model for calibrating and testing 3D printers.",
            url: "https://www.3dbenchy.com/download/",
            icon: "sailboat",
            category: "Calibration"
        ),
        Tool(
            id: "organic-relief-plate",
            title: "Organic Relief Plate Generator",
            description: "OpenSCAD generator for unique decorative relief plates.",
            url: "https://makerworld.com/de/models/2339750-organic-relief-plate-generator-openscad",
            icon: "paintpalette",
            category: "Design"
        ),
        Tool(
            id: "web-openscad-editor",
            title: "Web OpenSCAD Editor",
            description: "Browser-based OpenSCAD editor — create and preview parametric models without installing anything.",
            url: "https://github.com/yawkat/web-openscad-editor",
            icon: "curlybraces",
            category: "Design"
        ),
        Tool(
            id: "the-hornet-blade-generator",
            title: "The Hornet – Blade Generator",
            description: "Fully parametric propeller and fan generator in OpenSCAD.",
            url: "https://makerworld.com/en/models/2620727",
            icon: "fan",
            category: "Design"
        )
    ]

    @State private var selectedCategory: String?

    private var categories: [String] {
        Array(Set(Self.tools.map(\.category))).sorted()
    }

    private var filteredTools: [Tool] {
        guard let selectedCategory else { return Self.tools }
        return Self.tools.filter { $0.category == selectedCategory }
    }

    var body: some View {
        List {
            ForEach(filteredTools) { tool in
                if let url = URL(string: tool.url) {
                    Link(destination: url) {
                        HStack(spacing: 12) {
                            Image(systemName: tool.icon)
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(tool.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(tool.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(tool.category)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Categories").tag(String?.none)
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(String?.some(category))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ToolsView()
    }
}
