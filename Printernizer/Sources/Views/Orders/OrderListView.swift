import SwiftUI

/// Customer order list, shown inside the Jobs tab (Jobs | Orders
/// segmented control). Expects an enclosing NavigationStack.
struct OrderListView: View {
    @StateObject private var viewModel = OrderListViewModel()
    @State private var selectedStatus: OrderStatus?
    @State private var selectedOrder: OrderResponse?
    @State private var showNewOrder = false
    @State private var showCustomers = false
    @State private var showSources = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.orders.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.orders.isEmpty {
                ContentUnavailableView {
                    Label("No Orders", systemImage: "shippingbox")
                } description: {
                    Text("Customer orders will appear here.")
                } actions: {
                    Button("New Order") { showNewOrder = true }
                }
            } else {
                orderList
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewOrder = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $selectedStatus) {
                        Text("All Orders").tag(OrderStatus?.none)
                        ForEach(OrderStatus.allCases) { status in
                            Text(status.displayName).tag(OrderStatus?.some(status))
                        }
                    }

                    Divider()

                    Button {
                        showCustomers = true
                    } label: {
                        Label("Customers", systemImage: "person.2")
                    }

                    Button {
                        showSources = true
                    } label: {
                        Label("Order Sources", systemImage: "tray.2")
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onChange(of: selectedStatus) { _, newValue in
            Task { await viewModel.load(status: newValue) }
        }
        .refreshable {
            await viewModel.load(status: selectedStatus)
        }
        .task {
            guard APIConfiguration.isConfigured else { return }
            await viewModel.load(status: selectedStatus)
        }
        .sheet(item: $selectedOrder) { order in
            OrderDetailView(orderId: order.id) {
                Task { await viewModel.load(status: selectedStatus) }
            }
        }
        .sheet(isPresented: $showNewOrder) {
            OrderFormView {
                Task { await viewModel.load(status: selectedStatus) }
            }
        }
        .navigationDestination(isPresented: $showCustomers) {
            CustomerListView()
        }
        .navigationDestination(isPresented: $showSources) {
            OrderSourcesView()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var orderList: some View {
        List {
            ForEach(viewModel.orders) { order in
                OrderRowView(order: order)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedOrder = order
                    }
            }
        }
        .listStyle(.plain)
    }
}

struct OrderRowView: View {
    let order: OrderResponse

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(order.status.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(order.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let customer = order.customer?.name {
                        Text(customer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let due = order.dueDate, !due.isEmpty {
                        Label(due, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(order.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(order.status.color.opacity(0.15))
                    .foregroundStyle(order.status.color)
                    .clipShape(Capsule())

                if let price = order.quotedPrice, price > 0 {
                    Text(Formatters.eurString(price))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
final class OrderListViewModel: ObservableObject {
    @Published var orders: [OrderResponse] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let orderService = OrderService()

    func load(status: OrderStatus?) async {
        isLoading = true
        defer { isLoading = false }

        do {
            orders = try await orderService.listOrders(status: status)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        OrderListView()
    }
}
