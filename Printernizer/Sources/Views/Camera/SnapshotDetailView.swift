import SwiftUI

struct SnapshotDetailView: View {
    let snapshot: SnapshotResponse

    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0

    private let cameraService = CameraService()

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack {
                    if let image = fullImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .frame(
                                width: geometry.size.width * scale,
                                height: geometry.size.height * scale
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = max(1.0, min(value, 4.0))
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    scale = scale > 1.0 ? 1.0 : 2.0
                                }
                            }
                    } else if isLoading {
                        ProgressView()
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Failed to load image")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
        }
        .background(Color.black)
        .navigationTitle("Snapshot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                if let image = fullImage {
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview("Snapshot", image: Image(uiImage: image))
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            snapshotInfoBar
        }
        .task {
            await loadFullImage()
        }
    }

    private var snapshotInfoBar: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate)
                        .font(.headline)

                    if let jobName = snapshot.jobName {
                        Text(jobName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(triggerLabel)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                    if let width = snapshot.width, let height = snapshot.height {
                        Text("\(width) x \(height)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    private var formattedDate: String {
        // Parse ISO date string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: snapshot.capturedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        // Fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: snapshot.capturedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return snapshot.capturedAt
    }

    private var triggerLabel: String {
        switch snapshot.captureTrigger {
        case "manual":
            return "Manual"
        case "auto":
            return "Auto"
        case "job_start":
            return "Job Start"
        case "job_complete":
            return "Completed"
        case "job_failed":
            return "Failed"
        default:
            return snapshot.captureTrigger.capitalized
        }
    }

    private func loadFullImage() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let image = try await cameraService.downloadSnapshotImage(snapshotId: snapshot.id)
            fullImage = image
        } catch {
            // Failed to load image
        }
    }
}

#Preview {
    NavigationStack {
        SnapshotDetailView(
            snapshot: SnapshotResponse(
                id: 1,
                printerId: "test",
                jobId: nil,
                filename: "test.jpg",
                fileSize: 1024,
                contentType: "image/jpeg",
                capturedAt: "2024-01-15T10:30:00Z",
                captureTrigger: "manual",
                width: 1920,
                height: 1080,
                isValid: true,
                notes: nil,
                jobName: "Test Print",
                jobStatus: nil,
                printerName: "Prusa MK4",
                printerType: nil
            )
        )
    }
}
