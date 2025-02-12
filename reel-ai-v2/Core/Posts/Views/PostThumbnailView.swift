import SwiftUI
import AVKit

struct VideoThumbnailContent: View {
    let post: Post
    @ObservedObject var thumbnailLoader: VideoThumbnailLoader
    let cache: MediaCache
    
    var body: some View {
        if let cachedThumbnail = cache.getImage(forKey: post.mediaId, isThumbnail: true) {
            Image(uiImage: cachedThumbnail)
                .resizable()
                .scaledToFill()
        } else if thumbnailLoader.isLoading {
            ProgressView()
        } else if let thumbnail = thumbnailLoader.thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .onAppear {
                    cache.cacheImage(thumbnail, forKey: post.mediaId, isThumbnail: true)
                }
        } else if thumbnailLoader.error != nil {
            Image(systemName: "video.slash.fill")
                .font(.title)
                .foregroundColor(.gray)
        } else {
            Color.clear
                .onAppear {
                    print("📱 Loading video thumbnail for post \(post.id)")
                    let videoUrl = AppwriteService.shared.getMediaUrl(mediaId: post.mediaId, isVideo: true, forThumbnail: false)
                    print("📱 Using video URL for thumbnail generation: \(videoUrl)")
                    thumbnailLoader.loadThumbnail(from: videoUrl)
                }
        }
    }
}

struct ImageThumbnailContent: View {
    let post: Post
    let cache: MediaCache
    let appwrite: AppwriteService
    @State private var displayImage: UIImage?
    
    var body: some View {
        ZStack {
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // First try to get from cache
        if let cachedImage = cache.getImage(forKey: post.mediaId) {
            print("📱 ImageThumbnailContent: Loading from cache for post \(post.id)")
            displayImage = cachedImage
            return
        }
        
        // If not in cache, load from URL
        let imageUrl = appwrite.getMediaUrl(mediaId: post.mediaId, isVideo: false)
        print("📱 ImageThumbnailContent: Loading from URL for post \(post.id): \(imageUrl)")
        
        guard let url = URL(string: imageUrl) else {
            print("📱 ImageThumbnailContent: Invalid URL for post \(post.id)")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("📱 ImageThumbnailContent: Error loading image for post \(post.id): \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("📱 ImageThumbnailContent: Invalid image data for post \(post.id)")
                return
            }
            
            DispatchQueue.main.async {
                print("📱 ImageThumbnailContent: Successfully loaded image for post \(post.id)")
                self.cache.cacheImage(image, forKey: post.mediaId)
                self.displayImage = image
            }
        }.resume()
    }
}

struct PostThumbnailView: View {
    let post: Post
    @State private var showDetail = false
    @StateObject private var thumbnailLoader = VideoThumbnailLoader()
    private let appwrite = AppwriteService.shared
    private let cache = MediaCache.shared
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if post.mediaType == .video {
                    VideoThumbnailContent(post: post, thumbnailLoader: thumbnailLoader, cache: cache)
                } else {
                    ImageThumbnailContent(post: post, cache: cache, appwrite: appwrite)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipped()
            .overlay(
                Group {
                    if post.mediaType == .video {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                }
            )
            .onTapGesture {
                showDetail = true
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .sheet(isPresented: $showDetail) {
            PostDetailView(post: post)
        }
    }
}

// Add extension to convert SwiftUI Image to UIImage
extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        
        // Ensure the controller's view is using the correct size
        let targetSize = controller.view.intrinsicContentSize
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = .clear
        
        // Render synchronously to avoid lifecycle issues
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let uiImage = renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: false)
        }
        
        return uiImage.cgImage != nil ? uiImage : nil
    }
} 