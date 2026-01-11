import SwiftUI

struct JobListView: View {
    @StateObject private var viewModel = JobListViewModel()
    @State private var selectedFilter: JobFilter = .all
    @State private var selectedJob: JobResponse?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.jobs.isEmpty {
                    ContentUnavailableView(
                        "No Print Jobs",
                        systemImage: "doc.text",
                        description: Text("Print jobs will appear here when you start printing.")
                    )
                } else {
                    jobList
                }
            }
            .navigationTitle("Jobs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(JobFilter.allCases, id: \.self) { filter in
                            Button {
                                selectedFilter = filter
                                Task {
                                    await viewModel.loadJobs(status: filter.apiValue)
                                }
                            } label: {
                                if selectedFilter == filter {
                                    Label(filter.displayName, systemImage: "checkmark")
                                } else {
                                    Text(filter.displayName)
                                }
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.loadJobs(status: selectedFilter.apiValue)
            }
            .task {
                await viewModel.loadJobs()
            }
            .sheet(item: $selectedJob) { job in
                NavigationStack {
                    JobDetailView(job: job)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
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
                            await viewModel.loadMoreJobs(status: selectedFilter.apiValue)
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
                Text(job.jobName)
                    .font(.headline)
                    .lineLimit(1)

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

    func loadJobs(status: String? = nil) async {
        isLoading = true
        currentPage = 1

        do {
            let response = try await jobService.listJobs(status: status, page: 1)
            jobs = response.jobs
            totalPages = response.pagination.totalPages
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func loadMoreJobs(status: String? = nil) async {
        guard !isLoading, hasMorePages else { return }

        isLoading = true
        currentPage += 1

        do {
            let response = try await jobService.listJobs(status: status, page: currentPage)
            jobs.append(contentsOf: response.jobs)
            totalPages = response.pagination.totalPages
        } catch {
            currentPage -= 1
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }
}

#Preview {
    JobListView()
}
