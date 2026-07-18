import SwiftUI

/// Edits the backend's application settings (mirrors the web app's
/// Settings page sections that make sense on mobile). Path-type
/// settings stay on the web/desktop side.
struct ServerSettingsView: View {
    @StateObject private var viewModel = ServerSettingsViewModel()

    var body: some View {
        Form {
            if viewModel.isLoading && !viewModel.hasLoaded {
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading server settings…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                generalSection
                jobsSection
                gcodeSection
                uploadsSection
                librarySection
                timelapseSection
            }
        }
        .navigationTitle("Server Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await viewModel.save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(viewModel.isSaving || !viewModel.hasLoaded)
            }
        }
        .task {
            await viewModel.load()
        }
        .alert("Server Settings", isPresented: $viewModel.showMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.message)
        }
    }

    private var generalSection: some View {
        Section("General") {
            Picker("Log Level", selection: $viewModel.logLevel) {
                ForEach(["DEBUG", "INFO", "WARNING", "ERROR"], id: \.self) { level in
                    Text(level.capitalized).tag(level)
                }
            }

            LabeledContent("Monitoring Interval (s)") {
                TextField("30", value: $viewModel.monitoringInterval, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Connection Timeout (s)") {
                TextField("10", value: $viewModel.connectionTimeout, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("VAT Rate (%)") {
                TextField("19", value: $viewModel.vatRate, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var jobsSection: some View {
        Section("Jobs") {
            Toggle("Auto-Create Jobs", isOn: $viewModel.jobCreationAutoCreate)
        }
    }

    private var gcodeSection: some View {
        Section("G-Code Processing") {
            Toggle("Optimize Print-Only Moves", isOn: $viewModel.gcodeOptimizePrintOnly)

            LabeledContent("Optimization Max Lines") {
                TextField("100000", value: $viewModel.gcodeOptimizationMaxLines, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Render Max Lines") {
                TextField("100000", value: $viewModel.gcodeRenderMaxLines, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var uploadsSection: some View {
        Section("Uploads") {
            Toggle("Enable Uploads", isOn: $viewModel.enableUpload)

            LabeledContent("Max Upload Size (MB)") {
                TextField("50", value: $viewModel.maxUploadSizeMb, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var librarySection: some View {
        Section("Library") {
            Toggle("Library Enabled", isOn: $viewModel.libraryEnabled)
            Toggle("Auto-Organize", isOn: $viewModel.libraryAutoOrganize)
            Toggle("Extract Metadata", isOn: $viewModel.libraryAutoExtractMetadata)
            Toggle("Deduplicate", isOn: $viewModel.libraryAutoDeduplicate)
            Toggle("Preserve Originals", isOn: $viewModel.libraryPreserveOriginals)
        }
    }

    private var timelapseSection: some View {
        Section("Timelapse") {
            Toggle("Timelapse Enabled", isOn: $viewModel.timelapseEnabled)

            LabeledContent("Cleanup Age (days)") {
                TextField("30", value: $viewModel.timelapseCleanupAgeDays, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }

            if let ffmpeg = viewModel.ffmpeg {
                LabeledContent("FFmpeg") {
                    Label(
                        ffmpeg.installed == true ? (ffmpeg.version ?? "Installed") : "Not installed",
                        systemImage: ffmpeg.installed == true ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(ffmpeg.installed == true ? .green : .red)
                    .font(.caption)
                }
            }
        }
    }
}

@MainActor
final class ServerSettingsViewModel: ObservableObject {
    @Published var logLevel = "INFO"
    @Published var monitoringInterval: Int?
    @Published var connectionTimeout: Int?
    @Published var vatRate: Double?
    @Published var jobCreationAutoCreate = false
    @Published var gcodeOptimizePrintOnly = false
    @Published var gcodeOptimizationMaxLines: Int?
    @Published var gcodeRenderMaxLines: Int?
    @Published var enableUpload = true
    @Published var maxUploadSizeMb: Int?
    @Published var libraryEnabled = true
    @Published var libraryAutoOrganize = false
    @Published var libraryAutoExtractMetadata = false
    @Published var libraryAutoDeduplicate = false
    @Published var libraryPreserveOriginals = false
    @Published var timelapseEnabled = false
    @Published var timelapseCleanupAgeDays: Int?
    @Published var ffmpeg: FfmpegCheckResult?

    @Published var hasLoaded = false
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var showMessage = false
    @Published var message = ""

    private let service = ServerSettingsService()

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let settings = try await service.getSettings()
            logLevel = settings.logLevel?.uppercased() ?? "INFO"
            monitoringInterval = settings.monitoringInterval
            connectionTimeout = settings.connectionTimeout
            vatRate = settings.vatRate
            jobCreationAutoCreate = settings.jobCreationAutoCreate ?? false
            gcodeOptimizePrintOnly = settings.gcodeOptimizePrintOnly ?? false
            gcodeOptimizationMaxLines = settings.gcodeOptimizationMaxLines
            gcodeRenderMaxLines = settings.gcodeRenderMaxLines
            enableUpload = settings.enableUpload ?? true
            maxUploadSizeMb = settings.maxUploadSizeMb
            libraryEnabled = settings.libraryEnabled ?? true
            libraryAutoOrganize = settings.libraryAutoOrganize ?? false
            libraryAutoExtractMetadata = settings.libraryAutoExtractMetadata ?? false
            libraryAutoDeduplicate = settings.libraryAutoDeduplicate ?? false
            libraryPreserveOriginals = settings.libraryPreserveOriginals ?? false
            timelapseEnabled = settings.timelapseEnabled ?? false
            timelapseCleanupAgeDays = settings.timelapseCleanupAgeDays
            hasLoaded = true
        } catch {
            message = error.localizedDescription
            showMessage = true
        }

        ffmpeg = try? await service.checkFfmpeg()
    }

    func save() async {
        isSaving = true
        defer { isSaving = false }

        let update = ServerSettingsUpdate(
            logLevel: logLevel,
            monitoringInterval: monitoringInterval,
            connectionTimeout: connectionTimeout,
            vatRate: vatRate,
            jobCreationAutoCreate: jobCreationAutoCreate,
            gcodeOptimizePrintOnly: gcodeOptimizePrintOnly,
            gcodeOptimizationMaxLines: gcodeOptimizationMaxLines,
            gcodeRenderMaxLines: gcodeRenderMaxLines,
            enableUpload: enableUpload,
            maxUploadSizeMb: maxUploadSizeMb,
            libraryEnabled: libraryEnabled,
            libraryAutoOrganize: libraryAutoOrganize,
            libraryAutoExtractMetadata: libraryAutoExtractMetadata,
            libraryAutoDeduplicate: libraryAutoDeduplicate,
            libraryPreserveOriginals: libraryPreserveOriginals,
            timelapseEnabled: timelapseEnabled,
            timelapseCleanupAgeDays: timelapseCleanupAgeDays
        )

        do {
            try await service.updateSettings(update)
            message = "Server settings saved."
        } catch {
            message = error.localizedDescription
        }
        showMessage = true
    }
}

#Preview {
    NavigationStack {
        ServerSettingsView()
    }
}
