import SwiftUI
import UIKit

/// Create/edit form for filament spools. When editing, only the
/// fields the backend allows to change are shown (remaining weight,
/// cost, color hex, location, notes, active flag).
struct MaterialFormView: View {
    var editingMaterial: MaterialResponse?
    var onSaved: (() -> Void)?

    @StateObject private var viewModel = MaterialFormViewModel()
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { editingMaterial != nil }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section("Material") {
                        Picker("Type", selection: $viewModel.materialType) {
                            ForEach(viewModel.availableTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }

                        Picker("Brand", selection: $viewModel.brand) {
                            ForEach(viewModel.availableBrands, id: \.self) { brand in
                                Text(brand.capitalized).tag(brand)
                            }
                        }

                        Picker("Color", selection: $viewModel.color) {
                            ForEach(viewModel.availableColors, id: \.self) { color in
                                Text(color.capitalized).tag(color)
                            }
                        }

                        Picker("Diameter", selection: $viewModel.diameter) {
                            Text("1.75 mm").tag(1.75)
                            Text("2.85 mm").tag(2.85)
                        }
                    }

                    Section("Weight") {
                        LabeledContent("Spool Weight (kg)") {
                            TextField("1.0", value: $viewModel.weight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }

                        LabeledContent("Remaining (kg)") {
                            TextField("1.0", value: $viewModel.remainingWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } else {
                    Section("Stock") {
                        LabeledContent("Remaining (kg)") {
                            TextField("0.0", value: $viewModel.remainingWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Cost & Details") {
                    LabeledContent("Price per kg (€)") {
                        TextField("0.00", value: $viewModel.costPerKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if !isEditing {
                        TextField("Vendor", text: $viewModel.vendor)
                        TextField("Batch Number (optional)", text: $viewModel.batchNumber)
                    }

                    TextField("Location (optional)", text: $viewModel.location)

                    ColorPicker("Spool Color", selection: $viewModel.displayColor, supportsOpacity: false)
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Toggle("Active", isOn: $viewModel.isActive)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Material" : "Add Material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save(editingMaterial: editingMaterial) {
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
                    .disabled(viewModel.isSaving || !viewModel.isValid(isEditing: isEditing))
                }
            }
            .task {
                await viewModel.loadTypes()
                if let material = editingMaterial {
                    viewModel.prefill(from: material)
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
final class MaterialFormViewModel: ObservableObject {
    @Published var materialType = "PLA"
    @Published var brand = "OTHER"
    @Published var color = "BLACK"
    @Published var diameter = 1.75
    @Published var weight: Double? = 1.0
    @Published var remainingWeight: Double? = 1.0
    @Published var costPerKg: Double?
    @Published var vendor = ""
    @Published var batchNumber = ""
    @Published var location = ""
    @Published var notes = ""
    @Published var displayColor: Color = .black
    @Published var isActive = true

    @Published var availableTypes: [String] = ["PLA", "PETG", "TPU", "ABS", "ASA", "NYLON", "PC", "OTHER"]
    @Published var availableBrands: [String] = ["OVERTURE", "PRUSAMENT", "BAMBU", "POLYMAKER", "ESUN", "OTHER"]
    @Published var availableColors: [String] = ["BLACK", "WHITE", "GREY", "RED", "BLUE", "GREEN", "YELLOW", "ORANGE", "PURPLE", "PINK", "TRANSPARENT", "NATURAL", "OTHER"]

    @Published var isSaving = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let materialService = MaterialService()
    private var hasCustomColor = false

    func isValid(isEditing: Bool) -> Bool {
        if isEditing {
            return remainingWeight != nil
        }
        guard let weight, weight > 0,
              let remaining = remainingWeight, remaining >= 0, remaining <= weight else {
            return false
        }
        return !vendor.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func loadTypes() async {
        do {
            let types = try await materialService.getTypes()
            if !types.types.isEmpty { availableTypes = types.types }
            if !types.brands.isEmpty { availableBrands = types.brands }
            if !types.colors.isEmpty { availableColors = types.colors }
        } catch {
            // Fall back to the built-in enum values.
        }
    }

    func prefill(from material: MaterialResponse) {
        materialType = material.materialType
        brand = material.brand
        color = material.color
        diameter = material.diameter
        weight = material.weight
        remainingWeight = material.remainingWeight
        costPerKg = material.costPerKg > 0 ? material.costPerKg : nil
        vendor = material.vendor
        batchNumber = material.batchNumber ?? ""
        location = material.location ?? ""
        notes = material.notes ?? ""
        isActive = material.isActive
        if let hex = material.colorHex, let parsed = Color(hex: hex) {
            displayColor = parsed
            hasCustomColor = true
        }
    }

    func save(editingMaterial: MaterialResponse?) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            if let material = editingMaterial {
                let update = MaterialUpdateRequest(
                    remainingWeight: remainingWeight,
                    costPerKg: costPerKg,
                    notes: notes.isEmpty ? nil : notes,
                    colorHex: colorHexString,
                    location: location.isEmpty ? nil : location,
                    isActive: isActive
                )
                _ = try await materialService.updateMaterial(id: material.id, update: update)
            } else {
                let create = MaterialCreateRequest(
                    materialType: materialType,
                    brand: brand,
                    color: color,
                    diameter: diameter,
                    weight: weight ?? 1.0,
                    remainingWeight: remainingWeight ?? weight ?? 1.0,
                    costPerKg: costPerKg ?? 0,
                    vendor: vendor.trimmingCharacters(in: .whitespaces),
                    batchNumber: batchNumber.isEmpty ? nil : batchNumber,
                    notes: notes.isEmpty ? nil : notes,
                    colorHex: colorHexString,
                    location: location.isEmpty ? nil : location,
                    isActive: true
                )
                _ = try await materialService.createMaterial(create)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    /// Hex string of the picked color, e.g. "#FF5733".
    private var colorHexString: String? {
        guard let components = UIColor(displayColor).cgColor.components,
              components.count >= 3 else { return nil }
        let r = Int(round(components[0] * 255))
        let g = Int(round(components[1] * 255))
        let b = Int(round(components[2] * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#Preview {
    MaterialFormView()
}
