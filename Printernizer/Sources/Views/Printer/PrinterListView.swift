import SwiftUI

struct PrinterListView: View {
    @StateObject private var viewModel = PrinterListViewModel()
    @EnvironmentObject private var apiService: APIService
    @EnvironmentObject private var webSocketService: WebSocketService
    @AppStorage("refreshInterval") private var refreshInterval = 5.0

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.printers.isEmpty {
                    ProgressView("Loading printers...")
                } else if viewModel.printers.isEmpty {
                    ContentUnavailableView(
                        "No Printers",
                        systemImage: "printer.fill",
                        description: Text("Add a printer to get started")
                    )
                } else {
                    printerList
                }
            }
            .navigationTitle("Printers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refresh(using: apiService)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh(using: apiService)
            }
            .task {
                if !apiService.baseURL.isEmpty, !webSocketService.isConnected {
                    webSocketService.connect()
                }
                await viewModel.loadPrinters(using: apiService)
                subscribeToAllPrinters()

                // Polling fallback keeps the list fresh even when the
                // WebSocket is down; live events arrive in between.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(max(refreshInterval, 1)))
                    guard !Task.isCancelled else { break }
                    if !webSocketService.isConnected {
                        await viewModel.refresh(using: apiService)
                        subscribeToAllPrinters()
                    }
                }
            }
            .onReceive(viewModel.$printers) { _ in
                subscribeToAllPrinters()
            }
            .onReceive(webSocketService.$lastMessage) { message in
                if case .printerStatus(let printerId, let data) = message {
                    viewModel.handlePrinterStatus(printerId: printerId, data: data)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    private func subscribeToAllPrinters() {
        for printer in viewModel.printers {
            webSocketService.subscribeToPrinter(printer.id)
        }
    }

    private var printerList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.printers) { printer in
                    NavigationLink(destination: PrinterDetailView(printer: printer)) {
                        PrinterCardView(printer: printer)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

#Preview {
    PrinterListView()
        .environmentObject(APIService())
        .environmentObject(WebSocketService())
}
