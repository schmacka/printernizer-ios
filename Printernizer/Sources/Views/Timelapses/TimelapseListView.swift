import SwiftUI
import AVKit

/// Timelapse video gallery, pushed from the More tab.
struct TimelapseListView: View {
    @StateObject private var viewModel = TimelapseListViewModel()
    @State private var statusFilter: String?
    @State private var linkedOnly = false
    @State private var playingTimelapse: TimelapseResponse?
    @State private var timelapseToDelete: TimelapseResponse?

    private static let statusOptions = ["discovered", "pending", "processing", "completed", "failed"]

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.timelapses.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.timelapses.isEmpty {
                ContentUnavailableView(
                    "No Timelapses",
                    systemImage: "video",
                    description: Text("Timelapse recordings from your printers will appear here.")
                )
            } else {
                timelapseList
            }
        }
        .navigationTitle("Timelapses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $statusFilter) {
                        Text("All Statuses").tag(String?.none)
                        ForEach(Self.statusOptions, id: \.self) { status in
                            Text(status.capitalized).tag(String?.some(status))
                        }
                    }

                    Toggle("Linked to Jobs Only", isOn: $linkedOnly)
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onChange(of: statusFilter) { _, _ in
            Task { await viewModel.load(status: statusFilter, linkedOnly: linkedOnly) }
        }
        .onChange(of: linkedOnly) { _, _ in
            Task { await viewModel.load(status: statusFilter, linkedOnly: linkedOnly) }
        }
        .refreshable {
            await viewModel.load(status: statusFilter, linkedOnly: linkedOnly)
        }
        .task {
            guard APIConfiguration.isConfigured else { return }
            await viewModel.load(status: statusFilter, linkedOnly: linkedOnly)
        }
        .sheet(item: $playingTimelapse) { timelapse in
            TimelapsePlayerView(timelapse: timelapse)
        }
        .confirmationDialog(
            "Delete Timelapse?",
            isPresented: Binding(
                get: { timelapseToDelete != nil },
                set: { if !$0 { timelapseToDelete = nil } }
            ),
            presenting: timelapseToDelete
        ) { timelapse in
            Button("Delete \(timelapse.displayName)", role: .destructive) {
                Task { await viewModel.delete(timelapse) }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var timelapseList: some View {
        List {
            if let stats = viewModel.stats {
                statsSection(stats)
            }

            Section {
                ForEach(viewModel.timelapses) { timelapse in
                    timelapseRow(timelapse)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                timelapseToDelete = timelapse
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                Task { await viewModel.togglePin(timelapse) }
                            } label: {
                                Label(timelapse.pinned == true ? "Unpin" : "Pin", systemImage: "pin")
                            }
                            .tint(.orange)
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func statsSection(_ stats: TimelapseStats) -> some View {
        Section {
            HStack(spacing: 16) {
                StatCard(title: "Videos", value: "\(stats.totalVideos ?? 0)", icon: "video.fill", color: .blue)
                StatCard(title: "Processing", value: "\(stats.processingCount ?? 0)", icon: "gearshape.fill", color: .orange)
                StatCard(title: "Storage", value: storageText(stats), icon: "internaldrive.fill", color: .green)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func storageText(_ stats: TimelapseStats) -> String {
        if let gb = stats.totalSizeGb, gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        return String(format: "%.0f MB", stats.totalSizeMb ?? 0)
    }

    private func timelapseRow(_ timelapse: TimelapseResponse) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 56, height: 42)

                Image(systemName: timelapse.videoExists == true ? "play.fill" : "video.slash")
                    .foregroundStyle(timelapse.videoExists == true ? .blue : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(timelapse.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if timelapse.pinned == true {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 8) {
                    Text((timelapse.status ?? "unknown").capitalized)
                        .font(.caption)
                        .foregroundStyle(timelapse.statusColor)

                    if let size = timelapse.formattedSize {
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let duration = timelapse.formattedDuration {
                        Text(duration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if timelapse.jobId != nil {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if timelapse.videoExists != true,
               ["discovered", "pending", "failed"].contains((timelapse.status ?? "").lowercased()) {
                Button("Process") {
                    Task { await viewModel.process(timelapse) }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if timelapse.videoExists == true {
                playingTimelapse = timelapse
            }
        }
    }
}

/// Full-screen video playback for a rendered timelapse.
struct TimelapsePlayerView: View {
    let timelapse: TimelapseResponse

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    private let timelapseService = TimelapseService()

    var body: some View {
        NavigationStack {
            Group {
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView(
                        "Video Unavailable",
                        systemImage: "video.slash",
                        description: Text("The timelapse video could not be loaded.")
                    )
                }
            }
            .navigationTitle(timelapse.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                if let url = timelapseService.videoURL(id: timelapse.id) {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                if let url = timelapseService.videoURL(id: timelapse.id) {
                    let player = AVPlayer(url: url)
                    self.player = player
                    player.play()
                }
            }
            .onDisappear {
                player?.pause()
            }
        }
    }
}

@MainActor
final class TimelapseListViewModel: ObservableObject {
    @Published var timelapses: [TimelapseResponse] = []
    @Published var stats: TimelapseStats?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let timelapseService = TimelapseService()

    func load(status: String?, linkedOnly: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            timelapses = try await timelapseService.listTimelapses(status: status, linkedOnly: linkedOnly)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        stats = try? await timelapseService.stats()
    }

    func process(_ timelapse: TimelapseResponse) async {
        do {
            try await timelapseService.process(id: timelapse.id)
            await load(status: nil, linkedOnly: false)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func togglePin(_ timelapse: TimelapseResponse) async {
        do {
            try await timelapseService.togglePin(id: timelapse.id)
            await load(status: nil, linkedOnly: false)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func delete(_ timelapse: TimelapseResponse) async {
        do {
            try await timelapseService.delete(id: timelapse.id)
            timelapses.removeAll { $0.id == timelapse.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        TimelapseListView()
    }
}
