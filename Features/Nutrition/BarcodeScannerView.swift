import SwiftUI
import AVFoundation

struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    var onProductFound: (OFFProduct?) -> Void
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ScannerViewControllerDelegate {
        var parent: BarcodeScannerRepresentable
        
        init(_ parent: BarcodeScannerRepresentable) {
            self.parent = parent
        }
        
        func didFindBarcode(_ barcode: String, in vc: ScannerViewController) {
            Task {
                let service = FoodAPIService()
                do {
                    let product = try await service.fetchProduct(barcode: barcode)
                    DispatchQueue.main.async {
                        self.parent.onProductFound(product)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.parent.onProductFound(nil)
                    }
                }
            }
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func didFindBarcode(_ barcode: String, in vc: ScannerViewController)
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: ScannerViewControllerDelegate?
    var isProcessing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scannen nicht möglich", message: "Dein Gerät unterstützt kein Scannen von Barcodes.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isProcessing = false
        if (captureSession?.isRunning == false) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            isProcessing = true
            delegate?.didFindBarcode(stringValue, in: self)
        }
    }
}

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onProductFound: (OFFProduct?) -> Void
    
    var body: some View {
        ZStack {
            BarcodeScannerRepresentable(onProductFound: onProductFound)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                            .padding()
                    }
                }
                
                Spacer()
                
                Text("Bitte richte die Kamera auf den Barcode.")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding(.bottom, 60)
            }
        }
    }
}
