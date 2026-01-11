import Foundation

@MainActor
final class PrinterListViewModel: ObservableObject {
    @Published var printers: [Printer] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

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
}
