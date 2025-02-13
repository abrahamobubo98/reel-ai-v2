import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @StateObject private var viewModel: VideoPlayerViewModel
    @State private var isFullscreen = false
    
    init(url: URL) {
        self.url = url
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(url: url))
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else if viewModel.error != nil {
                VStack {
                    Image(systemName: "video.slash.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load video")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                VideoPlayer(player: viewModel.player)
                    .onAppear {
                        print("📱 VideoPlayer appeared for URL: \(url.absoluteString)")
                        if viewModel.player.status == .readyToPlay {
                            viewModel.player.play()
                        }
                    }
                    .onDisappear {
                        print("📱 VideoPlayer disappeared")
                        if !isFullscreen {
                            viewModel.player.pause()
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Button {
                            print("📱 Fullscreen button tapped")
                            print("📱 Current player rate: \(viewModel.player.rate)")
                            print("📱 Current player status: \(viewModel.player.status.rawValue)")
                            viewModel.savePlaybackTime()
                            isFullscreen = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.title3)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            VideoPlayer(player: viewModel.player)
                .ignoresSafeArea()
                .overlay(alignment: .topLeading) {
                    Button {
                        print("📱 Exiting fullscreen")
                        viewModel.savePlaybackTime()
                        isFullscreen = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
                .onAppear {
                    print("📱 Fullscreen view appeared")
                    print("📱 Player status: \(viewModel.player.status.rawValue)")
                    print("📱 Player error: \(String(describing: viewModel.player.error))")
                    
                    viewModel.restorePlaybackTime()
                    
                    if viewModel.player.status == .failed {
                        viewModel.resetPlayer()
                    }
                    
                    if viewModel.player.status == .readyToPlay {
                        viewModel.player.play()
                    }
                }
                .onDisappear {
                    print("📱 Fullscreen view disappeared")
                }
        }
    }
} 