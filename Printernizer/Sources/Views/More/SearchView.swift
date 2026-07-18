import SwiftUI

/// Unified search over library files and ideas, from the More tab.
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""

    var body: some View {
        Group {
            if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let results = viewModel.results, !results.groups.isEmpty {
                resultsList(results)
            } else if viewModel.results != nil {
                ContentUnavailableView.search(text: searchText)
            } else {
                ContentUnavailableView(
                    "Search Printernizer",
                    systemImage: "magnifyingglass",
                    description: Text("Find library files and ideas by name, description, or tags.")
                )
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchText, prompt: "Search files and ideas")
        .onSubmit(of: .search) {
            Task { await viewModel.search(query: searchText) }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                viewModel.results = nil
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func resultsList(_ results: SearchResults) -> some View {
        List {
            ForEach(results.groups, id: \.source) { group in
                Section(sourceTitle(group.source)) {
                    ForEach(group.results) { item in
                        resultRow(item)
                    }
                }
            }

            if let time = results.searchTimeMs {
                Section {
                    Text("\(results.totalResults ?? 0) results in \(time) ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func sourceTitle(_ source: String) -> String {
        switch source {
        case "local_files": return "Library Files"
        case "ideas": return "Ideas"
        default: return source.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func resultRow(_ item: SearchResultItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if let minutes = item.printTimeMinutes, minutes > 0 {
                    Label(Formatters.duration(minutes: minutes), systemImage: "clock")
                }
                if let cost = item.costEur, cost > 0 {
                    Text(Formatters.eurString(cost))
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var results: SearchResults?
    @Published var isSearching = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let searchService = SearchService()

    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }

        do {
            results = try await searchService.search(query: trimmed)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
