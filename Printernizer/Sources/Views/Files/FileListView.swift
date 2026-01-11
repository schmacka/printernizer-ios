import SwiftUI

struct FileListView: View {
    @StateObject private var viewModel = FileListViewModel()
    @State private var searchText = ""
    @State private var selectedFile: FileResponse?
    @State private var showDeleteConfirmation = false
    @State private var fileToDelete: FileResponse?

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.files.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.files.isEmpty {
                    ContentUnavailableView(
                        "No Files",
                        systemImage: "doc.text",
                        description: Text("Files from your printers will appear here.")
                    )
                } else {
                    fileGrid
                }
            }
            .navigationTitle("Files")
            .searchable(text: $searchText, prompt: "Search files")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await viewModel.searchFiles(query: newValue.isEmpty ? nil : newValue)
                }
            }
            .refreshable {
                await viewModel.loadFiles()
            }
            .task {
                await viewModel.loadFiles()
            }
            .sheet(item: $selectedFile) { file in
                NavigationStack {
                    FileDetailView(file: file) {
                        fileToDelete = file
                        showDeleteConfirmation = true
                    }
                }
            }
            .confirmationDialog("Delete File?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let file = fileToDelete {
                        Task {
                            await viewModel.deleteFile(file)
                            selectedFile = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this file?")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    private var fileGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.files) { file in
                    FileCardView(file: file)
                        .onTapGesture {
                            selectedFile = file
                        }
                }

                if viewModel.hasMorePages {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .onAppear {
                            Task {
                                await viewModel.loadMoreFiles()
                            }
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - File Card View

struct FileCardView: View {
    let file: FileResponse

    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = true

    private let fileService = FileService()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail or placeholder
            ZStack {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoadingThumbnail && file.hasThumbnail {
                    ProgressView()
                } else {
                    Image(systemName: file.sourceIcon)
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.filename)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack {
                    Text(file.formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            if file.hasThumbnail {
                await loadThumbnail()
            } else {
                isLoadingThumbnail = false
            }
        }
    }

    private var statusColor: Color {
        switch file.status.lowercased() {
        case "ready", "synced":
            return .green
        case "downloading", "processing":
            return .blue
        case "pending":
            return .orange
        case "error", "failed":
            return .red
        default:
            return .gray
        }
    }

    private func loadThumbnail() async {
        isLoadingThumbnail = true
        defer { isLoadingThumbnail = false }

        do {
            let image = try await fileService.getThumbnail(fileId: file.id)
            thumbnailImage = image
        } catch {
            // Failed to load thumbnail
        }
    }
}

// MARK: - View Model

@MainActor
final class FileListViewModel: ObservableObject {
    @Published var files: [FileResponse] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let fileService = FileService()
    private var currentPage = 1
    private var totalPages = 1
    private var currentSearch: String?

    var hasMorePages: Bool {
        currentPage < totalPages
    }

    func loadFiles() async {
        isLoading = true
        currentPage = 1
        currentSearch = nil

        do {
            let response = try await fileService.listFiles(page: 1)
            files = response.files
            totalPages = response.pagination.totalPages
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func searchFiles(query: String?) async {
        isLoading = true
        currentPage = 1
        currentSearch = query

        do {
            let response = try await fileService.listFiles(search: query, page: 1)
            files = response.files
            totalPages = response.pagination.totalPages
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func loadMoreFiles() async {
        guard !isLoading, hasMorePages else { return }

        isLoading = true
        currentPage += 1

        do {
            let response = try await fileService.listFiles(search: currentSearch, page: currentPage)
            files.append(contentsOf: response.files)
            totalPages = response.pagination.totalPages
        } catch {
            currentPage -= 1
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func deleteFile(_ file: FileResponse) async {
        do {
            try await fileService.deleteFile(id: file.id)
            files.removeAll { $0.id == file.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    FileListView()
}
