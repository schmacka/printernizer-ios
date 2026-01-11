import SwiftUI

struct PrinterDetailView: View {
    let printer: Printer
    @StateObject private var viewModel = PrinterDetailViewModel()
    @StateObject private var cameraViewModel = CameraStatusViewModel()
    @EnvironmentObject private var apiService: APIService

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusSection

                if let currentJob = viewModel.currentJob {
                    PrintJobView(job: currentJob)
                }

                // Camera section
                if let cameraStatus = cameraViewModel.cameraStatus, cameraStatus.isAvailable {
                    cameraSection(status: cameraStatus)
                }

                temperatureSection

                controlsSection
            }
            .padding()
        }
        .navigationTitle(printer.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadDetails(for: printer, using: apiService)
            await cameraViewModel.loadCameraStatus(printerId: printer.id)
        }
    }

    @ViewBuilder
    private func cameraSection(status: CameraStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Camera")
                    .font(.headline)

                Spacer()

                NavigationLink {
                    SnapshotGalleryView(printerId: printer.id)
                } label: {
                    HStack(spacing: 4) {
                        Text("Snapshots")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            CameraPreviewView(printerId: printer.id, cameraStatus: status)
        }
    }

    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(printer.statusColor)
                    .frame(width: 12, height: 12)
                Text(printer.status.displayName)
                    .font(.headline)
                Spacer()
            }

            if let currentJob = viewModel.currentJob {
                ProgressRingView(progress: currentJob.progress)
                    .frame(width: 120, height: 120)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temperature")
                .font(.headline)

            HStack(spacing: 24) {
                temperatureCard(
                    title: "Hotend",
                    current: viewModel.hotendTemp,
                    target: viewModel.hotendTarget
                )
                temperatureCard(
                    title: "Bed",
                    current: viewModel.bedTemp,
                    target: viewModel.bedTarget
                )
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func temperatureCard(title: String, current: Double, target: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(Int(current))°C")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Target: \(Int(target))°C")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .font(.headline)

            HStack(spacing: 12) {
                if printer.status == .paused {
                    controlButton(
                        title: "Resume",
                        systemImage: "play.fill",
                        action: { Task { await viewModel.resumePrint(using: apiService) } }
                    )
                } else {
                    controlButton(
                        title: "Pause",
                        systemImage: "pause.fill",
                        action: { Task { await viewModel.pausePrint(using: apiService) } }
                    )
                    .disabled(printer.status != .printing)
                }

                controlButton(
                    title: "Stop",
                    systemImage: "stop.fill",
                    action: { Task { await viewModel.stopPrint(using: apiService) } }
                )
                .disabled(printer.status != .printing && printer.status != .paused)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func controlButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    NavigationStack {
        PrinterDetailView(printer: .preview)
            .environmentObject(APIService())
    }
}
