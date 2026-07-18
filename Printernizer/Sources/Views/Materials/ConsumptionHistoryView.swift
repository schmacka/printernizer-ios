import SwiftUI

/// Filament consumption history, optionally filtered to one material.
struct ConsumptionHistoryView: View {
    var materialId: String?

    @StateObject private var viewModel = ConsumptionHistoryViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No Consumption Recorded",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("Recorded filament usage will appear here.")
                )
            } else {
                List {
                    ForEach(viewModel.items) { item in
                        consumptionRow(item)
                    }

                    if viewModel.hasMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .onAppear {
                                Task { await viewModel.loadMore(materialId: materialId) }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Consumption History")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.reload(materialId: materialId)
        }
        .task {
            await viewModel.reload(materialId: materialId)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func consumptionRow(_ item: ConsumptionHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(item.brand.capitalized) \(item.materialType)")
                    .font(.headline)

                Spacer()

                Text(Formatters.weightGrams(item.weightUsed))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if let fileName = item.fileName {
                Text(fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                if let date = Formatters.mediumDateTime(item.timestamp) {
                    Text(date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if item.cost > 0 {
                    Text(Formatters.eurString(item.cost))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

@MainActor
final class ConsumptionHistoryViewModel: ObservableObject {
    @Published var items: [ConsumptionHistoryItem] = []
    @Published var isLoading = false
    @Published var hasMore = false
    @Published var showError = false
    @Published var errorMessage = ""

    private var page = 1
    private let materialService = MaterialService()

    func reload(materialId: String?) async {
        page = 1
        await load(materialId: materialId, replace: true)
    }

    func loadMore(materialId: String?) async {
        guard hasMore, !isLoading else { return }
        page += 1
        await load(materialId: materialId, replace: false)
    }

    private func load(materialId: String?, replace: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await materialService.consumptionHistory(
                materialId: materialId,
                days: 365,
                page: page
            )
            if replace {
                items = response.items
            } else {
                items.append(contentsOf: response.items)
            }
            hasMore = response.page < response.totalPages
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        ConsumptionHistoryView()
    }
}
