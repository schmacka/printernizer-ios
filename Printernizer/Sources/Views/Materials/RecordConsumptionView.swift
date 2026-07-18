import SwiftUI

/// Records filament consumption for a job against a material spool.
/// The backend links the consumption to a job, so the user picks one
/// of the recent jobs; the printer is derived from the job.
struct RecordConsumptionView: View {
    let material: MaterialResponse
    var onRecorded: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RecordConsumptionViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Material") {
                    LabeledContent("Spool", value: "\(material.brand) \(material.color)")
                    LabeledContent("Remaining", value: material.formattedWeight)
                }

                Section("Job") {
                    if viewModel.jobs.isEmpty && !viewModel.isLoadingJobs {
                        Text("No jobs found")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Job", selection: $viewModel.selectedJobId) {
                            Text("Select a job").tag(String?.none)
                            ForEach(viewModel.jobs) { job in
                                Text(job.jobName).tag(String?.some(job.id))
                            }
                        }
                    }
                }

                Section("Consumption") {
                    LabeledContent("Weight (g)") {
                        TextField("0", value: $viewModel.weightGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Record Consumption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.record(materialId: material.id) {
                                onRecorded?()
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isSaving || !viewModel.isValid)
                }
            }
            .task {
                await viewModel.loadJobs()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

@MainActor
final class RecordConsumptionViewModel: ObservableObject {
    @Published var jobs: [JobResponse] = []
    @Published var selectedJobId: String?
    @Published var weightGrams: Double?
    @Published var isLoadingJobs = false
    @Published var isSaving = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let jobService = JobService()
    private let materialService = MaterialService()

    var isValid: Bool {
        selectedJobId != nil && (weightGrams ?? 0) > 0
    }

    func loadJobs() async {
        isLoadingJobs = true
        defer { isLoadingJobs = false }

        do {
            jobs = try await jobService.listJobs(limit: 25).jobs
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func record(materialId: String) async -> Bool {
        guard let jobId = selectedJobId,
              let job = jobs.first(where: { $0.id == jobId }),
              let grams = weightGrams, grams > 0 else { return false }

        isSaving = true
        defer { isSaving = false }

        do {
            try await materialService.recordConsumption(ConsumptionRequest(
                jobId: job.id,
                materialId: materialId,
                weightGrams: grams,
                printerId: job.printerId,
                fileName: job.filename,
                printTimeHours: nil
            ))
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
}

#Preview {
    RecordConsumptionView(material: MaterialResponse(
        id: "1",
        materialType: "PLA",
        brand: "Prusament",
        color: "Galaxy Black",
        diameter: 1.75,
        weight: 1.0,
        remainingWeight: 0.75,
        remainingPercentage: 75,
        costPerKg: 25.99,
        remainingValue: 19.49,
        vendor: "Prusa Research",
        batchNumber: nil,
        notes: nil,
        printerId: nil,
        colorHex: nil,
        location: nil,
        isActive: true,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z"
    ))
}
