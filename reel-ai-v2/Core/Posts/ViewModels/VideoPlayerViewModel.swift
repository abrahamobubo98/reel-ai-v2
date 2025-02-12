import SwiftUI
import AVKit

class VideoPlayerViewModel: NSObject, ObservableObject {
    @Published var error: Error?
    let player: AVPlayer
    
    init(url: URL) {
        self.player = AVPlayer(url: url)
        super.init()
        player.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
    }
    
    deinit {
        player.removeObserver(self, forKeyPath: "status")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let player = object as? AVPlayer {
            print("📱 Video player status changed: \(player.status.rawValue)")
            if player.status == .failed {
                print("📱 Video player error: \(String(describing: player.error))")
                DispatchQueue.main.async {
                    self.error = player.error
                }
            }
        }
    }
} 