import SwiftUI
import AVFoundation

class CameraViewModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    @Published var isCapturing = false
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: String?
    @Published var capturedImage: UIImage?
    @Published var isSimulator = false
    
    var onImageCaptured: ((UIImage) -> Void)?
    var onVideoCaptured: ((URL) -> Void)?
    
    private var camera: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureMovieFileOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var recordingTimer: Timer?
    
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
                
                // Add photo output
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                }
                
                // Add video output
                if session.canAddOutput(videoOutput) {
                    session.addOutput(videoOutput)
                }
                
                // Start session
                if let connection = photoOutput.connection(with: .video),
                   connection.isEnabled {
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        self?.session.startRunning()
                    }
                } else {
                    error = "Video output is not available"
                    debugPrint("📱 Video output is not enabled")
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
        stopRecording()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    private func checkPermissions() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch (videoStatus, audioStatus) {
        case (.authorized, .authorized):
            isAuthorized = true
        case (.notDetermined, _):
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                        DispatchQueue.main.async {
                            self?.isAuthorized = audioGranted
                            if audioGranted {
                                self?.setupCamera()
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.isAuthorized = false
                        self?.error = "Camera access is required"
                    }
                }
            }
        case (_, .notDetermined):
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted && videoStatus == .authorized
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            isAuthorized = false
            error = "Camera and microphone access are required"
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
        
        guard let videoConnection = photoOutput.connection(with: .video),
              videoConnection.isEnabled,
              videoConnection.isActive else {
            error = "Camera connection is not available"
            return
        }
        
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func startRecording() {
        guard !isSimulator else {
            error = "Cannot record video in simulator"
            return
        }
        
        guard session.isRunning else {
            error = "Camera is not ready"
            return
        }
        
        guard !isRecording else { return }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
        
        // Start timer for recording duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.recordingDuration += 0.1
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        videoOutput.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
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

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        isRecording = false
        
        if let error = error {
            self.error = "Failed to record video: \(error.localizedDescription)"
            debugPrint("📱 Video recording error: \(error)")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onVideoCaptured?(outputFileURL)
        }
        debugPrint("📱 Video recorded successfully")
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
    var onVideoCaptured: ((URL) -> Void)?
    
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
                        
                        if viewModel.isRecording {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                Text(String(format: "%.1f", viewModel.recordingDuration))
                                    .foregroundColor(.white)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .padding(.horizontal)
                        }
                    }
                    Spacer()
                    
                    // Camera button with gestures
                    Button(action: {}) {
                        Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "camera.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.white)
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                viewModel.startRecording()
                            }
                    )
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                if viewModel.isRecording {
                                    viewModel.stopRecording()
                                } else {
                                    viewModel.capturePhoto()
                                }
                            }
                    )
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
            viewModel.onVideoCaptured = { url in
                onVideoCaptured?(url)
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