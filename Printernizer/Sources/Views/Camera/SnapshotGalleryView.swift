import SwiftUI

struct SnapshotGalleryView: View {
    let printerId: String

    @StateObject private var viewModel = SnapshotGalleryViewModel()
    @State private var selectedSnapshot: SnapshotResponse?

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
    ]

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.snapshots.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.snapshots.isEmpty {
                ContentUnavailableView(
                    "No Snapshots",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Take a snapshot from the camera preview to see it here.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(viewModel.snapshots) { snapshot in
                            SnapshotThumbnailView(snapshot: snapshot)
                                .onTapGesture {
                                    selectedSnapshot = snapshot
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Snapshots")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadSnapshots()
        }
        .task {
            viewModel.configure(printerId: printerId)
            await viewModel.loadSnapshots()
        }
        .sheet(item: $selectedSnapshot) { snapshot in
            NavigationStack {
                SnapshotDetailView(snapshot: snapshot)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

// MARK: - Snapshot Thumbnail View

struct SnapshotThumbnailView: View {
    let snapshot: SnapshotResponse

    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true

    private let cameraService = CameraService()

    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100, height: 100)
        .background(Color.gray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottomTrailing) {
            if snapshot.captureTrigger != "manual" {
                Image(systemName: triggerIcon)
                    .font(.caption2)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(4)
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private var triggerIcon: String {
        switch snapshot.captureTrigger {
        case "job_start":
            return "play.fill"
        case "job_complete":
            return "checkmark"
        case "job_failed":
            return "xmark"
        case "auto":
            return "arrow.clockwise"
        default:
            return "camera"
        }
    }

    private func loadThumbnail() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let image = try await cameraService.downloadSnapshotImage(snapshotId: snapshot.id)
            thumbnailImage = image
        } catch {
            // Failed to load thumbnail
        }
    }
}

// MARK: - View Model

@MainActor
final class SnapshotGalleryViewModel: ObservableObject {
    @Published var snapshots: [SnapshotResponse] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private var printerId: String = ""
    private let cameraService = CameraService()

    func configure(printerId: String) {
        self.printerId = printerId
    }

    func loadSnapshots() async {
        guard !printerId.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            snapshots = try await cameraService.listSnapshots(printerId: printerId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        SnapshotGalleryView(printerId: "test-printer")
    }
}
