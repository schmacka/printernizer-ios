import SwiftUI

/// Order detail sheet: status flow, payment, costs, linked jobs and
/// attached library files.
struct OrderDetailView: View {
    let orderId: String
    var onChanged: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OrderDetailViewModel()
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false
    @State private var showLinkJob = false
    @State private var showAttachFile = false

    var body: some View {
        NavigationStack {
            Group {
                if let order = viewModel.order {
                    orderContent(order)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("Order Not Found", systemImage: "shippingbox")
                }
            }
            .navigationTitle("Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                if viewModel.order != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Edit") { showEdit = true }
                    }
                }
            }
            .task {
                await viewModel.load(orderId: orderId)
            }
            .sheet(isPresented: $showEdit) {
                if let order = viewModel.order {
                    OrderFormView(editingOrder: order) {
                        Task {
                            await viewModel.load(orderId: orderId)
                            onChanged?()
                        }
                    }
                }
            }
            .sheet(isPresented: $showLinkJob) {
                LinkJobPickerView { jobId in
                    Task {
                        await viewModel.linkJob(jobId: jobId)
                        onChanged?()
                    }
                }
            }
            .sheet(isPresented: $showAttachFile) {
                AttachLibraryFilePickerView { file in
                    Task {
                        await viewModel.attachFile(file)
                        onChanged?()
                    }
                }
            }
            .confirmationDialog("Delete Order?", isPresented: $showDeleteConfirmation) {
                Button("Delete Order", role: .destructive) {
                    Task {
                        if await viewModel.deleteOrder() {
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
    private func orderContent(_ order: OrderResponse) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection(order)
                detailsSection(order)
                costsSection(order)

                jobsSection(order)
                filesSection(order)

                if let notes = order.notes, !notes.isEmpty {
                    notesSection(notes)
                }

                actionsSection(order)
            }
            .padding()
        }
    }

    private func headerSection(_ order: OrderResponse) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(order.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(order.status.color.opacity(0.15))
                    .foregroundStyle(order.status.color)
                    .clipShape(Capsule())

                if let payment = order.paymentStatus {
                    Text(payment.displayName)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(payment.color.opacity(0.15))
                        .foregroundStyle(payment.color)
                        .clipShape(Capsule())
                }
            }

            Text(order.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if let next = order.status.next {
                Button {
                    Task {
                        await viewModel.advanceStatus(to: next)
                        onChanged?()
                    }
                } label: {
                    Label("Mark as \(next.displayName)", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailsSection(_ order: OrderResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            if let customer = order.customer {
                detailRow(label: "Customer", value: customer.name)
            }

            if let source = order.source {
                detailRow(label: "Source", value: source.name)
            }

            if let due = order.dueDate, !due.isEmpty {
                detailRow(label: "Due Date", value: due)
            }

            if let created = Formatters.mediumDateTime(order.createdAt) {
                detailRow(label: "Created", value: created)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func costsSection(_ order: OrderResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pricing")
                .font(.headline)

            if let price = order.quotedPrice {
                detailRow(label: "Quoted Price", value: Formatters.eurString(price))
            }

            if let material = order.materialCostEur, material > 0 {
                detailRow(label: "Material Cost", value: Formatters.eurString(material))
            }

            if let energy = order.energyCostEur, energy > 0 {
                detailRow(label: "Energy Cost", value: Formatters.eurString(energy))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func jobsSection(_ order: OrderResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Linked Jobs")
                    .font(.headline)

                Spacer()

                Button {
                    showLinkJob = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }

            if let jobs = order.jobs, !jobs.isEmpty {
                ForEach(jobs) { job in
                    HStack {
                        Text(job.displayName)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        if let status = job.status {
                            Text(status.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) {
                            Task {
                                await viewModel.unlinkJob(jobId: job.id)
                                onChanged?()
                            }
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text("No jobs linked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func filesSection(_ order: OrderResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Attached Files")
                    .font(.headline)

                Spacer()

                Button {
                    showAttachFile = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }

            if let files = order.files, !files.isEmpty {
                ForEach(files) { file in
                    HStack {
                        Image(systemName: "doc")
                            .foregroundStyle(.secondary)

                        Text(file.filename)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        Button(role: .destructive) {
                            Task {
                                await viewModel.detachFile(orderFileId: file.id)
                                onChanged?()
                            }
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text("No files attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)

            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func actionsSection(_ order: OrderResponse) -> some View {
        VStack(spacing: 12) {
            if order.status != .cancelled {
                Button(role: .destructive) {
                    Task {
                        await viewModel.advanceStatus(to: .cancelled)
                        onChanged?()
                    }
                } label: {
                    Label("Cancel Order", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange.opacity(0.1))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Order", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

@MainActor
final class OrderDetailViewModel: ObservableObject {
    @Published var order: OrderResponse?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let orderService = OrderService()

    func load(orderId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            order = try await orderService.getOrder(id: orderId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func advanceStatus(to status: OrderStatus) async {
        guard let order else { return }
        do {
            self.order = try await orderService.updateOrder(
                id: order.id,
                update: OrderUpdateRequest(status: status)
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteOrder() async -> Bool {
        guard let order else { return false }
        do {
            try await orderService.deleteOrder(id: order.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    func linkJob(jobId: String) async {
        guard let order else { return }
        do {
            try await orderService.linkJob(orderId: order.id, jobId: jobId)
            await load(orderId: order.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func unlinkJob(jobId: String) async {
        guard let order else { return }
        do {
            try await orderService.unlinkJob(orderId: order.id, jobId: jobId)
            await load(orderId: order.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func attachFile(_ file: LibraryFile) async {
        guard let order else { return }
        do {
            try await orderService.attachLibraryFile(
                orderId: order.id,
                fileChecksum: file.checksum,
                filename: file.filename
            )
            await load(orderId: order.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func detachFile(orderFileId: String) async {
        guard let order else { return }
        do {
            try await orderService.detachFile(orderId: order.id, orderFileId: orderFileId)
            await load(orderId: order.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    OrderDetailView(orderId: "order-1")
}
