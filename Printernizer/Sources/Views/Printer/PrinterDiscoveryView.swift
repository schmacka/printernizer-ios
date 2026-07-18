import SwiftUI

/// Scans the local network for printers and lets the user add a
/// discovered printer via a prefilled form.
struct PrinterDiscoveryView: View {
    var onAdded: (() -> Void)?

    @StateObject private var viewModel = PrinterDiscoveryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPrinter: DiscoveredPrinter?

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.interfaces.isEmpty {
                    Section("Network Interface") {
                        Picker("Interface", selection: $viewModel.selectedInterface) {
                            Text("Automatic").tag(String?.none)
                            ForEach(viewModel.interfaces) { interface in
                                Text(interfaceLabel(interface))
                                    .tag(String?.some(interface.name))
                            }
                        }
                    }
                }

                Section {
                    if viewModel.isScanning {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Scanning network… this can take up to 30 seconds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.hasScanned && viewModel.discovered.isEmpty {
                        ContentUnavailableView(
                            "No Printers Found",
                            systemImage: "printer",
                            description: Text("Make sure your printers are powered on and on the same network.")
                        )
                    }

                    ForEach(viewModel.discovered) { printer in
                        Button {
                            guard printer.alreadyAdded != true else { return }
                            selectedPrinter = printer
                        } label: {
                            discoveredRow(printer)
                        }
                        .buttonStyle(.plain)
                        .disabled(printer.alreadyAdded == true)
                    }
                } header: {
                    if viewModel.hasScanned && !viewModel.discovered.isEmpty {
                        Text("Discovered Printers")
                    }
                }

                if !viewModel.scanErrors.isEmpty {
                    Section("Scan Warnings") {
                        ForEach(viewModel.scanErrors, id: \.self) { error in
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Discover Printers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel.scan() }
                    } label: {
                        if viewModel.isScanning {
                            ProgressView()
                        } else {
                            Text(viewModel.hasScanned ? "Rescan" : "Scan")
                        }
                    }
                    .disabled(viewModel.isScanning)
                }
            }
            .task {
                await viewModel.loadInterfaces()
                await viewModel.scan()
            }
            .sheet(item: $selectedPrinter) { printer in
                PrinterFormView(discovered: printer) {
                    onAdded?()
                    dismiss()
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    private func interfaceLabel(_ interface: NetworkInterface) -> String {
        if let ip = interface.ip {
            return "\(interface.name) (\(ip))"
        }
        return interface.name
    }

    private func discoveredRow(_ printer: DiscoveredPrinter) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(printer.name ?? printer.model ?? "Unknown Printer")
                    .font(.headline)

                HStack(spacing: 8) {
                    if let ip = printer.ip {
                        Text(ip)
                    }
                    if let type = printer.printerType {
                        Text(type.displayName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if printer.alreadyAdded == true {
                Text("Added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
    }
}

@MainActor
final class PrinterDiscoveryViewModel: ObservableObject {
    @Published var interfaces: [NetworkInterface] = []
    @Published var selectedInterface: String?
    @Published var discovered: [DiscoveredPrinter] = []
    @Published var scanErrors: [String] = []
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let printerService = PrinterService()

    func loadInterfaces() async {
        do {
            let response = try await printerService.networkInterfaces()
            interfaces = response.interfaces
        } catch {
            // Interface selection is optional; discovery falls back to
            // auto-detection when the endpoint is unavailable.
        }
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        defer {
            isScanning = false
            hasScanned = true
        }

        do {
            let result = try await printerService.discoverPrinters(interface: selectedInterface)
            discovered = result.discovered
            scanErrors = result.errors ?? []
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

extension DiscoveredPrinter: Equatable {
    static func == (lhs: DiscoveredPrinter, rhs: DiscoveredPrinter) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    PrinterDiscoveryView()
}
