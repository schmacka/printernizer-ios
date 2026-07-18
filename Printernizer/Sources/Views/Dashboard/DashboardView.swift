import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject private var apiService: APIService
    @EnvironmentObject private var webSocketService: WebSocketService
    @AppStorage("refreshInterval") private var refreshInterval = 5.0

    var body: some View {
        NavigationStack {
            Group {
                if !APIConfiguration.isConfigured {
                    ContentUnavailableView(
                        "No Server Configured",
                        systemImage: "network.slash",
                        description: Text("Set the server URL in Settings (More tab)")
                    )
                } else {
                    dashboardContent
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Period", selection: $viewModel.period) {
                        ForEach(AnalyticsPeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.period) { _, _ in
                        Task { await viewModel.loadOverview() }
                    }
                }
            }
            .refreshable {
                await viewModel.load(using: apiService)
            }
            .task {
                guard APIConfiguration.isConfigured else { return }
                if !webSocketService.isConnected {
                    webSocketService.connect()
                }
                await viewModel.load(using: apiService)
                subscribeToAllPrinters()

                // Polling fallback mirrors PrinterListView: refresh only
                // while the WebSocket is down.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(max(refreshInterval, 1)))
                    guard !Task.isCancelled else { break }
                    if !webSocketService.isConnected {
                        await viewModel.load(using: apiService)
                        subscribeToAllPrinters()
                    }
                }
            }
            .onReceive(viewModel.$printers) { _ in
                subscribeToAllPrinters()
            }
            .onReceive(webSocketService.$lastMessage) { message in
                switch message {
                case .printerStatus(let printerId, let data):
                    viewModel.handlePrinterStatus(printerId: printerId, data: data)
                case .jobUpdate:
                    viewModel.handleJobUpdate()
                default:
                    break
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
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

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statsGrid

                if !viewModel.printers.isEmpty {
                    printersSection
                }

                if !viewModel.recentJobs.isEmpty {
                    recentJobsSection
                }
            }
            .padding()
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Printers Online",
                value: printersOnlineText,
                icon: "printer.fill",
                color: .green
            )
            StatCard(
                title: "Jobs (\(viewModel.period.displayName))",
                value: "\(viewModel.overview?.jobs?.totalJobs ?? 0)",
                icon: "doc.text.fill",
                color: .blue
            )
            StatCard(
                title: "Completed",
                value: "\(viewModel.overview?.jobs?.completedJobs ?? 0)",
                icon: "checkmark.circle.fill",
                color: .teal
            )
            StatCard(
                title: "Files",
                value: "\(viewModel.overview?.files?.totalFiles ?? 0)",
                icon: "folder.fill",
                color: .orange
            )
        }
    }

    private var printersOnlineText: String {
        if let printers = viewModel.overview?.printers,
           let total = printers.totalPrinters {
            return "\(printers.onlinePrinters ?? 0)/\(total)"
        }
        let online = viewModel.printers.filter { $0.status != .offline }.count
        return "\(online)/\(viewModel.printers.count)"
    }

    private var printersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Printers")
                .font(.headline)

            ForEach(viewModel.printers) { printer in
                NavigationLink(destination: PrinterDetailView(printer: printer)) {
                    PrinterCardView(printer: printer)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentJobsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Jobs")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(viewModel.recentJobs) { job in
                    JobRowView(job: job)
                        .padding(.vertical, 8)

                    if job.id != viewModel.recentJobs.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(APIService())
        .environmentObject(WebSocketService())
}
