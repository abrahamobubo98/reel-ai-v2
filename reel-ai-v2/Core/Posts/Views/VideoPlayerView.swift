import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @StateObject private var viewModel: VideoPlayerViewModel
    
    init(url: URL) {
        self.url = url
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(url: url))
    }
    
    var body: some View {
        VideoPlayer(player: viewModel.player)
            .onAppear {
                print("📱 Attempting to play video from URL: \(url.absoluteString)")
            }
    }
} 