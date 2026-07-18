import SwiftUI

/// Saved generator parameter presets; native fallback for browsing
/// and deleting presets without loading the web generator.
struct GeneratorPresetsView: View {
    @StateObject private var viewModel = GeneratorPresetsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.presets.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.presets.isEmpty {
                ContentUnavailableView(
                    "No Presets",
                    systemImage: "list.star",
                    description: Text("Presets saved in the generator will appear here.")
                )
            } else {
                List {
                    ForEach(viewModel.presets) { preset in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .font(.headline)
                            Text(preset.templateId)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        Task { await viewModel.delete(at: indexSet) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Generator Presets")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

@MainActor
final class GeneratorPresetsViewModel: ObservableObject {
    @Published var presets: [GeneratorPreset] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let generatorService = GeneratorService()

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            presets = try await generatorService.listPresets()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func delete(at indexSet: IndexSet) async {
        for index in indexSet {
            guard presets.indices.contains(index) else { continue }
            let preset = presets[index]
            do {
                try await generatorService.deletePreset(id: preset.id)
                presets.removeAll { $0.id == preset.id }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        GeneratorPresetsView()
    }
}
