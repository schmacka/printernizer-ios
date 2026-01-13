import SwiftUI
import AVFoundation

struct QRScannerView: View {
    let onScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @State private var errorMessage: String?
    @State private var hasScanned = false

    var body: some View {
        NavigationStack {
            ZStack {
                switch cameraPermissionStatus {
                case .authorized:
                    QRScannerRepresentable(
                        onScanned: handleScanned,
                        onError: { errorMessage = $0 }
                    )
                    .ignoresSafeArea()

                    scannerOverlay

                case .denied, .restricted:
                    permissionDeniedView

                case .notDetermined:
                    ProgressView("Requesting camera access...")

                @unknown default:
                    permissionDeniedView
                }

                if let error = errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding()
                    }
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await checkCameraPermission()
            }
        }
    }

    private var scannerOverlay: some View {
        GeometryReader { geometry in
            let frameSize = min(geometry.size.width, geometry.size.height) * 0.7

            ZStack {
                // Dimmed background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                // Clear scanning area
                RoundedRectangle(cornerRadius: 16)
                    .frame(width: frameSize, height: frameSize)
                    .blendMode(.destinationOut)

                // Frame corners
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: frameSize, height: frameSize)

                // Instructions
                VStack {
                    Spacer()
                        .frame(height: (geometry.size.height - frameSize) / 2 + frameSize + 40)

                    Text("Point camera at QR code")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("displayed in Printernizer web app")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .compositingGroup()
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.bold)

            Text("Camera access is needed to scan the QR code from Printernizer web app.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermissionStatus = status

        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionStatus = granted ? .authorized : .denied
        }
    }

    private func handleScanned(_ code: String) {
        guard !hasScanned else { return }

        // Validate URL
        guard let url = URL(string: code),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            errorMessage = "Invalid URL. Please scan a valid server URL."
            return
        }

        hasScanned = true
        errorMessage = nil

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Call completion and dismiss
        onScanned(code)
        dismiss()
    }
}

// MARK: - QR Scanner UIKit Wrapper

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, onError: onError)
    }

    class Coordinator: NSObject, QRScannerViewControllerDelegate {
        let onScanned: (String) -> Void
        let onError: (String) -> Void

        init(onScanned: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onScanned = onScanned
            self.onError = onError
        }

        func didScanCode(_ code: String) {
            onScanned(code)
        }

        func didFailWithError(_ error: String) {
            onError(error)
        }
    }
}

// MARK: - QR Scanner View Controller

protocol QRScannerViewControllerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didFailWithError(_ error: String)
}

class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerViewControllerDelegate?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    private func setupCamera() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError("No camera available")
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFailWithError("Could not access camera")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didFailWithError("Could not add camera input")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            delegate?.didFailWithError("Could not add metadata output")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.bounds
        previewLayer?.videoGravity = .resizeAspectFill

        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
    }

    private func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if self?.captureSession.isRunning == false {
                self?.captureSession.startRunning()
            }
        }
    }

    private func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        delegate?.didScanCode(stringValue)
    }
}

#Preview {
    QRScannerView { _ in }
}
