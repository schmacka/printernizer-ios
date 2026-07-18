import SwiftUI

/// Order source management (e.g. Etsy, eBay, direct).
struct OrderSourcesView: View {
    @StateObject private var viewModel = OrderSourcesViewModel()
    @State private var newSourceName = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("New source name", text: $newSourceName)

                    Button("Add") {
                        Task {
                            await viewModel.create(name: newSourceName)
                            newSourceName = ""
                        }
                    }
                    .disabled(newSourceName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section {
                ForEach(viewModel.sources) { source in
                    HStack {
                        Text(source.name)

                        Spacer()

                        if source.isActive == false {
                            Text("Inactive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    Task { await viewModel.delete(at: indexSet) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Order Sources")
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
final class OrderSourcesViewModel: ObservableObject {
    @Published var sources: [OrderSourceResponse] = []
    @Published var showError = false
    @Published var errorMessage = ""

    private let orderService = OrderService()

    func load() async {
        do {
            sources = try await orderService.listOrderSources()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func create(name: String) async {
        do {
            _ = try await orderService.createOrderSource(name: name.trimmingCharacters(in: .whitespaces))
            await load()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func delete(at indexSet: IndexSet) async {
        for index in indexSet {
            guard sources.indices.contains(index) else { continue }
            let source = sources[index]
            do {
                try await orderService.deleteOrderSource(id: source.id)
                sources.removeAll { $0.id == source.id }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        OrderSourcesView()
    }
}
