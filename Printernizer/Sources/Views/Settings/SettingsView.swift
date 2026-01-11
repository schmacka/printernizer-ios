import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var apiService: APIService
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("refreshInterval") private var refreshInterval = 5.0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    @State private var isTesting = false
    @State private var connectionStatus: ConnectionStatus?
    @State private var showQRScanner = false

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
                    TextField("Server URL", text: $serverURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: serverURL) { _, newValue in
                            apiService.baseURL = newValue
                            connectionStatus = nil
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
                        .disabled(isTesting || serverURL.isEmpty)

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
                        Toggle("Print Completed", isOn: .constant(true))
                        Toggle("Print Failed", isOn: .constant(true))
                        Toggle("Printer Offline", isOn: .constant(true))
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")

                    Link("View on GitHub", destination: URL(string: "https://github.com/printernizer")!)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { scannedURL in
                    serverURL = scannedURL
                    apiService.baseURL = scannedURL
                    connectionStatus = nil
                }
            }
        }
    }

    private func testConnection() async {
        isTesting = true
        connectionStatus = nil

        do {
            let success = try await apiService.testConnection()
            connectionStatus = success ? .success : .failure("Server not responding")
        } catch {
            connectionStatus = .failure(error.localizedDescription)
        }

        isTesting = false
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIService())
}
