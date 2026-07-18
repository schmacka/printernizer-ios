import SwiftUI

/// Manages server-side notification channels (Discord/Slack/ntfy),
/// reached from Settings. Local on-device notifications are separate.
struct NotificationChannelsView: View {
    @StateObject private var viewModel = NotificationChannelsViewModel()
    @State private var editingChannel: NotificationChannel?
    @State private var showNewChannel = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.channels.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.channels.isEmpty {
                ContentUnavailableView {
                    Label("No Channels", systemImage: "bell.badge")
                } description: {
                    Text("Send server notifications to Discord, Slack, or ntfy.")
                } actions: {
                    Button("Add Channel") { showNewChannel = true }
                }
            } else {
                List {
                    ForEach(viewModel.channels) { channel in
                        Button {
                            editingChannel = channel
                        } label: {
                            channelRow(channel)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(channel) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                Task { await viewModel.test(channel) }
                            } label: {
                                Label("Test", systemImage: "paperplane")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Notification Channels")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewChannel = true
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
        .sheet(isPresented: $showNewChannel) {
            NotificationChannelFormView(eventTypes: viewModel.eventTypes) {
                Task { await viewModel.load() }
            }
        }
        .sheet(item: $editingChannel) { channel in
            NotificationChannelFormView(editingChannel: channel, eventTypes: viewModel.eventTypes) {
                Task { await viewModel.load() }
            }
        }
        .alert("Notification", isPresented: $viewModel.showMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.message)
        }
    }

    private func channelRow(_ channel: NotificationChannel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(channel.channelType.displayName)
                    Text("·")
                    Text("\(channel.subscribedEvents.count) events")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if !channel.isEnabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Create/edit form for a notification channel with per-event toggles.
struct NotificationChannelFormView: View {
    var editingChannel: NotificationChannel?
    let eventTypes: [NotificationEventType]
    var onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var channelType: NotificationChannelType = .discord
    @State private var webhookUrl = ""
    @State private var topic = ""
    @State private var isEnabled = true
    @State private var subscribedEvents: Set<String> = []
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var isEditing: Bool { editingChannel != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Channel") {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $channelType) {
                        ForEach(NotificationChannelType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .disabled(isEditing)

                    TextField(channelType.urlFieldLabel, text: $webhookUrl)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    if channelType == .ntfy {
                        TextField("Topic", text: $topic)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }

                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section("Events") {
                    ForEach(eventTypes) { event in
                        Toggle(
                            event.label ?? event.id,
                            isOn: Binding(
                                get: { subscribedEvents.contains(event.id) },
                                set: { enabled in
                                    if enabled {
                                        subscribedEvents.insert(event.id)
                                    } else {
                                        subscribedEvents.remove(event.id)
                                    }
                                }
                            )
                        )
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Channel" : "New Channel")
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
                    .disabled(isSaving || name.isEmpty || webhookUrl.isEmpty || (channelType == .ntfy && topic.isEmpty))
                }
            }
            .onAppear {
                if let channel = editingChannel {
                    name = channel.name
                    channelType = channel.channelType
                    webhookUrl = channel.webhookUrl
                    topic = channel.topic ?? ""
                    isEnabled = channel.isEnabled
                    subscribedEvents = Set(channel.subscribedEvents)
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

        let service = NotificationChannelService()
        do {
            if let channel = editingChannel {
                _ = try await service.updateChannel(id: channel.id, update: ChannelUpdateRequest(
                    name: name,
                    webhookUrl: webhookUrl,
                    topic: channelType == .ntfy ? topic : nil,
                    isEnabled: isEnabled
                ))
                try await service.updateSubscriptions(id: channel.id, events: Array(subscribedEvents))
            } else {
                _ = try await service.createChannel(ChannelCreateRequest(
                    name: name,
                    channelType: channelType,
                    webhookUrl: webhookUrl,
                    topic: channelType == .ntfy ? topic : nil,
                    isEnabled: isEnabled,
                    subscribedEvents: Array(subscribedEvents)
                ))
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
final class NotificationChannelsViewModel: ObservableObject {
    @Published var channels: [NotificationChannel] = []
    @Published var eventTypes: [NotificationEventType] = []
    @Published var isLoading = false
    @Published var showMessage = false
    @Published var message = ""

    private let service = NotificationChannelService()

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            channels = try await service.listChannels()
            if eventTypes.isEmpty {
                eventTypes = try await service.listEventTypes()
            }
        } catch {
            message = error.localizedDescription
            showMessage = true
        }
    }

    func delete(_ channel: NotificationChannel) async {
        do {
            try await service.deleteChannel(id: channel.id)
            channels.removeAll { $0.id == channel.id }
        } catch {
            message = error.localizedDescription
            showMessage = true
        }
    }

    func test(_ channel: NotificationChannel) async {
        do {
            try await service.testChannel(id: channel.id)
            message = "Test notification sent to \(channel.name)."
        } catch {
            message = "Test failed: \(error.localizedDescription)"
        }
        showMessage = true
    }
}

#Preview {
    NavigationStack {
        NotificationChannelsView()
    }
}
