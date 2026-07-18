import SwiftUI

/// Shared create/edit form for printer configuration. Pass a
/// `printerId` to edit an existing printer, or a `DiscoveredPrinter`
/// to prefill from a network scan result.
struct PrinterFormView: View {
    var printerId: String?
    var discovered: DiscoveredPrinter?
    var onSaved: (() -> Void)?

    @StateObject private var viewModel = PrinterFormViewModel()
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { printerId != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Printer") {
                    TextField("Name", text: $viewModel.name)

                    Picker("Type", selection: $viewModel.printerType) {
                        ForEach(PrinterType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    TextField("IP Address", text: $viewModel.ipAddress)
                        .keyboardType(.decimalPad)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section("Connection") {
                    switch viewModel.printerType {
                    case .bambuLab:
                        SecureField("Access Code", text: $viewModel.accessCode)
                        TextField("Serial Number", text: $viewModel.serialNumber)
                            .autocapitalization(.allCharacters)
                            .autocorrectionDisabled()
                    case .prusaCore, .octoprint:
                        SecureField("API Key", text: $viewModel.apiKey)
                    }

                    TextField("Webcam URL (optional)", text: $viewModel.webcamUrl)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    HStack {
                        Button {
                            Task { await viewModel.testConnection() }
                        } label: {
                            if viewModel.isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Test Connection")
                            }
                        }
                        .disabled(viewModel.isTesting || !viewModel.isValid)

                        Spacer()

                        if let result = viewModel.testResult {
                            Image(systemName: result.success == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.success == true ? .green : .red)
                        }
                    }

                    if let result = viewModel.testResult,
                       result.success != true,
                       let message = result.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Details") {
                    TextField("Location (optional)", text: $viewModel.location)
                    TextField("Description (optional)", text: $viewModel.descriptionText)

                    if isEditing {
                        Toggle("Active", isOn: $viewModel.isEnabled)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Printer" : "Add Printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save(editingPrinterId: printerId) {
                                onSaved?()
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
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .task {
                if let printerId {
                    await viewModel.load(printerId: printerId)
                } else if let discovered {
                    viewModel.prefill(from: discovered)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

#Preview {
    PrinterFormView()
}
