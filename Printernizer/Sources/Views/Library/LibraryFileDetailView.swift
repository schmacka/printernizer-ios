import SwiftUI

struct LibraryFileDetailView: View {
    let file: LibraryFile
    let onDelete: () -> Void

    @EnvironmentObject private var apiService: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var thumbnailImage: UIImage?
    @State private var printFiles: [LibraryPrintFile] = []
    @State private var isLoadingPrintFiles = false
    @State private var showDeleteConfirmation = false
    @State private var showPrinterPicker = false
    @State private var printTargetChecksum: String?
    @State private var printers: [Printer] = []
    @State private var isPrinting = false
    @State private var printResult: PrintResult?

    private let libraryService = LibraryService()

    enum PrintResult: Identifiable {
        case success
        case failure(String)

        var id: String {
            switch self {
            case .success: return "success"
            case .failure(let message): return message
            }
        }
    }

    var body: some View {
        List {
            thumbnailSection
            infoSection

            if let error = file.analysisError {
                Section("Analysis Error") {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if file.isModel {
                printFilesSection
            }

            actionsSection
        }
        .navigationTitle(file.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            await loadDetails()
        }
        .confirmationDialog("Delete File?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this file from the library?")
        }
        .confirmationDialog("Print on...", isPresented: $showPrinterPicker, titleVisibility: .visible) {
            ForEach(printers) { printer in
                Button(printer.name) {
                    if let checksum = printTargetChecksum {
                        Task {
                            await startPrint(checksum: checksum, printerId: printer.id)
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert(item: $printResult) { result in
            switch result {
            case .success:
                return Alert(
                    title: Text("Print Started"),
                    message: Text("The file was sent to the printer."),
                    dismissButton: .default(Text("OK"))
                )
            case .failure(let message):
                return Alert(
                    title: Text("Print Failed"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Sections

    private var thumbnailSection: some View {
        Section {
            ZStack {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 240)
                        .frame(maxWidth: .infinity)
                } else {
                    Image(systemName: file.roleIcon)
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                }
            }
            .listRowBackground(Color.gray.opacity(0.1))
        }
    }

    private var infoSection: some View {
        Section("Details") {
            LabeledContent("Filename", value: file.filename)

            if let fileType = file.fileType {
                LabeledContent("Type", value: fileType.uppercased())
            }

            LabeledContent("Size", value: file.formattedFileSize)

            LabeledContent("Kind", value: file.isPrintFile ? "Print File" : "Model")

            if let dimensions = file.formattedDimensions {
                LabeledContent("Dimensions", value: dimensions)
            }

            if let weight = file.totalFilamentWeight, weight > 0 {
                LabeledContent("Filament", value: String(format: "%.0f g", weight))
            }

            if let cost = file.totalCost ?? file.materialCost, cost > 0 {
                LabeledContent("Est. Cost", value: String(format: "%.2f €", cost))
            }

            if let slicer = file.slicerName {
                LabeledContent("Slicer", value: slicer)
            }

            if let profile = file.profileName {
                LabeledContent("Profile", value: profile)
            }

            if let date = file.formattedDate {
                LabeledContent("Added", value: date)
            }
        }
    }

    private var printFilesSection: some View {
        Section("Print Files") {
            if isLoadingPrintFiles {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if printFiles.isEmpty {
                Text("No sliced print files yet. Slice this model in the Printernizer web app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(printFiles) { printFile in
                    printFileRow(printFile)
                }
            }
        }
    }

    private func printFileRow(_ printFile: LibraryPrintFile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.badge.gearshape")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(printFile.displayTitle)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let profile = printFile.profileName {
                        Text(profile)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let time = printFile.formattedPrintTime {
                        Label(time, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                printTargetChecksum = printFile.checksum
                Task {
                    await openPrinterPicker()
                }
            } label: {
                Image(systemName: "printer.fill")
            }
            .buttonStyle(.borderless)
            .disabled(isPrinting)
        }
    }

    private var actionsSection: some View {
        Section {
            if file.isPrintFile {
                Button {
                    printTargetChecksum = file.checksum
                    Task {
                        await openPrinterPicker()
                    }
                } label: {
                    Label("Print", systemImage: "printer.fill")
                }
                .disabled(isPrinting)
            }

            if let url = libraryService.downloadURL(checksum: file.checksum) {
                ShareLink(item: url) {
                    Label("Share Download Link", systemImage: "square.and.arrow.up")
                }
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    private func loadDetails() async {
        if file.hasThumbnail == true {
            thumbnailImage = try? await libraryService.getThumbnail(checksum: file.checksum)
        }

        if file.isModel {
            isLoadingPrintFiles = true
            printFiles = (try? await libraryService.getPrintFiles(checksum: file.checksum)) ?? []
            isLoadingPrintFiles = false
        }
    }

    private func openPrinterPicker() async {
        if printers.isEmpty {
            printers = (try? await apiService.fetchPrinters()) ?? []
        }
        if printers.isEmpty {
            printResult = .failure("No printers available.")
        } else {
            showPrinterPicker = true
        }
    }

    private func startPrint(checksum: String, printerId: String) async {
        isPrinting = true
        defer { isPrinting = false }

        do {
            try await libraryService.printFile(checksum: checksum, printerId: printerId)
            printResult = .success
        } catch {
            printResult = .failure(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack {
        LibraryFileDetailView(
            file: LibraryFile(
                checksum: "abc123",
                filename: "benchy.stl",
                displayName: "3D Benchy",
                fileSize: 1_500_000,
                fileType: "stl",
                status: "ready",
                role: "model",
                parentChecksum: nil,
                analysisError: nil,
                hasThumbnail: false,
                addedToLibrary: nil,
                lastModified: nil,
                modelWidth: 60,
                modelDepth: 31,
                modelHeight: 48,
                totalFilamentWeight: 15,
                materialCost: 0.45,
                totalCost: 0.6,
                slicerName: nil,
                profileName: nil,
                sources: nil
            ),
            onDelete: { }
        )
        .environmentObject(APIService())
    }
}
