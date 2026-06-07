import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {}

    final class Coordinator: NSObject, ScannerDelegate {
        let onScan: (String) -> Void
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }
        func didFind(_ code: String) { onScan(code) }
    }
}

protocol ScannerDelegate: AnyObject {
    func didFind(_ code: String)
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerDelegate?
    private let session = AVCaptureSession()
    private var found = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput results: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !found,
              let obj = results.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        found = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        delegate?.didFind(value)
    }
}
