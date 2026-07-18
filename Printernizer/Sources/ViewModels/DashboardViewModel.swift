import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var overview: AnalyticsOverview?
    @Published var printers: [Printer] = []
    @Published var recentJobs: [JobResponse] = []
    @Published var period: AnalyticsPeriod = .day
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let analyticsService = AnalyticsService()
    private let jobService = JobService()

    func load(using apiService: APIService) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Each block loads independently so one failing subsystem
        // doesn't blank the whole dashboard.
        async let overviewTask: () = loadOverview()
        async let printersTask: () = loadPrinters(using: apiService)
        async let jobsTask: () = loadRecentJobs()
        _ = await (overviewTask, printersTask, jobsTask)
    }

    func loadOverview() async {
        do {
            overview = try await analyticsService.overview(period: period)
        } catch {
            reportError(error)
        }
    }

    func loadPrinters(using apiService: APIService) async {
        do {
            printers = try await apiService.fetchPrinters()
        } catch {
            reportError(error)
        }
    }

    func loadRecentJobs() async {
        do {
            recentJobs = Array(try await jobService.listJobs(limit: 5).jobs.prefix(5))
        } catch {
            // Recent jobs are non-critical; leave the section empty.
        }
    }

    /// Applies a live printer_status event to the matching printer card.
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

    /// Refreshes recent jobs when the backend reports job changes.
    func handleJobUpdate() {
        Task { await loadRecentJobs() }
    }

    private func reportError(_ error: Error) {
        // Only surface the first error per load; subsequent ones are
        // usually the same connectivity problem.
        guard !showError else { return }
        errorMessage = error.localizedDescription
        showError = true
    }
}
