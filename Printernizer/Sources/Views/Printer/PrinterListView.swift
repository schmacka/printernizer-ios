import SwiftUI

struct PrinterListView: View {
    @StateObject private var viewModel = PrinterListViewModel()
    @EnvironmentObject private var apiService: APIService

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
                await viewModel.loadPrinters(using: apiService)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
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
}
