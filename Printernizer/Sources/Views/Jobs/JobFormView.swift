import SwiftUI

/// Creates a print job, optionally flagged as a business job with a
/// customer. Costs are computed by the backend; the material cost
/// field is an optional manual override in EUR.
struct JobFormView: View {
    var onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var apiService: APIService
    @StateObject private var viewModel = JobFormViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Job") {
                    TextField("Job Name", text: $viewModel.jobName)

                    Picker("Printer", selection: $viewModel.printerId) {
                        Text("Select a printer").tag(String?.none)
                        ForEach(viewModel.printers) { printer in
                            Text(printer.name).tag(String?.some(printer.id))
                        }
                    }

                    TextField("Filename (optional)", text: $viewModel.filename)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section("Business") {
                    Toggle("Business Job", isOn: $viewModel.isBusiness)

                    if viewModel.isBusiness {
                        TextField("Customer Name", text: $viewModel.customerName)

                        LabeledContent("Material Cost (€)") {
                            TextField("0.00", value: $viewModel.materialCost, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle("New Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save() {
                                onSaved?()
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(viewModel.isSaving || !viewModel.isValid)
                }
            }
            .task {
                await viewModel.loadPrinters(using: apiService)
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
final class JobFormViewModel: ObservableObject {
    @Published var jobName = ""
    @Published var printerId: String?
    @Published var filename = ""
    @Published var isBusiness = false
    @Published var customerName = ""
    @Published var materialCost: Double?

    @Published var printers: [Printer] = []
    @Published var isSaving = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let jobService = JobService()

    var isValid: Bool {
        !jobName.trimmingCharacters(in: .whitespaces).isEmpty && printerId != nil
    }

    func loadPrinters(using apiService: APIService) async {
        printers = (try? await apiService.fetchPrinters()) ?? []
    }

    func save() async -> Bool {
        guard let printerId else { return false }
        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await jobService.createJob(JobCreateRequest(
                printerId: printerId,
                jobName: jobName.trimmingCharacters(in: .whitespaces),
                filename: filename.isEmpty ? nil : filename,
                fileId: nil,
                estimatedDuration: nil,
                materialCost: isBusiness ? materialCost : nil,
                isBusiness: isBusiness,
                customerName: isBusiness && !customerName.isEmpty ? customerName : nil
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
    JobFormView()
        .environmentObject(APIService())
}
