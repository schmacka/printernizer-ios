import SwiftUI

struct PrinterDetailView: View {
    let printer: Printer
    @StateObject private var viewModel = PrinterDetailViewModel()
    @StateObject private var cameraViewModel = CameraStatusViewModel()
    @EnvironmentObject private var apiService: APIService
    @EnvironmentObject private var webSocketService: WebSocketService
    @State private var showEditPrinter = false

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
                } else if let cameraStatus = cameraViewModel.cameraStatus,
                          let errorMessage = cameraStatus.errorMessage {
                    cameraUnavailableSection(message: errorMessage)
                }

                temperatureSection

                controlsSection

                managementSection

                if let statistics = viewModel.statistics {
                    statisticsSection(statistics)
                }

                if !viewModel.recentJobs.isEmpty {
                    recentJobsSection
                }
            }
            .padding()
        }
        .navigationTitle(printer.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showEditPrinter = true
                }
            }
        }
        .sheet(isPresented: $showEditPrinter) {
            PrinterFormView(printerId: printer.id) {
                Task { await viewModel.loadDetails(for: printer, using: apiService) }
            }
        }
        .task {
            webSocketService.subscribeToPrinter(printer.id)
            await viewModel.loadDetails(for: printer, using: apiService)
            await cameraViewModel.loadCameraStatus(printerId: printer.id)
        }
        .onReceive(webSocketService.$lastMessage) { message in
            if case .printerStatus(let printerId, let data) = message, printerId == printer.id {
                viewModel.handlePrinterStatusUpdate(data)
            }
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
                    CameraDiagnosticsView(printerId: printer.id)
                } label: {
                    Image(systemName: "stethoscope")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

    private func cameraUnavailableSection(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "video.slash")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Management")
                    .font(.headline)

                Spacer()

                if viewModel.isPerformingAction {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            HStack(spacing: 12) {
                controlButton(
                    title: viewModel.isConnected ? "Disconnect" : "Connect",
                    systemImage: viewModel.isConnected ? "link.badge.plus" : "link",
                    action: { Task { await viewModel.toggleConnection(using: apiService) } }
                )

                controlButton(
                    title: "Get Job File",
                    systemImage: "arrow.down.doc",
                    action: { Task { await viewModel.downloadCurrentJob() } }
                )
                .disabled(printer.status != .printing && printer.status != .paused)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .disabled(viewModel.isPerformingAction)
    }

    private func statisticsSection(_ stats: PrinterStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statTile(value: "\(stats.totalJobs)", label: "Jobs")
                statTile(value: "\(stats.completedJobs)", label: "Completed")
                statTile(value: "\(stats.failedJobs)", label: "Failed")
                statTile(value: String(format: "%.0f%%", stats.successRate), label: "Success")
                statTile(value: String(format: "%.1fh", stats.totalPrintTimeHours), label: "Print Time")
                statTile(value: String(format: "%.2fkg", stats.totalMaterialKg), label: "Material")
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recentJobsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Jobs")
                .font(.headline)

            ForEach(viewModel.recentJobs) { job in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.fileName)
                            .font(.subheadline)
                            .lineLimit(1)

                        if let minutes = job.printTimeMinutes {
                            Text(formatPrintTime(minutes))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text(job.status.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(jobStatusColor(job.status).opacity(0.15))
                        .foregroundStyle(jobStatusColor(job.status))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 4)

                if job.id != viewModel.recentJobs.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatPrintTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    private func jobStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed": return .green
        case "failed", "cancelled": return .red
        case "printing", "running": return .blue
        default: return .secondary
        }
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
            .environmentObject(WebSocketService())
    }
}
