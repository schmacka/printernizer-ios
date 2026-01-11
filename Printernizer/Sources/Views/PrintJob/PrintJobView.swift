import SwiftUI

struct PrintJobView: View {
    let job: PrintJob

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Print")
                    .font(.headline)
                Spacer()
                Text(job.fileName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ProgressView(value: job.progress)
                    .tint(.accentColor)

                HStack {
                    Text("\(Int(job.progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    if let timeRemaining = job.formattedTimeRemaining {
                        Label(timeRemaining, systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 24) {
                statView(title: "Layer", value: "\(job.currentLayer)/\(job.totalLayers)")
                statView(title: "Elapsed", value: job.formattedElapsedTime)
                statView(title: "Filament", value: job.formattedFilamentUsed)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    PrintJobView(job: .preview)
        .padding()
}
