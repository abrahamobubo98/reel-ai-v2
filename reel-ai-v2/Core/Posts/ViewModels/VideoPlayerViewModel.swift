import SwiftUI
import AVKit

class VideoPlayerViewModel: NSObject, ObservableObject {
    @Published var error: Error?
    @Published var isLoading = true
    
    let player: AVPlayer
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private let url: URL
    private var lastPlaybackTime: CMTime?
    
    func savePlaybackTime() {
        lastPlaybackTime = player.currentTime()
    }
    
    func restorePlaybackTime() {
        if let time = lastPlaybackTime {
            player.seek(to: time)
        }
    }
    
    init(url: URL) {
        self.url = url
        print("📱 VideoPlayerViewModel: Initializing with URL: \(url.absoluteString)")
        
        // Create an AVPlayerItem with optimized settings
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 2
        playerItem.automaticallyPreservesTimeOffsetFromLive = false
        
        // Initialize player with the configured item
        self.player = AVPlayer(playerItem: playerItem)
        super.init()
        
        // Configure player
        player.automaticallyWaitsToMinimizeStalling = true
        
        // Observe player status
        statusObserver = player.observe(\.status, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                print("📱 Video player status changed: \(player.status.rawValue)")
                self?.isLoading = player.status == .unknown
                
                if player.status == .failed {
                    print("📱 Video player error: \(String(describing: player.error))")
                    self?.error = player.error
                } else if player.status == .readyToPlay {
                    print("📱 Video player ready to play")
                    // Preroll the player to prepare for smooth playback
                    player.preroll(atRate: 1) { finished in
                        print("📱 Video player preroll finished: \(finished)")
                    }
                }
            }
        }
        
        // Add periodic time observer
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] _ in
            guard let self = self,
                  let duration = self.player.currentItem?.duration,
                  self.player.currentTime() >= duration else { return }
            self.cleanup()
        }
    }
    
    func resetPlayer() {
        print("📱 Resetting player")
        cleanup()
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 2
        playerItem.automaticallyPreservesTimeOffsetFromLive = false
        
        player.replaceCurrentItem(with: playerItem)
    }
    
    func cleanup() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        player.replaceCurrentItem(with: nil)
    }
    
    deinit {
        cleanup()
    }
} 