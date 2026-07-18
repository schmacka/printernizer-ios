import SwiftUI

/// Slices a library model server-side: pick slicer and profile,
/// optionally send to a printer (slice & print), then watch progress.
struct SliceSheetView: View {
    let file: LibraryFile
    var onSliced: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var apiService: APIService
    @StateObject private var viewModel = SliceSheetViewModel()

    var body: some View {
        NavigationStack {
            Form {
                if let job = viewModel.activeJob {
                    jobSection(job)
                } else {
                    configSection
                }
            }
            .navigationTitle("Slice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.activeJob?.isFinished == true ? "Done" : "Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.load(using: apiService)
            }
            .onDisappear {
                viewModel.stopPolling()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    @ViewBuilder
    private var configSection: some View {
        Section("Model") {
            LabeledContent("File", value: file.displayTitle)
        }

        Section("Slicer") {
            if viewModel.slicers.isEmpty && !viewModel.isLoading {
                Text("No slicers configured on the server.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Slicer", selection: $viewModel.selectedSlicerId) {
                    Text("Select").tag(String?.none)
                    ForEach(viewModel.slicers) { slicer in
                        Text(slicer.name).tag(String?.some(slicer.id))
                    }
                }
                .onChange(of: viewModel.selectedSlicerId) { _, _ in
                    Task { await viewModel.loadProfiles() }
                }

                Picker("Profile", selection: $viewModel.selectedProfileId) {
                    Text("Select").tag(String?.none)
                    ForEach(viewModel.profiles) { profile in
                        Text(profile.profileName).tag(String?.some(profile.id))
                    }
                }
                .disabled(viewModel.profiles.isEmpty)
            }
        }

        Section("Print") {
            Picker("Printer (optional)", selection: $viewModel.selectedPrinterId) {
                Text("Slice only").tag(String?.none)
                ForEach(viewModel.printers) { printer in
                    Text(printer.name).tag(String?.some(printer.id))
                }
            }

            if viewModel.selectedPrinterId != nil {
                Toggle("Start print automatically", isOn: $viewModel.autoStart)
            }
        }

        Section {
            Button {
                Task { await viewModel.startSlicing(checksum: file.checksum) }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(viewModel.selectedPrinterId == nil ? "Slice" : "Slice & Print")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(viewModel.isSubmitting || viewModel.selectedSlicerId == nil || viewModel.selectedProfileId == nil)
        }
    }

    @ViewBuilder
    private func jobSection(_ job: SlicingJobResponse) -> some View {
        Section("Slicing Job") {
            if job.isFinished {
                Label(
                    job.isSuccessful ? "Slicing completed" : "Slicing \(job.status)",
                    systemImage: job.isSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(job.isSuccessful ? .green : .red)

                if let error = job.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if job.isSuccessful {
                    if let seconds = job.estimatedPrintTime, seconds > 0 {
                        LabeledContent("Est. Print Time", value: Formatters.duration(minutes: seconds / 60))
                    }
                    if let filament = job.filamentUsed, filament > 0 {
                        LabeledContent("Filament", value: Formatters.weightGrams(filament))
                    }
                }
            } else {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Slicing… \(job.progress ?? 0)%")
                }
            }
        }

        if job.isFinished && job.isSuccessful {
            Section {
                Button("Done") {
                    onSliced?()
                    dismiss()
                }
            }
        }
    }
}

@MainActor
final class SliceSheetViewModel: ObservableObject {
    @Published var slicers: [SlicerConfig] = []
    @Published var profiles: [SlicerProfileResponse] = []
    @Published var printers: [Printer] = []
    @Published var selectedSlicerId: String?
    @Published var selectedProfileId: String?
    @Published var selectedPrinterId: String?
    @Published var autoStart = false
    @Published var activeJob: SlicingJobResponse?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let slicingService = SlicingService()
    private var pollTask: Task<Void, Never>?

    func load(using apiService: APIService) async {
        isLoading = true
        defer { isLoading = false }

        do {
            slicers = try await slicingService.listSlicers()
            if slicers.count == 1 {
                selectedSlicerId = slicers.first?.id
                await loadProfiles()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        printers = (try? await apiService.fetchPrinters()) ?? []
    }

    func loadProfiles() async {
        profiles = []
        selectedProfileId = nil
        guard let slicerId = selectedSlicerId else { return }

        do {
            profiles = try await slicingService.listProfiles(slicerId: slicerId)
            if profiles.count == 1 {
                selectedProfileId = profiles.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func startSlicing(checksum: String) async {
        guard let slicerId = selectedSlicerId, let profileId = selectedProfileId else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let job = try await slicingService.slice(
                checksum: checksum,
                slicerId: slicerId,
                profileId: profileId,
                printerId: selectedPrinterId,
                autoStart: autoStart
            )
            activeJob = job
            startPolling(jobId: job.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func startPolling(jobId: String) {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }

                if let job = try? await self.slicingService.getJob(id: jobId) {
                    self.activeJob = job
                    if job.isFinished {
                        return
                    }
                }
            }
        }
    }
}

#Preview {
    SliceSheetView(file: LibraryFile(
        checksum: "abc123",
        filename: "benchy.stl",
        displayName: "3D Benchy",
        fileSize: 1_500_000,
        fileType: "stl",
        status: "ready",
        role: "model",
        parentChecksum: nil,
        analysisError: nil,
        hasThumbnail: false,
        addedToLibrary: nil,
        lastModified: nil,
        modelWidth: 60,
        modelDepth: 31,
        modelHeight: 48,
        totalFilamentWeight: 15,
        materialCost: 0.45,
        totalCost: 0.6,
        slicerName: nil,
        profileName: nil,
        sources: nil
    ))
    .environmentObject(APIService())
}
