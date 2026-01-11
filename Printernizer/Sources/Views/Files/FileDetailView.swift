import SwiftUI

struct FileDetailView: View {
    let file: FileResponse
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = true

    private let fileService = FileService()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Thumbnail
                thumbnailSection

                // File info
                infoSection

                // Metadata
                metadataSection

                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle("File Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            if file.hasThumbnail {
                await loadThumbnail()
            } else {
                isLoadingThumbnail = false
            }
        }
    }

    private var thumbnailSection: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if isLoadingThumbnail && file.hasThumbnail {
                ProgressView()
                    .frame(height: 200)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: file.sourceIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(file.filename)
                .font(.title3)
                .fontWeight(.bold)

            HStack {
                Label(file.source.capitalized, systemImage: file.sourceIcon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())

                Label(file.status.capitalized, systemImage: "circle.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)

            detailRow(label: "Size", value: file.formattedFileSize)

            if let fileType = file.fileType {
                detailRow(label: "Type", value: fileType.uppercased())
            }

            if let date = file.formattedDate {
                detailRow(label: "Added", value: date)
            }

            if let width = file.thumbnailWidth, let height = file.thumbnailHeight {
                detailRow(label: "Thumbnail", value: "\(width) x \(height)")
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionsSection: some View {
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete File", systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
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

#Preview {
    NavigationStack {
        FileDetailView(
            file: FileResponse(
                id: "1",
                printerId: "printer-1",
                filename: "benchy.gcode",
                source: "printer",
                status: "ready",
                fileSize: 1_500_000,
                filePath: nil,
                fileType: "gcode",
                downloadedAt: "2024-01-15T10:30:00Z",
                createdAt: "2024-01-15T10:30:00Z",
                watchFolderPath: nil,
                relativePath: nil,
                modifiedTime: nil,
                hasThumbnail: true,
                thumbnailWidth: 400,
                thumbnailHeight: 300,
                thumbnailFormat: "png"
            ),
            onDelete: { }
        )
    }
}
