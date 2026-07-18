import SwiftUI

/// Camera troubleshooting report for a printer.
struct CameraDiagnosticsView: View {
    let printerId: String

    @State private var diagnostics: CameraDiagnostics?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let cameraService = CameraService()

    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Running diagnostics…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let diagnostics {
                Section("Printer") {
                    if let type = diagnostics.printerType {
                        LabeledContent("Driver", value: type)
                    }
                    if let ip = diagnostics.printerIp {
                        LabeledContent("IP Address", value: ip)
                    }
                }

                Section("Tests") {
                    if let tests = diagnostics.tests, !tests.isEmpty {
                        ForEach(tests.keys.sorted(), id: \.self) { key in
                            if let test = tests[key] {
                                testRow(test)
                            }
                        }
                    } else if let error = diagnostics.error {
                        Text(error)
                            .foregroundStyle(.red)
                    } else {
                        Text("No test results")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Camera Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
    }

    private func testRow(_ test: CameraDiagnostics.DiagnosticTest) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: test.passed == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(test.passed == true ? .green : .red)

                Text(test.test ?? "Test")
                    .font(.subheadline)
            }

            if let details = test.details {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            diagnostics = try await cameraService.getDiagnostics(printerId: printerId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        CameraDiagnosticsView(printerId: "printer-1")
    }
}
