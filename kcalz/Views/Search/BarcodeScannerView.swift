import AVFoundation
import SwiftUI

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
                    .frame(width: 260, height: 160)

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

private final class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// MARK: - Camera UIViewRepresentable

private struct CameraPreview: UIViewRepresentable {
    let offStore: OFFStore
    let onFound: (OFFProduct) -> Void
    let onNotFound: () -> Void

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView(frame: .zero)
        context.coordinator.setupSession(in: view)
        return view
    }

    func updateUIView(_: CameraPreviewUIView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(offStore: offStore, onFound: onFound, onNotFound: onNotFound)
    }

    static func dismantleUIView(_: CameraPreviewUIView, coordinator: Coordinator) {
        coordinator.stopSession()
    }

    @MainActor
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let offStore: OFFStore
        private let onFound: (OFFProduct) -> Void
        private let onNotFound: () -> Void
        private var captureSession: AVCaptureSession?
        private var lastScanDate = Date.distantPast
        private let cooldown: TimeInterval = 1.5

        init(offStore: OFFStore, onFound: @escaping (OFFProduct) -> Void, onNotFound: @escaping () -> Void) {
            self.offStore = offStore
            self.onFound = onFound
            self.onNotFound = onNotFound
        }

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
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8]

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
            view.previewLayer = previewLayer

            startSessionAsync(session)
        }

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

            MainActor.assumeIsolated {
                handleCode(code)
            }
        }

        private func handleCode(_ code: String) {
            let now = Date.now
            guard now.timeIntervalSince(lastScanDate) >= cooldown else { return }
            lastScanDate = now

            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

            print("[BarcodeScan] code=\(code)")

            // Try exact match first, then padded to 13 digits (OFF stores some codes with leading zeros)
            let padded = code.count < 13
                ? String(repeating: "0", count: 13 - code.count) + code
                : code

            if let product = offStore.findByBarcode(code) ?? offStore.findByBarcode(padded) {
                onFound(product)
            } else {
                onNotFound()
            }
        }
    }
}
