import SwiftUI

/// Printer file discovery & downloads plus watch folder management —
/// the web app's "Files" page. Pushed from the More tab.
struct FileListView: View {
    enum Section: String, CaseIterable, Identifiable {
        case files = "Printer Files"
        case watchFolders = "Watch Folders"

        var id: String { rawValue }
    }

    @State private var section: Section = .files

    var body: some View {
        Group {
            switch section {
            case .files:
                PrinterFilesSection()
            case .watchFolders:
                WatchFoldersSection()
            }
        }
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Printer Files

struct PrinterFilesSection: View {
    @StateObject private var viewModel = PrinterFilesViewModel()
    @State private var statusFilter: String?
    @State private var searchText = ""

    private static let statusOptions = ["available", "downloaded", "local", "error"]

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.files.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.files.isEmpty {
                ContentUnavailableView(
                    "No Files",
                    systemImage: "doc",
                    description: Text("Files discovered on your printers and watch folders appear here.")
                )
            } else {
                fileList
            }
        }
        .searchable(text: $searchText, prompt: "Search files")
        .onSubmit(of: .search) {
            Task { await viewModel.load(status: statusFilter, search: searchText) }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                Task { await viewModel.load(status: statusFilter, search: nil) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.sync() }
                } label: {
                    if viewModel.isSyncing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(viewModel.isSyncing)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $statusFilter) {
                        Text("All Statuses").tag(String?.none)
                        ForEach(Self.statusOptions, id: \.self) { status in
                            Text(status.capitalized).tag(String?.some(status))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onChange(of: statusFilter) { _, _ in
            Task { await viewModel.load(status: statusFilter, search: searchText) }
        }
        .refreshable {
            await viewModel.load(status: statusFilter, search: searchText)
        }
        .task {
            guard APIConfiguration.isConfigured else { return }
            await viewModel.load(status: statusFilter, search: nil)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var fileList: some View {
        List {
            ForEach(viewModel.files) { file in
                fileRow(file)
            }

            if viewModel.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        Task { await viewModel.loadMore(status: statusFilter, search: searchText) }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func fileRow(_ file: PrinterFileResponse) -> some View {
        HStack(spacing: 12) {
            Image(systemName: file.sourceIcon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.filename)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text((file.status ?? "unknown").capitalized)
                        .font(.caption)
                        .foregroundStyle(file.statusColor)

                    if let size = file.formattedSize {
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let type = file.fileType {
                        Text(type.uppercased())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if file.isDownloadable {
                Button {
                    Task { await viewModel.download(file) }
                } label: {
                    if viewModel.downloadingIds.contains(file.id) {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.down.circle")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.downloadingIds.contains(file.id))
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.delete(file) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

@MainActor
final class PrinterFilesViewModel: ObservableObject {
    @Published var files: [PrinterFileResponse] = []
    @Published var downloadingIds: Set<String> = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var hasMore = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let fileService = FileService()
    private var page = 1

    func load(status: String?, search: String?) async {
        page = 1
        await fetch(status: status, search: search, replace: true)
    }

    func loadMore(status: String?, search: String?) async {
        guard hasMore, !isLoading else { return }
        page += 1
        await fetch(status: status, search: search, replace: false)
    }

    private func fetch(status: String?, search: String?, replace: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await fileService.listFiles(
                status: status,
                search: search?.isEmpty == true ? nil : search,
                page: page
            )
            if replace {
                files = response.files
            } else {
                files.append(contentsOf: response.files)
            }
            let totalPages = response.pagination?.totalPages ?? 1
            hasMore = page < totalPages
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func sync() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await fileService.syncFiles()
            await load(status: nil, search: nil)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func download(_ file: PrinterFileResponse) async {
        downloadingIds.insert(file.id)
        defer { downloadingIds.remove(file.id) }

        do {
            try await fileService.downloadFile(id: file.id)
            await load(status: nil, search: nil)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func delete(_ file: PrinterFileResponse) async {
        do {
            try await fileService.deleteFile(id: file.id)
            files.removeAll { $0.id == file.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Watch Folders

struct WatchFoldersSection: View {
    @StateObject private var viewModel = WatchFoldersViewModel()
    @State private var newFolderPath = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Server folder path", text: $newFolderPath)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    Button("Add") {
                        Task {
                            await viewModel.add(path: newFolderPath)
                            newFolderPath = ""
                        }
                    }
                    .disabled(newFolderPath.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Watch folders are paths on the Printernizer server; new model files there are imported automatically.")
            }

            Section("Folders") {
                if viewModel.folders.isEmpty && !viewModel.isLoading {
                    Text("No watch folders configured")
                        .foregroundStyle(.secondary)
                }

                ForEach(viewModel.folders, id: \.itemId) { folder in
                    folderRow(folder)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.load()
        }
        .task {
            guard APIConfiguration.isConfigured else { return }
            await viewModel.load()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func folderRow(_ folder: WatchFolderItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(folder.folderName ?? folder.folderPath)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { folder.isActive ?? true },
                    set: { newValue in
                        Task { await viewModel.setActive(folder, isActive: newValue) }
                    }
                ))
                .labelsHidden()
            }

            Text(folder.folderPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                if let count = folder.fileCount {
                    Text("\(count) files")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if folder.isValid == false {
                    Label(folder.validationError ?? "Invalid path", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.remove(folder) }
            } label: {
                Label("Remove", systemImage: "trash")
            }

            Button {
                Task { await viewModel.rescan(folder) }
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .tint(.blue)
        }
    }
}

@MainActor
final class WatchFoldersViewModel: ObservableObject {
    @Published var folders: [WatchFolderItem] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let fileService = FileService()

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            folders = try await fileService.watchFolderSettings().watchFolders
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func add(path: String) async {
        do {
            try await fileService.addWatchFolder(path: path.trimmingCharacters(in: .whitespaces))
            await load()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func remove(_ folder: WatchFolderItem) async {
        do {
            try await fileService.removeWatchFolder(path: folder.folderPath)
            folders.removeAll { $0.itemId == folder.itemId }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func setActive(_ folder: WatchFolderItem, isActive: Bool) async {
        do {
            try await fileService.setWatchFolderActive(path: folder.folderPath, isActive: isActive)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func rescan(_ folder: WatchFolderItem) async {
        do {
            try await fileService.rescanWatchFolder(path: folder.folderPath)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        FileListView()
    }
}
