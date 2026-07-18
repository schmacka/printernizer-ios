import SwiftUI

/// Customer management: list, create, edit, delete.
struct CustomerListView: View {
    @StateObject private var viewModel = CustomerListViewModel()
    @State private var editingCustomer: CustomerResponse?
    @State private var showNewCustomer = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.customers.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.customers.isEmpty {
                ContentUnavailableView {
                    Label("No Customers", systemImage: "person.2")
                } actions: {
                    Button("New Customer") { showNewCustomer = true }
                }
            } else {
                List {
                    ForEach(viewModel.customers) { customer in
                        Button {
                            editingCustomer = customer
                        } label: {
                            customerRow(customer)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        Task { await viewModel.delete(at: indexSet) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Customers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewCustomer = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $showNewCustomer) {
            CustomerFormView {
                Task { await viewModel.load() }
            }
        }
        .sheet(item: $editingCustomer) { customer in
            CustomerFormView(editingCustomer: customer) {
                Task { await viewModel.load() }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func customerRow(_ customer: CustomerResponse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(customer.name)
                    .font(.headline)

                if let email = customer.email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let count = customer.orderCount, count > 0 {
                Text("\(count) orders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct CustomerFormView: View {
    var editingCustomer: CustomerResponse?
    var onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var isEditing: Bool { editingCustomer != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    TextField("Name", text: $name)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Address (optional)", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Customer" : "New Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let customer = editingCustomer {
                    name = customer.name
                    email = customer.email ?? ""
                    phone = customer.phone ?? ""
                    address = customer.address ?? ""
                    notes = customer.notes ?? ""
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let request = CustomerCreateRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            address: address.isEmpty ? nil : address,
            notes: notes.isEmpty ? nil : notes
        )

        do {
            let service = OrderService()
            if let customer = editingCustomer {
                _ = try await service.updateCustomer(id: customer.id, customer: request)
            } else {
                _ = try await service.createCustomer(request)
            }
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

@MainActor
final class CustomerListViewModel: ObservableObject {
    @Published var customers: [CustomerResponse] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let orderService = OrderService()

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            customers = try await orderService.listCustomers()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func delete(at indexSet: IndexSet) async {
        for index in indexSet {
            guard customers.indices.contains(index) else { continue }
            let customer = customers[index]
            do {
                try await orderService.deleteCustomer(id: customer.id)
                customers.removeAll { $0.id == customer.id }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        CustomerListView()
    }
}
