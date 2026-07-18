import SwiftUI

/// Idea board: print ideas and imported bookmarks. Pushed from the
/// More tab (enclosing NavigationStack provided there).
struct IdeaListView: View {
    @StateObject private var viewModel = IdeaListViewModel()
    @State private var statusFilter: IdeaStatus?
    @State private var businessFilter: Bool?
    @State private var selectedIdea: IdeaResponse?
    @State private var showNewIdea = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.ideas.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.ideas.isEmpty {
                ContentUnavailableView {
                    Label("No Ideas", systemImage: "lightbulb")
                } description: {
                    Text("Collect print ideas or import them from MakerWorld and Printables.")
                } actions: {
                    Button("New Idea") { showNewIdea = true }
                }
            } else {
                ideaList
            }
        }
        .navigationTitle("Ideas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewIdea = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $statusFilter) {
                        Text("All Statuses").tag(IdeaStatus?.none)
                        ForEach(IdeaStatus.allCases) { status in
                            Text(status.displayName).tag(IdeaStatus?.some(status))
                        }
                    }

                    Picker("Type", selection: $businessFilter) {
                        Text("All Types").tag(Bool?.none)
                        Text("Business").tag(Bool?.some(true))
                        Text("Personal").tag(Bool?.some(false))
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onChange(of: statusFilter) { _, _ in
            Task { await viewModel.load(status: statusFilter, isBusiness: businessFilter) }
        }
        .onChange(of: businessFilter) { _, _ in
            Task { await viewModel.load(status: statusFilter, isBusiness: businessFilter) }
        }
        .refreshable {
            await viewModel.load(status: statusFilter, isBusiness: businessFilter)
        }
        .task {
            guard APIConfiguration.isConfigured else { return }
            await viewModel.load(status: statusFilter, isBusiness: businessFilter)
        }
        .sheet(item: $selectedIdea) { idea in
            IdeaDetailView(ideaId: idea.id) {
                Task { await viewModel.load(status: statusFilter, isBusiness: businessFilter) }
            }
        }
        .sheet(isPresented: $showNewIdea) {
            IdeaFormView {
                Task { await viewModel.load(status: statusFilter, isBusiness: businessFilter) }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var ideaList: some View {
        List {
            ForEach(viewModel.ideas) { idea in
                IdeaRowView(idea: idea)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedIdea = idea
                    }
            }

            if viewModel.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        Task {
                            await viewModel.loadMore(status: statusFilter, isBusiness: businessFilter)
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

struct IdeaRowView: View {
    let idea: IdeaResponse

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sourceIcon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(idea.title)
                        .font(.headline)
                        .lineLimit(1)

                    if idea.isBusiness == true {
                        Text("Business")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if let category = idea.category, !category.isEmpty {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let priority = idea.priority {
                        HStack(spacing: 1) {
                            ForEach(0..<priority, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
            }

            Spacer()

            Text(idea.ideaStatus.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(idea.ideaStatus.color.opacity(0.15))
                .foregroundStyle(idea.ideaStatus.color)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var sourceIcon: String {
        switch idea.sourceType {
        case "makerworld", "printables":
            return "bookmark"
        default:
            return "lightbulb"
        }
    }
}

@MainActor
final class IdeaListViewModel: ObservableObject {
    @Published var ideas: [IdeaResponse] = []
    @Published var isLoading = false
    @Published var hasMore = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let ideaService = IdeaService()
    private var page = 1

    func load(status: IdeaStatus?, isBusiness: Bool?) async {
        page = 1
        await fetch(status: status, isBusiness: isBusiness, replace: true)
    }

    func loadMore(status: IdeaStatus?, isBusiness: Bool?) async {
        guard hasMore, !isLoading else { return }
        page += 1
        await fetch(status: status, isBusiness: isBusiness, replace: false)
    }

    private func fetch(status: IdeaStatus?, isBusiness: Bool?, replace: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await ideaService.listIdeas(
                status: status,
                isBusiness: isBusiness,
                page: page
            )
            if replace {
                ideas = response.ideas
            } else {
                ideas.append(contentsOf: response.ideas)
            }
            hasMore = response.hasMore ?? false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        IdeaListView()
    }
}
