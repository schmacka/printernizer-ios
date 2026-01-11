import SwiftUI

struct CameraPreviewView: View {
    let printerId: String
    let cameraStatus: CameraStatus

    @StateObject private var viewModel = CameraPreviewViewModel()
    @State private var showSnapshotConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // Preview Image
            ZStack {
                if let image = viewModel.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 200)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No preview available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 200)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Controls
            HStack(spacing: 16) {
                // Auto-refresh toggle
                Toggle(isOn: $viewModel.autoRefreshEnabled) {
                    Label("Auto", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(viewModel.autoRefreshEnabled ? .blue : .gray)

                Spacer()

                // Manual refresh
                Button {
                    Task {
                        await viewModel.refreshPreview()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)

                // Take snapshot
                Button {
                    Task {
                        await viewModel.takeSnapshot()
                        showSnapshotConfirmation = true
                    }
                } label: {
                    Image(systemName: "camera.shutter.button")
                }
                .disabled(viewModel.isLoading || viewModel.isTakingSnapshot)
            }
            .padding(.horizontal, 4)

            // Status indicator
            if viewModel.autoRefreshEnabled {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task {
            viewModel.configure(printerId: printerId, useExternal: !cameraStatus.hasCamera && cameraStatus.hasExternalWebcam)
            await viewModel.startPreview()
        }
        .onDisappear {
            viewModel.stopPreview()
        }
        .alert("Snapshot Saved", isPresented: $showSnapshotConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Snapshot has been saved successfully.")
        }
    }
}

// MARK: - View Model

@MainActor
final class CameraPreviewViewModel: ObservableObject {
    @Published var previewImage: UIImage?
    @Published var isLoading = false
    @Published var isTakingSnapshot = false
    @Published var errorMessage: String?
    @Published var autoRefreshEnabled = true {
        didSet {
            if autoRefreshEnabled {
                startAutoRefresh()
            } else {
                stopAutoRefresh()
            }
        }
    }

    private var printerId: String = ""
    private var useExternal: Bool = false
    private var refreshTask: Task<Void, Never>?
    private let cameraService = CameraService()
    private let refreshInterval: TimeInterval = 3.0 // seconds

    func configure(printerId: String, useExternal: Bool) {
        self.printerId = printerId
        self.useExternal = useExternal
    }

    func startPreview() async {
        await refreshPreview()
        if autoRefreshEnabled {
            startAutoRefresh()
        }
    }

    func stopPreview() {
        stopAutoRefresh()
    }

    func refreshPreview() async {
        guard !printerId.isEmpty else { return }

        isLoading = previewImage == nil
        errorMessage = nil

        do {
            let image = try await cameraService.getPreviewImage(printerId: printerId, useExternal: useExternal)
            previewImage = image
            errorMessage = nil
        } catch let error as CameraError {
            if previewImage == nil {
                errorMessage = error.localizedDescription
            }
        } catch {
            if previewImage == nil {
                errorMessage = "Failed to load preview"
            }
        }

        isLoading = false
    }

    func takeSnapshot() async {
        guard !printerId.isEmpty else { return }

        isTakingSnapshot = true
        defer { isTakingSnapshot = false }

        do {
            _ = try await cameraService.takeSnapshot(printerId: printerId)
        } catch {
            errorMessage = "Failed to take snapshot"
        }
    }

    private func startAutoRefresh() {
        stopAutoRefresh()

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.refreshInterval ?? 3.0))
                guard !Task.isCancelled else { break }
                await self?.refreshPreview()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

#Preview {
    CameraPreviewView(
        printerId: "test-printer",
        cameraStatus: CameraStatus(
            hasCamera: true,
            hasExternalWebcam: false,
            isAvailable: true,
            streamUrl: nil,
            externalWebcamUrl: nil,
            externalWebcamType: nil,
            ffmpegAvailable: true,
            ffmpegRequired: false,
            errorMessage: nil
        )
    )
    .padding()
}
