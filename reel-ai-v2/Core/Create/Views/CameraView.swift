import SwiftUI
import AVFoundation

class CameraViewModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    @Published var isCapturing = false
    @Published var error: String?
    @Published var capturedImage: UIImage?
    @Published var isSimulator = false
    
    var onImageCaptured: ((UIImage) -> Void)?
    private var camera: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var output = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        #if targetEnvironment(simulator)
        isSimulator = true
        error = "Camera is not available in simulator"
        #else
        setupCamera()
        #endif
    }
    
    func setupCamera() {
        checkPermissions()
        
        guard isAuthorized else { return }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // Reset any existing configuration
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        // Setup new configuration
        camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
        do {
            if let camera = camera {
                input = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(input!) {
                    session.addInput(input!)
                }
                
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    // Ensure we have a video connection before proceeding
                    if let connection = output.connection(with: .video),
                       connection.isEnabled {
                        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                            self?.session.startRunning()
                        }
                    } else {
                        error = "Video output is not available"
                        debugPrint("📱 Video output is not enabled")
                    }
                } else {
                    error = "Failed to setup camera output"
                    debugPrint("📱 Cannot add photo output")
                }
            } else {
                error = "Camera device not found"
                debugPrint("📱 No camera device available")
            }
        } catch {
            self.error = "Failed to setup camera: \(error.localizedDescription)"
            debugPrint("📱 Camera setup error: \(error)")
        }
    }
    
    func cleanup() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            isAuthorized = false
            error = "Camera access is required to take photos"
        }
    }
    
    func capturePhoto() {
        guard !isSimulator else {
            error = "Cannot capture photo in simulator"
            return
        }
        
        guard session.isRunning else {
            error = "Camera is not ready"
            return
        }
        
        guard let videoConnection = output.connection(with: .video),
              videoConnection.isEnabled,
              videoConnection.isActive else {
            error = "Camera connection is not available"
            return
        }
        
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCapturing = false
        
        if let error = error {
            self.error = "Failed to capture photo: \(error.localizedDescription)"
            debugPrint("📱 Photo capture error: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            self.error = "Could not process captured photo"
            debugPrint("📱 Could not get image data")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
            self?.onImageCaptured?(image)
        }
        debugPrint("📱 Photo captured successfully")
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CameraViewModel()
    var onImageCaptured: ((UIImage) -> Void)?
    
    var body: some View {
        ZStack {
            if viewModel.isSimulator {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Camera not available in simulator")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Text("Please run on a real device")
                        .foregroundColor(.gray)
                    Button("Close") {
                        dismiss()
                    }
                    .padding()
                }
                .padding()
            } else if viewModel.isAuthorized {
                CameraPreviewView(session: viewModel.session)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                    }
                    Spacer()
                    Button(action: {
                        viewModel.capturePhoto()
                    }) {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.white)
                    }
                    .disabled(viewModel.isCapturing)
                    .padding(.bottom, 30)
                }
            } else {
                VStack {
                    Text(viewModel.error ?? "Camera access required")
                        .font(.title)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Close") {
                        dismiss()
                    }
                    .padding()
                }
            }
            
            if viewModel.isCapturing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
            }
        }
        .onAppear {
            viewModel.onImageCaptured = { image in
                onImageCaptured?(image)
                dismiss()
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

#Preview {
    CameraView()
} 