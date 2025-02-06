import SwiftUI
import AVKit

// MARK: - Model & ViewModel
struct CreatePostModel {
    var mediaType: MediaType = .photo
    var caption: String = ""
    var externalLink: String = ""
    var isUploading: Bool = false
    var uploadProgress: Double = 0
    var error: String?
    var image: UIImage?
    var videoURL: URL?
    var fileId: String?
    var post: Post?
    var shouldDismiss: Bool = false
    
    enum MediaType {
        case photo
        case video
        
        var postMediaType: Post.MediaType {
            switch self {
            case .photo: return .photo
            case .video: return .video
            }
        }
    }
}

@MainActor
class CreatePostViewModel: ObservableObject {
    @Published var model = CreatePostModel()
    @Published var showCamera = false
    @Published var showMediaPicker = false
    @Published var showImagePreview = false
    @Published var showVideoPreview = false
    
    let appwrite = AppwriteService.shared
    
    func handleMediaCapture() {
        showCamera = true
    }
    
    func handleMediaSelection() {
        showMediaPicker = true
    }
    
    func handleCapturedImage(_ image: UIImage) {
        model.mediaType = .photo
        model.image = image
        model.videoURL = nil
        model.error = nil
        showImagePreview = true
        showVideoPreview = false
    }
    
    func handleCapturedVideo(_ videoURL: URL) {
        model.mediaType = .video
        model.videoURL = videoURL
        model.image = nil
        model.error = nil
        showVideoPreview = true
        showImagePreview = false
    }
    
    func clearMedia() {
        model.image = nil
        model.videoURL = nil
        model.error = nil
        model.uploadProgress = 0
        model.isUploading = false
        model.fileId = nil
        model.post = nil
        model.shouldDismiss = false
        showImagePreview = false
        showVideoPreview = false
    }
    
