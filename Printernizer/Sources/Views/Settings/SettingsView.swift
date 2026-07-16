import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var apiService: APIService
    @EnvironmentObject private var webSocketService: WebSocketService
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("refreshInterval") private var refreshInterval = 5.0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notifyPrintCompleted") private var notifyPrintCompleted = true
    @AppStorage("notifyPrintFailed") private var notifyPrintFailed = true
    @AppStorage("notifyPrinterOffline") private var notifyPrinterOffline = true

    @State private var isTesting = false
    @State private var connectionStatus: ConnectionStatus?
    @State private var showQRScanner = false
    @State private var serverInfo: SystemInfo?

    /// Local draft of the server URL. The TextField edits this instead of
    /// the stored value so that typing doesn't publish through APIService
    /// and re-render every tab on each keystroke; the draft is committed
    /// when editing ends (submit or focus loss).
    @State private var serverURLDraft = ""
    @FocusState private var serverURLFieldFocused: Bool

    enum ConnectionStatus {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Server URL", text: $serverURLDraft)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($serverURLFieldFocused)
                        .onChange(of: serverURLDraft) { _, _ in
                            connectionStatus = nil
                            serverInfo = nil
                        }
                        .onSubmit {
                            serverURLFieldFocused = false
                        }

                    Button {
                        showQRScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }

                    HStack {
                        Button {
                            Task {
                                await testConnection()
                            }
                        } label: {
                            HStack {
                                if isTesting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Test Connection")
                                }
                            }
                        }
                        .disabled(isTesting || serverURLDraft.isEmpty)

                        Spacer()

                        if let status = connectionStatus {
                            Image(systemName: status.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(status.isSuccess ? .green : .red)
                        }
                    }

                    if case .failure(let message) = connectionStatus {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let info = serverInfo {
                    Section("Server Info") {
                        if let version = info.version {
                            LabeledContent("Backend Version", value: version)
                        }
                        if let environment = info.environment {
                            LabeledContent("Environment", value: environment)
                        }
                        if let timezone = info.timezone {
                            LabeledContent("Timezone", value: timezone)
                        }
                        if let uptime = info.uptimeSeconds {
                            LabeledContent("Uptime", value: formatUptime(uptime))
                        }
                    }
                }

                Section("Refresh") {
                    Picker("Refresh Interval", selection: $refreshInterval) {
                        Text("1 second").tag(1.0)
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                        Text("30 seconds").tag(30.0)
                    }
                }

                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)

                    if notificationsEnabled {
                        Toggle("Print Completed", isOn: $notifyPrintCompleted)
                        Toggle("Print Failed", isOn: $notifyPrintFailed)
                        Toggle("Printer Offline", isOn: $notifyPrinterOffline)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)

                    Link("View on GitHub", destination: URL(string: "https://github.com/schmacka/printernizer-ios")!)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                serverURLDraft = serverURL
            }
            .onChange(of: serverURLFieldFocused) { _, focused in
                if !focused {
                    commitServerURL()
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { scannedURL in
                    serverURLDraft = scannedURL
                    serverURL = scannedURL
                    apiService.baseURL = scannedURL
                    connectionStatus = nil
                    reconnectWebSocket()
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    private func formatUptime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours >= 24 {
            return "\(hours / 24)d \(hours % 24)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Persists the edited server URL and reconnects the WebSocket.
    /// Called when editing ends; a no-op when the URL didn't change.
    private func commitServerURL() {
        let trimmed = serverURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != serverURL else { return }
        serverURL = trimmed
        apiService.baseURL = trimmed
        connectionStatus = nil
        serverInfo = nil
        reconnectWebSocket()
    }

    /// Reconnects the WebSocket only when the configured URL is usable;
    /// connecting with a malformed URL must never be attempted.
    private func reconnectWebSocket() {
        guard APIConfiguration.isConfigured else {
            webSocketService.disconnect()
            return
        }
        webSocketService.connect()
    }

    private func testConnection() async {
        serverURLFieldFocused = false
        commitServerURL()

        isTesting = true
        connectionStatus = nil

        do {
            let success = try await apiService.testConnection()
            connectionStatus = success ? .success : .failure("Server not responding")
            if success {
                serverInfo = try? await apiService.fetchSystemInfo()
                reconnectWebSocket()
            }
        } catch {
            connectionStatus = .failure(error.localizedDescription)
        }

        isTesting = false
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIService())
        .environmentObject(WebSocketService())
}
