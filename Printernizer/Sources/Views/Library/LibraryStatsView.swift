import SwiftUI

/// Library statistics sheet (GET /library/statistics).
struct LibraryStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stats: LibraryStatistics?
    @State private var errorMessage: String?

    private let libraryService = LibraryService()

    var body: some View {
        NavigationStack {
            List {
                if let stats {
                    Section("Files") {
                        LabeledContent("Total Files", value: "\(stats.totalFiles ?? 0)")
                        LabeledContent("With Thumbnails", value: "\(stats.filesWithThumbnails ?? 0)")
                        LabeledContent("Analyzed", value: "\(stats.filesAnalyzed ?? 0)")
                        LabeledContent("Available", value: "\(stats.availableFiles ?? 0)")
                        LabeledContent("Processing", value: "\(stats.processingFiles ?? 0)")
                        LabeledContent("Errors", value: "\(stats.errorFiles ?? 0)")
                    }

                    Section("Storage & Cost") {
                        if let size = stats.totalSize {
                            LabeledContent("Total Size", value: formatBytes(size))
                        }
                        if let cost = stats.totalMaterialCost, cost > 0 {
                            LabeledContent("Total Material Cost", value: Formatters.eurString(cost))
                        }
                    }
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                } else {
                    HStack {
                        ProgressView()
                        Text("Loading statistics…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Library Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                do {
                    stats = try await libraryService.statistics()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000_000 {
            return String(format: "%.2f GB", Double(bytes) / 1_000_000_000)
        }
        return String(format: "%.1f MB", Double(bytes) / 1_000_000)
    }
}

#Preview {
    LibraryStatsView()
}
