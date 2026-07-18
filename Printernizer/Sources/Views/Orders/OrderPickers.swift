import SwiftUI

/// Picks an existing job to link to an order.
struct LinkJobPickerView: View {
    let onPicked: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var jobs: [JobResponse] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && jobs.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if jobs.isEmpty {
                    ContentUnavailableView("No Jobs", systemImage: "doc.text")
                } else {
                    List(jobs) { job in
                        Button {
                            onPicked(job.id)
                            dismiss()
                        } label: {
                            JobRowView(job: job)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Link Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                isLoading = true
                defer { isLoading = false }
                jobs = (try? await JobService().listJobs(limit: 50).jobs) ?? []
            }
        }
    }
}

/// Picks a library file to attach to an order.
struct AttachLibraryFilePickerView: View {
    let onPicked: (LibraryFile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var files: [LibraryFile] = []
    @State private var searchText = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && files.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if files.isEmpty {
                    ContentUnavailableView("No Library Files", systemImage: "books.vertical")
                } else {
                    List(files) { file in
                        Button {
                            onPicked(file)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.filename)
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Attach File")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, _ in
                Task { await load() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await load()
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let search = searchText.count >= 2 ? searchText : nil
        files = (try? await LibraryService().listFiles(search: search, limit: 50).files) ?? []
    }
}
