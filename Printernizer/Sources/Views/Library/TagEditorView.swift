import SwiftUI

/// Assign/remove tags on a library file, with inline tag creation.
struct TagEditorView: View {
    let checksum: String
    var onChanged: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TagEditorViewModel()
    @State private var newTagName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New tag name", text: $newTagName)
                            .autocapitalization(.none)

                        Button("Create") {
                            Task {
                                await viewModel.createAndAssign(name: newTagName, checksum: checksum)
                                newTagName = ""
                                onChanged?()
                            }
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Tags") {
                    if viewModel.allTags.isEmpty && !viewModel.isLoading {
                        Text("No tags yet — create one above.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.allTags) { tag in
                        Button {
                            Task {
                                await viewModel.toggle(tag: tag, checksum: checksum)
                                onChanged?()
                            }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: tag.color ?? "") ?? .gray)
                                    .frame(width: 12, height: 12)

                                Text(tag.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if viewModel.assignedTagIds.contains(tag.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.load(checksum: checksum)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

@MainActor
final class TagEditorViewModel: ObservableObject {
    @Published var allTags: [TagResponse] = []
    @Published var assignedTagIds: Set<String> = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let tagService = TagService()

    func load(checksum: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            allTags = try await tagService.listTags()
            assignedTagIds = Set(try await tagService.fileTags(checksum: checksum).map(\.id))
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func toggle(tag: TagResponse, checksum: String) async {
        do {
            if assignedTagIds.contains(tag.id) {
                try await tagService.removeTags(checksum: checksum, tagIds: [tag.id])
                assignedTagIds.remove(tag.id)
            } else {
                try await tagService.assignTags(checksum: checksum, tagIds: [tag.id])
                assignedTagIds.insert(tag.id)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func createAndAssign(name: String, checksum: String) async {
        do {
            let tag = try await tagService.createTag(name: name.trimmingCharacters(in: .whitespaces))
            allTags.append(tag)
            try await tagService.assignTags(checksum: checksum, tagIds: [tag.id])
            assignedTagIds.insert(tag.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    TagEditorView(checksum: "abc123")
}
