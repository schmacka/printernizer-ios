import SwiftUI

/// Jobs tab root: a segmented control switches between print jobs
/// and customer orders (business features).
struct JobListView: View {
    enum Section: String, CaseIterable, Identifiable {
        case jobs = "Jobs"
        case orders = "Orders"

        var id: String { rawValue }
    }

    @StateObject private var viewModel = JobListViewModel()
    @State private var section: Section = .jobs
    @State private var selectedFilter: JobFilter = .all
    @State private var businessFilter: Bool?
    @State private var selectedJob: JobResponse?
    @State private var showNewJob = false
    @State private var exportedFile: URL?
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            Group {
                switch section {
                case .jobs:
                    jobsContent
                case .orders:
                    OrderListView()
                }
            }
            .navigationTitle(section == .jobs ? "Jobs" : "Orders")
            .safeAreaInset(edge: .top) {
                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
        }
    }

    @ViewBuilder
    private var jobsContent: some View {
        Group {
            if viewModel.isLoading && viewModel.jobs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.jobs.isEmpty {
                ContentUnavailableView {
                    Label("No Print Jobs", systemImage: "doc.text")
                } description: {
                    Text("Print jobs will appear here when you start printing.")
                } actions: {
                    Button("New Job") { showNewJob = true }
                }
            } else {
                jobList
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewJob = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $selectedFilter) {
                        ForEach(JobFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }

                    Picker("Type", selection: $businessFilter) {
                        Text("All Types").tag(Bool?.none)
                        Text("Business").tag(Bool?.some(true))
                        Text("Private").tag(Bool?.some(false))
                    }

                    Divider()

                    Button {
                        Task { await exportJobs() }
                    } label: {
                        Label("Export as CSV", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                .disabled(isExporting)
            }
        }
        .onChange(of: selectedFilter) { _, _ in
            Task { await reload() }
        }
        .onChange(of: businessFilter) { _, _ in
            Task { await reload() }
        }
        .refreshable {
            await reload()
        }
        .task {
            guard APIConfiguration.isConfigured else { return }
            await reload()
        }
        .sheet(item: $selectedJob) { job in
            NavigationStack {
                JobDetailView(job: job)
            }
        }
        .sheet(isPresented: $showNewJob) {
            JobFormView {
                Task { await reload() }
            }
        }
        .sheet(item: Binding(
            get: { exportedFile.map(ExportedJobFile.init) },
            set: { if $0 == nil { exportedFile = nil } }
        )) { file in
            ShareSheetView(url: file.url)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private struct ExportedJobFile: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private func reload() async {
        await viewModel.loadJobs(status: selectedFilter.apiValue, isBusiness: businessFilter)
    }

    private func exportJobs() async {
        isExporting = true
        defer { isExporting = false }
        exportedFile = await viewModel.exportJobs(
            status: selectedFilter.apiValue,
            isBusiness: businessFilter
        )
    }

    private var jobList: some View {
        List {
            ForEach(viewModel.jobs) { job in
                JobRowView(job: job)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedJob = job
                    }
            }

            if viewModel.hasMorePages {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        Task {
                            await viewModel.loadMoreJobs(
                                status: selectedFilter.apiValue,
                                isBusiness: businessFilter
                            )
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Job Row View

struct JobRowView: View {
    let job: JobResponse

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(job.jobName)
                        .font(.headline)
                        .lineLimit(1)

                    if job.isBusiness {
                        Text("Business")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if let filename = job.filename {
                        Text(filename)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let duration = job.formattedDuration {
                        Text(duration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let date = job.formattedDate {
                    Text(date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Progress or status
            if job.status.lowercased() == "running" || job.status.lowercased() == "printing" {
                if let progress = job.progress ?? job.progressPercent {
                    Text("\(Int(progress))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
            } else {
                Text(job.status.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch job.status.lowercased() {
        case "completed":
            return .green
        case "running", "printing":
            return .blue
        case "pending", "queued":
            return .orange
        case "failed", "cancelled":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Job Filter

enum JobFilter: String, CaseIterable {
    case all
    case running
    case completed
    case failed

    var displayName: String {
        switch self {
        case .all: return "All Jobs"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    var apiValue: String? {
        switch self {
        case .all: return nil
        case .running: return "running"
        case .completed: return "completed"
        case .failed: return "failed"
        }
    }
}

// MARK: - View Model

@MainActor
final class JobListViewModel: ObservableObject {
    @Published var jobs: [JobResponse] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let jobService = JobService()
    private var currentPage = 1
    private var totalPages = 1

    var hasMorePages: Bool {
        currentPage < totalPages
    }

    func loadJobs(status: String? = nil, isBusiness: Bool? = nil) async {
        isLoading = true
        currentPage = 1

        do {
            let response = try await jobService.listJobs(status: status, isBusiness: isBusiness, page: 1)
            jobs = response.jobs
            totalPages = response.pagination.totalPages
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func loadMoreJobs(status: String? = nil, isBusiness: Bool? = nil) async {
        guard !isLoading, hasMorePages else { return }

        isLoading = true
        currentPage += 1

        do {
            let response = try await jobService.listJobs(status: status, isBusiness: isBusiness, page: currentPage)
            jobs.append(contentsOf: response.jobs)
            totalPages = response.pagination.totalPages
        } catch {
            currentPage -= 1
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func exportJobs(status: String?, isBusiness: Bool?) async -> URL? {
        do {
            return try await jobService.exportJobs(status: status, isBusiness: isBusiness)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }
}

#Preview {
    JobListView()
        .environmentObject(APIService())
}
