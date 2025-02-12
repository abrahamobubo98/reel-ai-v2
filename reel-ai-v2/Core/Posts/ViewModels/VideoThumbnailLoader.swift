import SwiftUI
import AVKit
import AVFoundation

class VideoThumbnailLoader: ObservableObject {
    @Published var thumbnail: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadThumbnail(from urlString: String) {
        print("📱 VideoThumbnailLoader: Starting thumbnail generation for URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            let error = NSError(domain: "VideoThumbnailLoader", code: -1, 
                              userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
            print("📱 VideoThumbnailLoader Error: \(error.localizedDescription)")
            self.error = error
            return
        }
        
        isLoading = true
        print("📱 VideoThumbnailLoader: Creating AVAsset")
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 400, height: 400)
        
        // Request thumbnail at 0.1 seconds to avoid black frames at the start
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        Task {
            do {
                print("📱 VideoThumbnailLoader: Starting thumbnail generation")
                
                // First, check if the asset is ready to generate thumbnails
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard !tracks.isEmpty else {
                    throw NSError(domain: "VideoThumbnailLoader", code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "No video tracks found in asset"])
                }
                
                if #available(iOS 16.0, *) {
                    print("📱 VideoThumbnailLoader: Using iOS 16+ method")
                    let cgImage = try await imageGenerator.image(at: time).image
                    await MainActor.run {
                        self.thumbnail = UIImage(cgImage: cgImage)
                        self.isLoading = false
                        print("📱 VideoThumbnailLoader: Successfully generated thumbnail (iOS 16+)")
                    }
                } else {
                    print("📱 VideoThumbnailLoader: Using pre-iOS 16 method")
                    var actualTime = CMTime.zero
                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: &actualTime)
                    await MainActor.run {
                        self.thumbnail = UIImage(cgImage: cgImage)
                        self.isLoading = false
                        print("📱 VideoThumbnailLoader: Successfully generated thumbnail (pre-iOS 16)")
                    }
                }
            } catch {
                print("📱 VideoThumbnailLoader Error: \(error.localizedDescription)")
                if let avError = error as? AVError {
                    print("📱 VideoThumbnailLoader AVError Code: \(avError.code.rawValue)")
                }
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
} 