import SwiftUI

/// Idea detail sheet: status changes, source link, edit, delete.
struct IdeaDetailView: View {
    let ideaId: String
    var onChanged: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = IdeaDetailViewModel()
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if let idea = viewModel.idea {
                    ideaContent(idea)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("Idea Not Found", systemImage: "lightbulb")
                }
            }
            .navigationTitle("Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                if viewModel.idea != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Edit") { showEdit = true }
                    }
                }
            }
            .task {
                await viewModel.load(ideaId: ideaId)
            }
            .sheet(isPresented: $showEdit) {
                if let idea = viewModel.idea {
                    IdeaFormView(editingIdea: idea) {
                        Task {
                            await viewModel.load(ideaId: ideaId)
                            onChanged?()
                        }
                    }
                }
            }
            .confirmationDialog("Delete Idea?", isPresented: $showDeleteConfirmation) {
                Button("Delete Idea", role: .destructive) {
                    Task {
                        if await viewModel.delete() {
                            onChanged?()
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    @ViewBuilder
    private func ideaContent(_ idea: IdeaResponse) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection(idea)
                statusSection(idea)
                detailsSection(idea)

                if let notes = idea.materialNotes, !notes.isEmpty {
                    textSection(title: "Material Notes", text: notes)
                }

                if let customer = idea.customerInfo, !customer.isEmpty {
                    textSection(title: "Customer", text: customer)
                }

                deleteButton
            }
            .padding()
        }
    }

    private func headerSection(_ idea: IdeaResponse) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(idea.ideaStatus.displayName)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(idea.ideaStatus.color.opacity(0.15))
                    .foregroundStyle(idea.ideaStatus.color)
                    .clipShape(Capsule())

                if idea.isBusiness == true {
                    Text("Business")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            Text(idea.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if let description = idea.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let sourceUrl = idea.sourceUrl, let url = URL(string: sourceUrl) {
                Link(destination: url) {
                    Label("Open Source Page", systemImage: "safari")
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusSection(_ idea: IdeaResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Move To")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IdeaStatus.allCases.filter { $0 != idea.ideaStatus }) { status in
                        Button {
                            Task {
                                await viewModel.updateStatus(status)
                                onChanged?()
                            }
                        } label: {
                            Text(status.displayName)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(status.color.opacity(0.15))
                                .foregroundStyle(status.color)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailsSection(_ idea: IdeaResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            if let category = idea.category, !category.isEmpty {
                detailRow(label: "Category", value: category)
            }

            if let priority = idea.priority {
                detailRow(label: "Priority", value: String(repeating: "★", count: priority))
            }

            if let minutes = idea.estimatedPrintTime, minutes > 0 {
                detailRow(label: "Est. Print Time", value: Formatters.duration(minutes: minutes))
            }

            if let planned = idea.plannedDate, !planned.isEmpty {
                detailRow(label: "Planned", value: planned)
            }

            if let tags = idea.tags, !tags.isEmpty {
                detailRow(label: "Tags", value: tags.joined(separator: ", "))
            }

            if let sourceType = idea.sourceType, sourceType != "manual" {
                detailRow(label: "Source", value: sourceType.capitalized)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func textSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete Idea", systemImage: "trash")
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
                .multilineTextAlignment(.trailing)
        }
    }
}

@MainActor
final class IdeaDetailViewModel: ObservableObject {
    @Published var idea: IdeaResponse?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let ideaService = IdeaService()

    func load(ideaId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            idea = try await ideaService.getIdea(id: ideaId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func updateStatus(_ status: IdeaStatus) async {
        guard let idea else { return }
        do {
            try await ideaService.updateStatus(id: idea.id, status: status)
            await load(ideaId: idea.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func delete() async -> Bool {
        guard let idea else { return false }
        do {
            try await ideaService.deleteIdea(id: idea.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
}

#Preview {
    IdeaDetailView(ideaId: "idea-1")
}
