import SwiftUI

/// Read-only server log viewer with level/source filters and clear —
/// the mobile counterpart of the web debug page. Reached from
/// Settings.
struct LogViewerView: View {
    @StateObject private var viewModel = LogViewerViewModel()
    @State private var levelFilter: String?
    @State private var sourceFilter: String?
    @State private var showClearConfirmation = false

    private static let levels = ["debug", "info", "warn", "error"]
    private static let sources = ["backend", "frontend", "errors"]

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.entries.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.plaintext",
                    description: Text("Server log entries will appear here.")
                )
            } else {
                logList
            }
        }
        .navigationTitle("Server Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Level", selection: $levelFilter) {
                        Text("All Levels").tag(String?.none)
                        ForEach(Self.levels, id: \.self) { level in
                            Text(level.uppercased()).tag(String?.some(level))
                        }
                    }

                    Picker("Source", selection: $sourceFilter) {
                        Text("All Sources").tag(String?.none)
                        ForEach(Self.sources, id: \.self) { source in
                            Text(source.capitalized).tag(String?.some(source))
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear Logs", systemImage: "trash")
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onChange(of: levelFilter) { _, _ in
            Task { await viewModel.load(source: sourceFilter, level: levelFilter) }
        }
        .onChange(of: sourceFilter) { _, _ in
            Task { await viewModel.load(source: sourceFilter, level: levelFilter) }
        }
        .refreshable {
            await viewModel.load(source: sourceFilter, level: levelFilter)
        }
        .task {
            await viewModel.load(source: sourceFilter, level: levelFilter)
        }
        .confirmationDialog("Clear all server logs?", isPresented: $showClearConfirmation) {
            Button("Clear Logs", role: .destructive) {
                Task { await viewModel.clear() }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var logList: some View {
        List {
            ForEach(viewModel.entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text((entry.level ?? "log").uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(entry.levelColor.opacity(0.15))
                            .foregroundStyle(entry.levelColor)
                            .clipShape(Capsule())

                        if let category = entry.category, !category.isEmpty {
                            Text(category)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let date = Formatters.mediumDateTime(entry.timestamp) {
                            Text(date)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Text(entry.message)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .lineLimit(4)
                }
                .padding(.vertical, 2)
            }

            if viewModel.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        Task { await viewModel.loadMore(source: sourceFilter, level: levelFilter) }
                    }
            }
        }
        .listStyle(.plain)
    }
}

@MainActor
final class LogViewerViewModel: ObservableObject {
    @Published var entries: [LogEntry] = []
    @Published var isLoading = false
    @Published var hasMore = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let logService = LogService()
    private var page = 1

    func load(source: String?, level: String?) async {
        page = 1
        await fetch(source: source, level: level, replace: true)
    }

    func loadMore(source: String?, level: String?) async {
        guard hasMore, !isLoading else { return }
        page += 1
        await fetch(source: source, level: level, replace: false)
    }

    private func fetch(source: String?, level: String?, replace: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await logService.queryLogs(source: source, level: level, page: page)
            if replace {
                entries = result.data
            } else {
                entries.append(contentsOf: result.data)
            }
            hasMore = page < (result.pagination?.totalPages ?? 1)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func clear() async {
        do {
            try await logService.clearLogs()
            entries = []
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        LogViewerView()
    }
}
