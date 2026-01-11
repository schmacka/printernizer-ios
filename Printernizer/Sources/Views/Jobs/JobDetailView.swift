import SwiftUI

struct JobDetailView: View {
    let job: JobResponse

    @Environment(\.dismiss) private var dismiss
    @State private var showCancelConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Progress (if running)
                if isRunning, let progress = job.progress ?? job.progressPercent {
                    progressSection(progress: progress)
                }

                // Details
                detailsSection

                // Costs
                if job.totalCost > 0 {
                    costsSection
                }

                // Actions
                if isRunning {
                    actionsSection
                }
            }
            .padding()
        }
        .navigationTitle("Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .confirmationDialog("Cancel Job?", isPresented: $showCancelConfirmation) {
            Button("Cancel Job", role: .destructive) {
                Task {
                    await cancelJob()
                }
            }
            Button("Keep Running", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel this print job?")
        }
    }

    private var isRunning: Bool {
        let status = job.status.lowercased()
        return status == "running" || status == "printing" || status == "pending"
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Status badge
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(job.status.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if job.isBusiness {
                    Text("Business")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            Text(job.jobName)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if let filename = job.filename {
                Text(filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func progressSection(progress: Double) -> some View {
        VStack(spacing: 12) {
            Text("Progress")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ProgressView(value: progress / 100)
                .progressViewStyle(.linear)
                .tint(.blue)

            Text("\(Int(progress))%")
                .font(.title)
                .fontWeight(.bold)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)

            detailRow(label: "Printer", value: job.printerType)

            if let date = job.formattedDate {
                detailRow(label: "Started", value: date)
            }

            if let duration = job.formattedDuration {
                detailRow(label: "Duration", value: duration)
            }

            if let materialUsed = job.materialUsed, materialUsed > 0 {
                detailRow(label: "Material Used", value: String(format: "%.1f g", materialUsed))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var costsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Costs")
                .font(.headline)

            if let materialCost = job.materialCost, materialCost > 0 {
                detailRow(label: "Material", value: String(format: "%.2f EUR", materialCost))
            }

            if let powerCost = job.powerCost, powerCost > 0 {
                detailRow(label: "Power", value: String(format: "%.2f EUR", powerCost))
            }

            Divider()

            detailRow(label: "Total", value: String(format: "%.2f EUR", job.totalCost))
                .fontWeight(.semibold)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionsSection: some View {
        Button(role: .destructive) {
            showCancelConfirmation = true
        } label: {
            Label("Cancel Job", systemImage: "xmark.circle")
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

    private func cancelJob() async {
        let jobService = JobService()
        do {
            try await jobService.cancelJob(id: job.id)
            dismiss()
        } catch {
            // Handle error
        }
    }
}

#Preview {
    NavigationStack {
        JobDetailView(
            job: JobResponse(
                id: "1",
                printerId: "printer-1",
                printerType: "Bambu Lab",
                jobName: "Test Print",
                filename: "benchy.gcode",
                status: "running",
                startTime: nil,
                endTime: nil,
                estimatedDuration: 3600,
                actualDuration: nil,
                progress: 45,
                materialUsed: 15.5,
                materialCost: 0.50,
                powerCost: 0.10,
                isBusiness: false,
                createdAt: "2024-01-15T10:30:00Z",
                updatedAt: "2024-01-15T10:30:00Z",
                progressPercent: 45,
                costEur: 0.60,
                startedAt: "2024-01-15T10:30:00Z",
                completedAt: nil
            )
        )
    }
}
