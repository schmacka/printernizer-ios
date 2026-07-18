import SwiftUI
import UniformTypeIdentifiers

struct LibraryListView: View {
    @StateObject private var viewModel = LibraryListViewModel()
    @State private var searchText = ""
    @State private var selectedFile: LibraryFile?
    @State private var roleFilter: LibraryRoleFilter = .all
    @State private var sourceFilter: String?
    @State private var thumbnailOnly = false
    @State private var showFileImporter = false
    @State private var showStats = false

    /// File types the backend accepts for library uploads.
    private static let uploadTypes: [UTType] = {
        var types: [UTType] = []
        for ext in ["stl", "3mf", "gcode", "bgcode", "obj", "ply"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        types.append(.data)
        return types
    }()

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
                    Button {
                        showFileImporter = true
                    } label: {
                        if viewModel.isUploading {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(viewModel.isUploading)
                }

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

                        Divider()

                        Picker("Source", selection: $sourceFilter) {
                            Text("All Sources").tag(String?.none)
                            Text("Printer").tag(String?.some("printer"))
                            Text("Watch Folder").tag(String?.some("watch_folder"))
                            Text("Upload").tag(String?.some("upload"))
                        }

                        Toggle("With Thumbnail Only", isOn: $thumbnailOnly)

                        Divider()

                        Button {
                            showStats = true
                        } label: {
                            Label("Library Statistics", systemImage: "chart.bar")
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .onChange(of: sourceFilter) { _, _ in
                Task { await viewModel.applyFilters(sourceType: sourceFilter, hasThumbnail: thumbnailOnly ? true : nil) }
            }
            .onChange(of: thumbnailOnly) { _, _ in
                Task { await viewModel.applyFilters(sourceType: sourceFilter, hasThumbnail: thumbnailOnly ? true : nil) }
            }
            .sheet(isPresented: $showStats) {
                LibraryStatsView()
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: Self.uploadTypes,
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    Task { await viewModel.upload(urls: urls) }
                }
            }
            .refreshable {
                await viewModel.loadFiles()
            }
            .task {
                guard APIConfiguration.isConfigured else { return }
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
    @Published var isUploading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let libraryService = LibraryService()
    private var currentPage = 1
    private var totalPages = 1
    private var currentSearch: String?
    private var sourceType: String?
    private var hasThumbnail: Bool?

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

    func applyFilters(sourceType: String?, hasThumbnail: Bool?) async {
        self.sourceType = sourceType
        self.hasThumbnail = hasThumbnail
        await reload()
    }

    private func reload() async {
        isLoading = true
        currentPage = 1

        do {
            let response = try await libraryService.listFiles(
                search: currentSearch,
                sourceType: sourceType,
                hasThumbnail: hasThumbnail,
                page: 1
            )
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
            let response = try await libraryService.listFiles(
                search: currentSearch,
                sourceType: sourceType,
                hasThumbnail: hasThumbnail,
                page: currentPage
            )
            files.append(contentsOf: response.files)
            totalPages = response.pagination?.totalPages ?? totalPages
        } catch {
            currentPage -= 1
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    /// Uploads picked files. Security-scoped access is required for
    /// URLs coming from the document picker.
    func upload(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isUploading = true
        defer { isUploading = false }

        var payload: [(filename: String, data: Data)] = []
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                payload.append((filename: url.lastPathComponent, data: data))
            } catch {
                errorMessage = "Could not read \(url.lastPathComponent)"
                showError = true
            }
        }

        guard !payload.isEmpty else { return }

        do {
            try await libraryService.uploadFiles(payload)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
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
