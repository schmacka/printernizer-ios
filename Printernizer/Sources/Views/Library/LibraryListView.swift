import SwiftUI

struct LibraryListView: View {
    @StateObject private var viewModel = LibraryListViewModel()
    @State private var searchText = ""
    @State private var selectedFile: LibraryFile?
    @State private var roleFilter: LibraryRoleFilter = .all

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.files.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredFiles.isEmpty {
                    ContentUnavailableView(
                        "No Library Files",
                        systemImage: "books.vertical",
                        description: Text("Models and print files from your printers, watch folders, and uploads will appear here.")
                    )
                } else {
                    fileGrid
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search library")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await viewModel.search(query: newValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(LibraryRoleFilter.allCases, id: \.self) { filter in
                            Button {
                                roleFilter = filter
                            } label: {
                                if roleFilter == filter {
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
                await viewModel.loadFiles()
            }
            .task {
                await viewModel.loadFiles()
            }
            .sheet(item: $selectedFile) { file in
                NavigationStack {
                    LibraryFileDetailView(file: file) {
                        Task {
                            await viewModel.deleteFile(file)
                            selectedFile = nil
                        }
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    private var filteredFiles: [LibraryFile] {
        switch roleFilter {
        case .all:
            return viewModel.files
        case .models:
            return viewModel.files.filter { $0.isModel }
        case .printFiles:
            return viewModel.files.filter { $0.isPrintFile }
        }
    }

    private var fileGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredFiles) { file in
                    LibraryFileCardView(file: file)
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

// MARK: - Role Filter

enum LibraryRoleFilter: CaseIterable {
    case all
    case models
    case printFiles

    var displayName: String {
        switch self {
        case .all: return "All Files"
        case .models: return "Models"
        case .printFiles: return "Print Files"
        }
    }
}

// MARK: - Library File Card

struct LibraryFileCardView: View {
    let file: LibraryFile

    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = true

    private let libraryService = LibraryService()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoadingThumbnail && file.hasThumbnail == true {
                    ProgressView()
                } else {
                    Image(systemName: file.roleIcon)
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(file.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack {
                    Text(file.formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if file.isPrintFile {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Circle()
                        .fill(file.statusColor)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            if file.hasThumbnail == true {
                await loadThumbnail()
            } else {
                isLoadingThumbnail = false
            }
        }
    }

    private func loadThumbnail() async {
        isLoadingThumbnail = true
        defer { isLoadingThumbnail = false }

        do {
            thumbnailImage = try await libraryService.getThumbnail(checksum: file.checksum)
        } catch {
            // No thumbnail available
        }
    }
}

// MARK: - View Model

@MainActor
final class LibraryListViewModel: ObservableObject {
    @Published var files: [LibraryFile] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let libraryService = LibraryService()
    private var currentPage = 1
    private var totalPages = 1
    private var currentSearch: String?

    var hasMorePages: Bool {
        currentPage < totalPages
    }

    func loadFiles() async {
        currentSearch = nil
        await reload()
    }

    func search(query: String) async {
        // The backend requires at least 2 characters; treat shorter
        // input as "no search".
        currentSearch = query.count >= 2 ? query : nil
        await reload()
    }

    private func reload() async {
        isLoading = true
        currentPage = 1

        do {
            let response = try await libraryService.listFiles(search: currentSearch, page: 1)
            files = response.files
            totalPages = response.pagination?.totalPages ?? 1
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
            let response = try await libraryService.listFiles(search: currentSearch, page: currentPage)
            files.append(contentsOf: response.files)
            totalPages = response.pagination?.totalPages ?? totalPages
        } catch {
            currentPage -= 1
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func deleteFile(_ file: LibraryFile) async {
        do {
            try await libraryService.deleteFile(checksum: file.checksum)
            files.removeAll { $0.checksum == file.checksum }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    LibraryListView()
}
