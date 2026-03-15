import AVFoundation
import SwiftUI

/// Full-screen barcode scanner that looks up scanned EAN codes in the OFF database.
struct BarcodeScannerView: View {
    let offStore: OFFStore
    let onFound: (OFFProduct) -> Void

    @State private var showNotFound = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CameraPreview(offStore: offStore, onFound: onFound, onNotFound: {
                showNotFound = true
            })
            .ignoresSafeArea()

            // Réticule
            VStack {
                Spacer()

                RoundedRectangle(cornerRadius: Theme.cornerRadiusL, style: .continuous)
                    .strokeBorder(Color.kcFeather, lineWidth: 3)
                    .frame(width: CameraPreview.reticleWidth, height: CameraPreview.reticleHeight)

                Spacer()

                Text("Scannez un code-barres")
                    .font(.kcHeadline)
                    .foregroundStyle(Color.kcSnow)
                    .shadow(radius: 4)
                    .padding(.bottom, 80)
            }
        }
        .navigationTitle("Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Produit non trouvé", isPresented: $showNotFound) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ce code-barres ne correspond à aucun produit dans la base.")
        }
    }
}

// MARK: - Preview UIView

/// Bare UIView subclass whose sole job is to host and resize the camera preview layer.
private final class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// MARK: - Camera UIViewRepresentable

/// Bridges AVFoundation barcode capture into SwiftUI via a UIViewRepresentable.
private struct CameraPreview: UIViewRepresentable {
    let offStore: OFFStore
    let onFound: (OFFProduct) -> Void
    let onNotFound: () -> Void

    static let reticleWidth: CGFloat = 260
    static let reticleHeight: CGFloat = 160

    /// Creates the underlying UIView and wires up the capture session.
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView(frame: .zero)
        context.coordinator.setupSession(in: view)
        return view
    }

    func updateUIView(_: CameraPreviewUIView, context _: Context) {}

    /// Vends the coordinator that owns the AVCaptureSession and barcode delegate.
    func makeCoordinator() -> Coordinator {
        Coordinator(offStore: offStore, onFound: onFound, onNotFound: onNotFound)
    }

    /// Tears down the capture session when the view is removed from the hierarchy.
    static func dismantleUIView(_: CameraPreviewUIView, coordinator: Coordinator) {
        coordinator.stopSession()
    }

    /// Coordinator that owns the AVCaptureSession and handles barcode metadata callbacks.
    @MainActor
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private static let scanCooldownSeconds: TimeInterval = 1.5
        private static let ean13Length = 13

        private let offStore: OFFStore
        private let onFound: (OFFProduct) -> Void
        private let onNotFound: () -> Void
        private var captureSession: AVCaptureSession?
        private var lastScanDate = Date.distantPast

        /// Initializes the coordinator with store and result callbacks.
        init(offStore: OFFStore, onFound: @escaping (OFFProduct) -> Void, onNotFound: @escaping () -> Void) {
            self.offStore = offStore
            self.onFound = onFound
            self.onNotFound = onNotFound
        }

        /// Configures the capture session, input device, metadata output, and preview layer.
        func setupSession(in view: CameraPreviewUIView) {
            let session = AVCaptureSession()
            self.captureSession = session

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            // Delegate is dispatched on .main queue so MainActor.assumeIsolated is safe in metadataOutput.
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8]

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
            view.previewLayer = previewLayer

            startSessionAsync(session)
        }

        /// Stops and releases the capture session.
        func stopSession() {
            let session = captureSession
            captureSession = nil
            if let session { stopSessionAsync(session) }
        }

        private nonisolated func startSessionAsync(_ session: AVCaptureSession) {
            DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        }

        private nonisolated func stopSessionAsync(_ session: AVCaptureSession) {
            DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
        }

        nonisolated func metadataOutput(
            _: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from _: AVCaptureConnection
        ) {
            guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = readable.stringValue else { return }

            // Safe because the delegate queue is .main (see setupSession).
            MainActor.assumeIsolated {
                handleCode(code)
            }
        }

        /// Debounces scans then looks up the barcode in the OFF store.
        private func handleCode(_ code: String) {
            let now = Date.now
            guard now.timeIntervalSince(lastScanDate) >= Self.scanCooldownSeconds else { return }
            lastScanDate = now

            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

            // OFF stores EAN-13 codes with leading zeros, so short codes (e.g. EAN-8)
            // must be zero-padded to 13 digits before the fallback lookup.
            let padded = code.count < Self.ean13Length
                ? String(repeating: "0", count: Self.ean13Length - code.count) + code
                : code

            if let product = offStore.findByBarcode(code) ?? offStore.findByBarcode(padded) {
                onFound(product)
            } else {
                onNotFound()
            }
        }
    }
}
