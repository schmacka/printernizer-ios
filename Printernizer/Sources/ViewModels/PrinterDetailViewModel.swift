import Foundation

@MainActor
final class PrinterDetailViewModel: ObservableObject {
    @Published var currentJob: PrintJob?
    @Published var hotendTemp: Double = 0
    @Published var hotendTarget: Double = 0
    @Published var bedTemp: Double = 0
    @Published var bedTarget: Double = 0
    @Published var statistics: PrinterStatistics?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private(set) var printer: Printer?

    func loadDetails(for printer: Printer, using apiService: APIService) async {
        self.printer = printer
        isLoading = true
        defer { isLoading = false }

        do {
            let details = try await apiService.fetchPrinterDetails(printerId: printer.id)
            currentJob = details.currentJob
            hotendTemp = details.hotendTemp
            hotendTarget = details.hotendTarget
            bedTemp = details.bedTemp
            bedTarget = details.bedTarget
            statistics = details.statistics
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func pausePrint(using apiService: APIService) async {
        guard let printer else { return }

        do {
            try await apiService.pausePrint(printerId: printer.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func resumePrint(using apiService: APIService) async {
        guard let printer else { return }

        do {
            try await apiService.resumePrint(printerId: printer.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func stopPrint(using apiService: APIService) async {
        guard let printer else { return }

        do {
            try await apiService.stopPrint(printerId: printer.id)
            currentJob = nil
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - WebSocket Update Handling

    func handlePrinterStatusUpdate(_ data: PrinterStatusData) {
        if let progress = data.progress, let job = currentJob {
            currentJob = PrintJob(
                id: job.id,
                fileName: data.currentJob ?? job.fileName,
                progress: progress / 100.0,
                elapsedSeconds: job.elapsedSeconds,
                estimatedTotalSeconds: job.estimatedTotalSeconds,
                currentLayer: job.currentLayer,
                totalLayers: job.totalLayers,
                filamentUsedMm: job.filamentUsedMm
            )
        }

        if let bedTemp = data.temperatureBed {
            self.bedTemp = bedTemp
        }
        if let nozzleTemp = data.temperatureNozzle {
            self.hotendTemp = nozzleTemp
        }
    }
}
