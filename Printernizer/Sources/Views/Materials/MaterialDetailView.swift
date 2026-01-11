import SwiftUI

struct MaterialDetailView: View {
    let material: MaterialResponse
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with color
                headerSection

                // Stock level
                stockSection

                // Details
                detailsSection

                // Cost
                if material.costPerKg > 0 {
                    costSection
                }

                // Notes
                if let notes = material.notes, !notes.isEmpty {
                    notesSection(notes)
                }

                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Material Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Color circle
            Circle()
                .fill(material.displayColor)
                .frame(width: 80, height: 80)
                .overlay {
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                }
                .shadow(color: material.displayColor.opacity(0.4), radius: 8, y: 4)

            VStack(spacing: 4) {
                Text(material.brand)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(material.color)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(material.materialType)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    Text("\(String(format: "%.2f", material.diameter))mm")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.gray.opacity(0.1))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())

                    if !material.isActive {
                        Text("Inactive")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var stockSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Stock Level")
                    .font(.headline)

                Spacer()

                if material.isLowStock {
                    Label("Low Stock", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            VStack(spacing: 8) {
                ProgressView(value: material.remainingPercentage / 100)
                    .progressViewStyle(.linear)
                    .tint(progressColor)
                    .scaleEffect(y: 2)

                HStack {
                    Text(material.formattedWeight)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("/ \(material.formattedTotalWeight)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(material.remainingPercentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(progressColor)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)

            detailRow(label: "Vendor", value: material.vendor)

            if let batchNumber = material.batchNumber {
                detailRow(label: "Batch", value: batchNumber)
            }

            if let location = material.location {
                detailRow(label: "Location", value: location)
            }

            detailRow(label: "Diameter", value: String(format: "%.2f mm", material.diameter))
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var costSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost")
                .font(.headline)

            detailRow(label: "Price per kg", value: String(format: "%.2f EUR", material.costPerKg))
            detailRow(label: "Remaining Value", value: String(format: "%.2f EUR", material.remainingValue))
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)

            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionsSection: some View {
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete Material", systemImage: "trash")
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

    private var progressColor: Color {
        if material.remainingPercentage < 10 {
            return .red
        } else if material.remainingPercentage < 20 {
            return .orange
        }
        return .green
    }
}

#Preview {
    NavigationStack {
        MaterialDetailView(
            material: MaterialResponse(
                id: "1",
                materialType: "PLA",
                brand: "Prusament",
                color: "Galaxy Black",
                diameter: 1.75,
                weight: 1000,
                remainingWeight: 750,
                remainingPercentage: 75,
                costPerKg: 25.99,
                remainingValue: 19.49,
                vendor: "Prusa Research",
                batchNumber: "ABC123",
                notes: "Great quality, smooth prints",
                printerId: nil,
                colorHex: "#1a1a2e",
                location: "Shelf A",
                isActive: true,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-15T00:00:00Z"
            ),
            onDelete: { }
        )
    }
}
