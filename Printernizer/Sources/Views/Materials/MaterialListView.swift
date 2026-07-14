import SwiftUI

struct MaterialListView: View {
    @StateObject private var viewModel = MaterialListViewModel()
    @State private var selectedMaterial: MaterialResponse?
    @State private var showLowStockOnly = false
    @State private var showDeleteConfirmation = false
    @State private var materialToDelete: MaterialResponse?
    @State private var exportedFile: ExportedFile?
    @State private var isExporting = false

    struct ExportedFile: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.materials.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.materials.isEmpty {
                    ContentUnavailableView(
                        "No Materials",
                        systemImage: "cylinder",
                        description: Text("Add filament spools to track your inventory.")
                    )
                } else {
                    materialList
                }
            }
            .navigationTitle("Materials")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Low Stock Only", isOn: $showLowStockOnly)
                            .onChange(of: showLowStockOnly) { _, newValue in
                                Task {
                                    await viewModel.loadMaterials(lowStock: newValue)
                                }
                            }

                        Divider()

                        Button {
                            Task { await exportInventory(format: .csv) }
                        } label: {
                            Label("Export as CSV", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            Task { await exportInventory(format: .excel) }
                        } label: {
                            Label("Export as Excel", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .refreshable {
                await viewModel.loadMaterials(lowStock: showLowStockOnly)
            }
            .task {
                await viewModel.loadMaterials()
                await viewModel.loadStats()
            }
            .sheet(item: $selectedMaterial) { material in
                NavigationStack {
                    MaterialDetailView(material: material) {
                        materialToDelete = material
                        showDeleteConfirmation = true
                    }
                }
            }
            .confirmationDialog("Delete Material?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let material = materialToDelete {
                        Task {
                            await viewModel.deleteMaterial(material)
                            selectedMaterial = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this material from your inventory?")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(item: $exportedFile) { file in
                ShareSheetView(url: file.url)
            }
        }
    }

    private func exportInventory(format: MaterialExportFormat) async {
        isExporting = true
        defer { isExporting = false }

        if let url = await viewModel.exportMaterials(format: format) {
            exportedFile = ExportedFile(url: url)
        }
    }

    private var materialList: some View {
        List {
            // Stats section
            if let stats = viewModel.stats {
                statsSection(stats)
            }

            // Materials
            Section {
                ForEach(viewModel.materials) { material in
                    MaterialRowView(material: material)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMaterial = material
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func statsSection(_ stats: MaterialStats) -> some View {
        Section {
            HStack(spacing: 16) {
                StatCard(title: "Spools", value: "\(stats.totalSpools)", icon: "cylinder.fill", color: .blue)
                StatCard(title: "Low Stock", value: "\(stats.lowStock ?? 0)", icon: "exclamationmark.triangle.fill", color: .orange)
                StatCard(title: "Total", value: formatWeight(stats.totalWeight), icon: "scalemass.fill", color: .green)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000)
        }
        return String(format: "%.0fg", grams)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Material Row View

struct MaterialRowView: View {
    let material: MaterialResponse

    var body: some View {
        HStack(spacing: 12) {
            // Color swatch
            Circle()
                .fill(material.displayColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(material.brand)
                        .font(.headline)

                    Text(material.materialType)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                Text(material.color)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Progress bar
                ProgressView(value: material.remainingPercentage / 100)
                    .progressViewStyle(.linear)
                    .tint(progressColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(material.formattedWeight)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(Int(material.remainingPercentage))%")
                    .font(.caption)
                    .foregroundStyle(progressColor)

                if material.isLowStock {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
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

// MARK: - View Model

@MainActor
final class MaterialListViewModel: ObservableObject {
    @Published var materials: [MaterialResponse] = []
    @Published var stats: MaterialStats?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let materialService = MaterialService()

    func loadMaterials(lowStock: Bool = false) async {
        isLoading = true

        do {
            materials = try await materialService.listMaterials(lowStock: lowStock)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func loadStats() async {
        do {
            stats = try await materialService.getStats()
        } catch {
            // Stats are optional, don't show error
        }
    }

    func deleteMaterial(_ material: MaterialResponse) async {
        do {
            try await materialService.deleteMaterial(id: material.id)
            materials.removeAll { $0.id == material.id }
            await loadStats()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func exportMaterials(format: MaterialExportFormat) async -> URL? {
        do {
            return try await materialService.exportMaterials(format: format)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

#Preview {
    MaterialListView()
}
