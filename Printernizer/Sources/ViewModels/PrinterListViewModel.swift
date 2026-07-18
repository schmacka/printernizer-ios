import Foundation

@MainActor
final class PrinterListViewModel: ObservableObject {
    @Published var printers: [Printer] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let printerService = PrinterService()

    func loadPrinters(using apiService: APIService) async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            printers = try await apiService.fetchPrinters()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func refresh(using apiService: APIService) async {
        do {
            printers = try await apiService.fetchPrinters()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deletePrinter(_ printer: Printer) async {
        do {
            try await printerService.deletePrinter(id: printer.id)
            printers.removeAll { $0.id == printer.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// Applies a live printer_status event to the matching list row.
    func handlePrinterStatus(printerId: String, data: PrinterStatusData) {
        guard let index = printers.firstIndex(where: { $0.id == printerId }) else { return }

        let existing = printers[index]
        let status = data.status.map(PrinterStatus.init(apiValue:)) ?? existing.status
        let progress = data.progress.map { $0 / 100.0 } ?? existing.currentJobProgress

        printers[index] = Printer(
            id: existing.id,
            name: existing.name,
            status: status,
            model: existing.model,
            currentJobProgress: status == .printing || status == .paused ? progress : nil
        )
    }
}