    func uploadPost() async {
        guard !model.isUploading else { return }
        
        guard model.image != nil || model.videoURL != nil else {
            model.error = "No media selected"
            return
        }
        
        guard !model.caption.isEmpty else {
            model.error = "Please add a caption"
            return
        }
        
        model.isUploading = true
        model.error = nil
        
        do {
            try Task.checkCancellation()
            
            // 1. Upload media
            let fileId: String
            if let image = model.image {
                fileId = try await appwrite.uploadImage(image) { progress in
                    Task { @MainActor in
                        self.model.uploadProgress = progress * 0.7 // Image upload is 70% of total progress
                    }
                }
            } else if let videoURL = model.videoURL {
                fileId = try await appwrite.uploadVideo(from: videoURL) { progress in
                    Task { @MainActor in
                        self.model.uploadProgress = progress * 0.7 // Video upload is 70% of total progress
                    }
                }
            } else {
                throw StorageError.invalidFormat
            }
            
            model.fileId = fileId
            
            try Task.checkCancellation()
            
            // Update progress for database operation
            await MainActor.run {
                model.uploadProgress = 0.8
            }
            
            // 2. Create post in database
            let post = try await appwrite.createPost(
                mediaId: fileId,
                caption: model.caption,
                mediaType: model.mediaType.postMediaType,
                externalLink: model.externalLink
            )
            
            try Task.checkCancellation()
            
            await MainActor.run {
                model.post = post
                model.uploadProgress = 1.0
            }
            
            // 3. Reset and dismiss
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            
            await MainActor.run {
                model.shouldDismiss = true
                clearMedia()
            }
            
        } catch is CancellationError {
            // Task was cancelled, clean up
            await MainActor.run {
                model.error = nil
                model.isUploading = false
            }
            return
        } catch let error as StorageError {
            await MainActor.run {
                model.error = error.localizedDescription
            }
        } catch let error as DatabaseError {
            await MainActor.run {
                model.error = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                model.error = "Failed to create post: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            model.isUploading = false
        }
    }
}

// MARK: - View
struct MediaPreviewView: View {
    let image: UIImage?
    let videoURL: URL?
    let player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if videoURL != nil {
                if isPlaying {
                    VideoPlayer(player: player)
                } else {
                    // Video thumbnail with play button
                    ZStack {
                        AsyncImage(url: videoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure(_):
                                Color.black
                            case .empty:
                                Color.black
                            @unknown default:
                                Color.black
                            }
                        }
                        
                        Button(action: {
                            isPlaying = true
                            player?.play()
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                        }
                    }
                }
            }
        }
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CreateView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var videoPlayer = VideoPlayerManager()
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.showImagePreview || viewModel.showVideoPreview {
                VStack(spacing: 15) {
                    // Header
                    HStack {
                        Button(action: {
                            viewModel.clearMedia()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Button(action: {
                            Task {
                                await viewModel.uploadPost()
                            }
                        }) {
                            if viewModel.model.isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Post")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(viewModel.model.isUploading || viewModel.model.caption.isEmpty)
                    }
                    .padding()
                    
                    // Media Preview
                    MediaPreviewView(
                        image: viewModel.model.image,
                        videoURL: viewModel.model.videoURL,
                        player: videoPlayer.player
                    )
                    .onAppear {
                        if let videoURL = viewModel.model.videoURL {
                            videoPlayer.setVideo(url: videoURL)
                        }
                    }
                    .onDisappear {
                        videoPlayer.cleanup()
                    }
                    
                    // Upload Progress
                    if viewModel.model.isUploading {
                        ProgressView(value: viewModel.model.uploadProgress) {
                            Text("Creating post... \(Int(viewModel.model.uploadProgress * 100))%")
                                .font(.caption)
                        }
                        .progressViewStyle(.linear)
                        .padding()
                    }
                    
                    // Error Message
                    if let error = viewModel.model.error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }
                    
                    // Input Fields
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Caption")
                                .font(.headline)
                                .foregroundColor(.gray)
                            TextField("Write a caption for your post...", text: $viewModel.model.caption)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(height: 44)
                                .font(.body)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("External Link")
                                .font(.headline)
                                .foregroundColor(.gray)
                            TextField("Add a link (optional)", text: $viewModel.model.externalLink)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(height: 44)
                                .font(.body)
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                        }
                    }
                    .padding()
                    .disabled(viewModel.model.isUploading)
                    
                    Spacer()
                }
            } else {
                Text("Create")
                    .font(.largeTitle)
                    .bold()
                
                VStack(spacing: 15) {
                    Button(action: {
                        viewModel.handleMediaCapture()
                    }) {
                        Label("Take Photo or Video", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        viewModel.handleMediaSelection()
                    }) {
                        Label("Choose from Library", systemImage: "photo.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // Placeholder for live streaming functionality
                    }) {
                        Label("Stream Live Lecture", systemImage: "antenna.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .sheet(isPresented: $viewModel.showCamera) {
            CameraView(
                onImageCaptured: { image in
                    viewModel.handleCapturedImage(image)
                },
                onVideoCaptured: { videoURL in
                    viewModel.handleCapturedVideo(videoURL)
                }
            )
        }
        .onChange(of: viewModel.model.shouldDismiss) { shouldDismiss in
            if shouldDismiss {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onChange(of: viewModel.model.isUploading) { isUploading in
            if isUploading {
                videoPlayer.pause()
            }
        }
    }
}

class VideoPlayerManager: ObservableObject, @unchecked Sendable {
    @Published var player: AVPlayer
    @Published var isLoading = false
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var assetResourceLoader: AVAssetResourceLoader?
    
    init() {
        self.player = AVPlayer()
    }
    
    func setVideo(url: URL) {
        isLoading = true
        cleanup() // Clean up previous resources
        
        // Create asset with optimized loading options
        let asset = AVURLAsset(
            url: url,
            options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true
            ]
        )
        
        // Configure resource loader for better streaming
        assetResourceLoader = asset.resourceLoader
        
        // Load asset asynchronously
        Task { @MainActor in
            do {
                // Load essential properties first
                let keys = ["playable", "duration", "tracks"]
                for key in keys {
                    asset.loadValuesAsynchronously(forKeys: [key])
                }
                
                // Check for playable status
                var error: NSError?
                let status = asset.statusOfValue(forKey: "playable", error: &error)
                if status == .failed {
                    throw error ?? NSError(domain: "VideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load asset"])
                }
                
                // Create player item with optimized settings
                let item = AVPlayerItem(asset: asset)
                item.preferredForwardBufferDuration = 2
                item.preferredMaximumResolution = CGSize(width: 640, height: 640) // Limit resolution for preview
                
                // Configure item for better memory usage
                item.automaticallyPreservesTimeOffsetFromLive = false
                item.preferredForwardBufferDuration = 2
                item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
                
                // Set up time observer
                timeObserver = player.addPeriodicTimeObserver(
                    forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                    queue: .main
                ) { [weak self] _ in
                    if self?.player.currentTime() == self?.player.currentItem?.duration {
                        self?.cleanup()
                    }
                }
                
                self.playerItem = item
                self.player.replaceCurrentItem(with: item)
                self.isLoading = false
                
            } catch {
                print("📱 Error loading video asset: \(error)")
                self.isLoading = false
            }
        }
    }
    
    func pause() {
        player.pause()
    }
    
    func cleanup() {
        player.pause()
        
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        playerItem?.cancelPendingSeeks()
        playerItem = nil
        player.replaceCurrentItem(with: nil)
        assetResourceLoader = nil
        isLoading = false
    }
    
    deinit {
        cleanup()
    }
}

#Preview {
    CreateView()
} 