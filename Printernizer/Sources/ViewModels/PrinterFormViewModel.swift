import Foundation

@MainActor
final class PrinterFormViewModel: ObservableObject {
    @Published var name = ""
    @Published var printerType: PrinterType = .bambuLab
    @Published var ipAddress = ""
    @Published var accessCode = ""
    @Published var serialNumber = ""
    @Published var apiKey = ""
    @Published var webcamUrl = ""
    @Published var location = ""
    @Published var descriptionText = ""
    @Published var isEnabled = true

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isTesting = false
    @Published var testResult: ConnectionTestResult?
    @Published var showError = false
    @Published var errorMessage = ""

    private let printerService = PrinterService()

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !ipAddress.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Prefills the form from a network discovery result.
    func prefill(from discovered: DiscoveredPrinter) {
        name = discovered.name ?? discovered.model ?? ""
        ipAddress = discovered.ip ?? ""
        serialNumber = discovered.serial ?? ""
        if let type = discovered.printerType {
            printerType = type
        }
    }

    /// Loads the existing configuration when editing.
    func load(printerId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let printer = try await printerService.getPrinter(id: printerId)
            name = printer.name
            if let type = printer.printerType.flatMap(PrinterType.init(rawValue:)) {
                printerType = type
            }
            let config = printer.connectionConfig
            ipAddress = config?.ipAddress ?? printer.ipAddress ?? ""
            accessCode = config?.accessCode ?? ""
            serialNumber = config?.serialNumber ?? ""
            apiKey = config?.apiKey ?? ""
            webcamUrl = config?.webcamUrl ?? ""
            location = printer.location ?? ""
            descriptionText = printer.description ?? ""
            isEnabled = printer.isEnabled ?? true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func testConnection() async {
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        do {
            testResult = try await printerService.testConnection(
                type: printerType,
                config: connectionConfig
            )
        } catch {
            testResult = ConnectionTestResult(
                success: false,
                message: error.localizedDescription,
                responseTimeMs: nil
            )
        }
    }

    /// Creates or updates the printer. Returns true on success so the
    /// presenting view can dismiss.
    func save(editingPrinterId: String?) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            if let printerId = editingPrinterId {
                let update = PrinterUpdateRequest(
                    name: name.trimmingCharacters(in: .whitespaces),
                    printerType: printerType,
                    connectionConfig: connectionConfig,
                    location: location.isEmpty ? nil : location,
                    description: descriptionText.isEmpty ? nil : descriptionText,
                    isEnabled: isEnabled
                )
                _ = try await printerService.updatePrinter(id: printerId, update: update)
            } else {
                let create = PrinterCreateRequest(
                    name: name.trimmingCharacters(in: .whitespaces),
                    printerType: printerType,
                    connectionConfig: connectionConfig,
                    location: location.isEmpty ? nil : location,
                    description: descriptionText.isEmpty ? nil : descriptionText
                )
                _ = try await printerService.createPrinter(create)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    private var connectionConfig: PrinterConnectionConfig {
        var config = PrinterConnectionConfig(
            ipAddress: ipAddress.trimmingCharacters(in: .whitespaces)
        )
        switch printerType {
        case .bambuLab:
            config.accessCode = accessCode.isEmpty ? nil : accessCode
            config.serialNumber = serialNumber.isEmpty ? nil : serialNumber
        case .prusaCore, .octoprint:
            config.apiKey = apiKey.isEmpty ? nil : apiKey
        }
        if !webcamUrl.trimmingCharacters(in: .whitespaces).isEmpty {
            config.webcamUrl = webcamUrl.trimmingCharacters(in: .whitespaces)
        }
        return config
    }
}
