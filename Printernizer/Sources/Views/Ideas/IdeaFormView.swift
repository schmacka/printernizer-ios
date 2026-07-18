import SwiftUI

/// Create/edit form for ideas. Pasting a MakerWorld/Printables/etc.
/// URL previews the page metadata and imports through the backend.
struct IdeaFormView: View {
    var editingIdea: IdeaResponse?
    var onSaved: (() -> Void)?

    @StateObject private var viewModel = IdeaFormViewModel()
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { editingIdea != nil }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section("Import from URL (optional)") {
                        TextField("Model page URL", text: $viewModel.importUrl)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        if !viewModel.importUrl.isEmpty {
                            Button {
                                Task { await viewModel.previewUrl() }
                            } label: {
                                if viewModel.isPreviewing {
                                    ProgressView()
                                } else {
                                    Label("Fetch Title & Details", systemImage: "sparkle.magnifyingglass")
                                }
                            }
                            .disabled(viewModel.isPreviewing)

                            if let platform = viewModel.detectedPlatform {
                                Label(platform.capitalized, systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                Section("Idea") {
                    TextField("Title", text: $viewModel.title)

                    TextField("Description (optional)", text: $viewModel.descriptionText, axis: .vertical)
                        .lineLimit(3...6)

                    TextField("Category (optional)", text: $viewModel.category)

                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(1...5, id: \.self) { level in
                            Text(String(repeating: "★", count: level)).tag(level)
                        }
                    }
                }

                Section("Planning") {
                    LabeledContent("Est. Print Time (min)") {
                        TextField("0", value: $viewModel.estimatedPrintTime, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Toggle("Has Planned Date", isOn: $viewModel.hasPlannedDate)

                    if viewModel.hasPlannedDate {
                        DatePicker("Planned", selection: $viewModel.plannedDate, displayedComponents: .date)
                    }

                    TextField("Material Notes (optional)", text: $viewModel.materialNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Business") {
                    Toggle("Business Idea", isOn: $viewModel.isBusiness)

                    if viewModel.isBusiness {
                        TextField("Customer Info", text: $viewModel.customerInfo)
                    }
                }

                Section("Tags") {
                    TextField("Tags (comma-separated)", text: $viewModel.tagsText)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle(isEditing ? "Edit Idea" : "New Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save(editingIdea: editingIdea) {
                                onSaved?()
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let idea = editingIdea {
                    viewModel.prefill(from: idea)
                }
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
final class IdeaFormViewModel: ObservableObject {
    @Published var importUrl = ""
    @Published var detectedPlatform: String?
    @Published var title = ""
    @Published var descriptionText = ""
    @Published var category = ""
    @Published var priority = 3
    @Published var estimatedPrintTime: Int?
    @Published var hasPlannedDate = false
    @Published var plannedDate = Date()
    @Published var materialNotes = ""
    @Published var isBusiness = false
    @Published var customerInfo = ""
    @Published var tagsText = ""

    @Published var isPreviewing = false
    @Published var isSaving = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let ideaService = IdeaService()

    func prefill(from idea: IdeaResponse) {
        title = idea.title
        descriptionText = idea.description ?? ""
        category = idea.category ?? ""
        priority = idea.priority ?? 3
        estimatedPrintTime = idea.estimatedPrintTime
        materialNotes = idea.materialNotes ?? ""
        isBusiness = idea.isBusiness ?? false
        customerInfo = idea.customerInfo ?? ""
        tagsText = (idea.tags ?? []).joined(separator: ", ")
        if let planned = idea.plannedDate, let date = Formatters.parseISODate(planned) {
            hasPlannedDate = true
            plannedDate = date
        }
    }

    func previewUrl() async {
        isPreviewing = true
        defer { isPreviewing = false }

        do {
            let response = try await ideaService.previewUrl(importUrl)
            if let preview = response.preview {
                if title.isEmpty, let previewTitle = preview.title {
                    title = previewTitle
                }
                detectedPlatform = preview.platform
            }
        } catch {
            errorMessage = "Could not read that URL. You can still save the idea manually."
            showError = true
        }
    }

    func save(editingIdea: IdeaResponse?) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        do {
            if let idea = editingIdea {
                try await ideaService.updateIdea(id: idea.id, update: IdeaUpdateRequest(
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: descriptionText.isEmpty ? nil : descriptionText,
                    category: category.isEmpty ? nil : category,
                    priority: priority,
                    isBusiness: isBusiness,
                    estimatedPrintTime: estimatedPrintTime,
                    materialNotes: materialNotes.isEmpty ? nil : materialNotes,
                    customerInfo: customerInfo.isEmpty ? nil : customerInfo,
                    plannedDate: plannedDateString,
                    tags: tags
                ))
            } else if !importUrl.trimmingCharacters(in: .whitespaces).isEmpty {
                try await ideaService.importIdea(IdeaImportRequest(
                    url: importUrl.trimmingCharacters(in: .whitespaces),
                    title: title.isEmpty ? nil : title,
                    description: descriptionText.isEmpty ? nil : descriptionText,
                    category: category.isEmpty ? nil : category,
                    priority: priority,
                    isBusiness: isBusiness,
                    tags: tags
                ))
            } else {
                try await ideaService.createIdea(IdeaCreateRequest(
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: descriptionText.isEmpty ? nil : descriptionText,
                    category: category.isEmpty ? nil : category,
                    priority: priority,
                    isBusiness: isBusiness,
                    estimatedPrintTime: estimatedPrintTime,
                    materialNotes: materialNotes.isEmpty ? nil : materialNotes,
                    customerInfo: customerInfo.isEmpty ? nil : customerInfo,
                    plannedDate: plannedDateString,
                    tags: tags
                ))
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    private var plannedDateString: String? {
        guard hasPlannedDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: plannedDate)
    }
}

#Preview {
    IdeaFormView()
}
