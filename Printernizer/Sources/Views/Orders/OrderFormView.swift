import SwiftUI

/// Create/edit form for customer orders.
struct OrderFormView: View {
    var editingOrder: OrderResponse?
    var onSaved: (() -> Void)?

    @StateObject private var viewModel = OrderFormViewModel()
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { editingOrder != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Order") {
                    TextField("Title", text: $viewModel.title)

                    Picker("Customer", selection: $viewModel.customerId) {
                        Text("None").tag(String?.none)
                        ForEach(viewModel.customers) { customer in
                            Text(customer.name).tag(String?.some(customer.id))
                        }
                    }

                    Picker("Source", selection: $viewModel.sourceId) {
                        Text("None").tag(String?.none)
                        ForEach(viewModel.sources) { source in
                            Text(source.name).tag(String?.some(source.id))
                        }
                    }
                }

                Section("Payment") {
                    LabeledContent("Quoted Price (€)") {
                        TextField("0.00", value: $viewModel.quotedPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Payment Status", selection: $viewModel.paymentStatus) {
                        ForEach(PaymentStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                }

                Section("Due Date") {
                    Toggle("Has Due Date", isOn: $viewModel.hasDueDate)

                    if viewModel.hasDueDate {
                        DatePicker("Due", selection: $viewModel.dueDate, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Order" : "New Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save(editingOrder: editingOrder) {
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
            .task {
                await viewModel.loadPickers()
                if let order = editingOrder {
                    viewModel.prefill(from: order)
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
final class OrderFormViewModel: ObservableObject {
    @Published var title = ""
    @Published var customerId: String?
    @Published var sourceId: String?
    @Published var quotedPrice: Double?
    @Published var paymentStatus: PaymentStatus = .unpaid
    @Published var hasDueDate = false
    @Published var dueDate = Date()
    @Published var notes = ""

    @Published var customers: [CustomerResponse] = []
    @Published var sources: [OrderSourceResponse] = []

    @Published var isSaving = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let orderService = OrderService()

    func loadPickers() async {
        customers = (try? await orderService.listCustomers()) ?? []
        sources = (try? await orderService.listOrderSources()) ?? []
    }

    func prefill(from order: OrderResponse) {
        title = order.title
        customerId = order.customerId
        sourceId = order.sourceId
        quotedPrice = order.quotedPrice
        paymentStatus = order.paymentStatus ?? .unpaid
        notes = order.notes ?? ""
        if let due = order.dueDate,
           let date = Formatters.parseISODate(due) ?? parseDateOnly(due) {
            hasDueDate = true
            dueDate = date
        }
    }

    func save(editingOrder: OrderResponse?) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            if let order = editingOrder {
                let update = OrderUpdateRequest(
                    title: title.trimmingCharacters(in: .whitespaces),
                    customerId: customerId,
                    sourceId: sourceId,
                    quotedPrice: quotedPrice,
                    paymentStatus: paymentStatus,
                    notes: notes.isEmpty ? nil : notes,
                    dueDate: dueDateString
                )
                _ = try await orderService.updateOrder(id: order.id, update: update)
            } else {
                let create = OrderCreateRequest(
                    title: title.trimmingCharacters(in: .whitespaces),
                    customerId: customerId,
                    sourceId: sourceId,
                    quotedPrice: quotedPrice,
                    paymentStatus: paymentStatus,
                    notes: notes.isEmpty ? nil : notes,
                    dueDate: dueDateString
                )
                _ = try await orderService.createOrder(create)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    private var dueDateString: String? {
        guard hasDueDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: dueDate)
    }

    private func parseDateOnly(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

#Preview {
    OrderFormView()
}
