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
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    
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
        
        // Stop the session before reconfiguring
        if session.isRunning {
            session.stopRunning()
        }
        
        // Use a dedicated queue for session configuration
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Reset any existing configuration
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }
            
            // Setup new configuration
            self.camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentCameraPosition)
            
            do {
                if let camera = self.camera {
                    self.input = try AVCaptureDeviceInput(device: camera)
                    if self.session.canAddInput(self.input!) {
                        self.session.addInput(self.input!)
                    }
                    
                    // Add photo output
                    if self.session.canAddOutput(self.photoOutput) {
                        self.session.addOutput(self.photoOutput)
                    }
                    
                    // Add video output
                    if self.session.canAddOutput(self.videoOutput) {
                        self.session.addOutput(self.videoOutput)
                    }
                    
                    self.session.commitConfiguration()
                    
                    // Start session after configuration is committed
                    if let connection = self.photoOutput.connection(with: .video),
                       connection.isEnabled {
                        self.session.startRunning()
                    } else {
                        DispatchQueue.main.async {
                            self.error = "Video output is not available"
                        }
                        debugPrint("📱 Video output is not enabled")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.error = "Camera device not found"
                    }
                    debugPrint("📱 No camera device available")
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to setup camera: \(error.localizedDescription)"
                }
                debugPrint("📱 Camera setup error: \(error)")
            }
        }
    }
    
    func switchCamera() {
        // Stop any ongoing recording
        if isRecording {
            stopRecording()
        }
        
        // Toggle camera position
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        
        // Reconfigure session with new camera
        setupCamera()
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
        
        DispatchQueue.main.async {
            self.isRecording = true
            
            // Start timer for recording duration
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingDuration += 0.1
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        videoOutput.stopRecording()
        
        DispatchQueue.main.async {
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            self.recordingDuration = 0
            self.isRecording = false
        }
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
    @State private var captureMode: CaptureMode = .photo
    @State private var dragOffset: CGFloat = 0
    
    var onImageCaptured: ((UIImage) -> Void)?
    var onVideoCaptured: ((URL) -> Void)?
    
    enum CaptureMode {
        case photo
        case video
    }
    
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
                ZStack {
                    // Camera Preview
                    CameraPreviewView(session: viewModel.session)
                        .ignoresSafeArea()
                    
                    // Mode Indicator at top
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
                            
                            // Mode Pills - Now Tappable
                            HStack(spacing: 0) {
                                Button(action: {
                                    withAnimation {
                                        captureMode = .photo
                                    }
                                }) {
                                    Text("Photo")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(captureMode == .photo ? Color.white : Color.black.opacity(0.5))
                                        .foregroundColor(captureMode == .photo ? .black : .white)
                                }
                                
                                Button(action: {
                                    withAnimation {
                                        captureMode = .video
                                    }
                                }) {
                                    Text("Video")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(captureMode == .video ? Color.white : Color.black.opacity(0.5))
                                        .foregroundColor(captureMode == .video ? .black : .white)
                                }
                            }
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .padding()
                            
                            Spacer()
                            
                            // Camera Switch Button
                            Button(action: {
                                viewModel.switchCamera()
                            }) {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            .disabled(viewModel.isRecording)
                        }
                        
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
                        
                        Spacer()
                        
                        // Capture Button with improved gestures
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 3)
                                .frame(width: 80, height: 80)
                            
                            if captureMode == .video {
                                if viewModel.isRecording {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red)
                                        .frame(width: 30, height: 30)
                                } else {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 60, height: 60)
                                }
                            } else {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 20) // Increased minimum distance
                                .onChanged { gesture in
                                    dragOffset = gesture.translation.width
                                    let threshold: CGFloat = 30 // Reduced threshold
                                    withAnimation {
                                        if dragOffset > threshold {
                                            captureMode = .video
                                        } else if dragOffset < -threshold {
                                            captureMode = .photo
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    dragOffset = 0
                                }
                        )
                        .highPriorityGesture(
                            TapGesture()
                                .onEnded {
                                    if captureMode == .photo {
                                        viewModel.capturePhoto()
                                    } else if !viewModel.isRecording {
                                        viewModel.startRecording()
                                    } else {
                                        viewModel.stopRecording()
                                    }
                                }
                        )
                        .disabled(viewModel.isCapturing)
                        .padding(.bottom, 30)
                    }
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
            if viewModel.isRecording {
                viewModel.stopRecording()
            }
            viewModel.cleanup()
        }
    }
}

#Preview {
    CameraView()
} 