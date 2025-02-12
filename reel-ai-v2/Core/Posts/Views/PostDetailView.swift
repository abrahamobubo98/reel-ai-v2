import SwiftUI
import AVKit

struct PostDetailView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    private let appwrite = AppwriteService.shared
    private let cache = MediaCache.shared
    
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var isLoading = false
    
    init(post: Post) {
        self.post = post
        self._likeCount = State(initialValue: post.likes)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    if post.mediaType == .video {
                        let mediaUrl = appwrite.getMediaUrl(mediaId: post.mediaId, isVideo: true, forThumbnail: false)
                        if let url = URL(string: mediaUrl) {
                            VideoPlayerView(url: url)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .onAppear {
                                    print("📱 Attempting to load detail video with URL: \(mediaUrl)")
                                }
                        } else {
                            Text("Invalid video URL")
                                .foregroundColor(.red)
                        }
                    } else {
                        if let cachedImage = cache.getImage(forKey: post.mediaId) {
                            Image(uiImage: cachedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        } else {
                            AsyncImage(url: URL(string: appwrite.getMediaUrl(mediaId: post.mediaId))) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .onAppear {
                                            if let uiImage = image.asUIImage() {
                                                cache.cacheImage(uiImage, forKey: post.mediaId)
                                            }
                                        }
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    
                    // Post details
                    VStack(alignment: .leading, spacing: 12) {
                        // User info
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                            Text(post.author)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.top)
                        
                        // Caption
                        if !post.caption.isEmpty {
                            Text(post.caption)
                                .font(.body)
                        }
                        
                        // Metadata
                        HStack {
                            Button(action: handleLikeAction) {
                                HStack {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .foregroundColor(isLiked ? .red : .primary)
                                    Text("\(likeCount)")
                                }
                            }
                            .disabled(isLoading)
                            
                            Spacer()
                            
                            Text(post.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .task {
            // Check if user has liked the post
            do {
                isLiked = try await appwrite.hasLiked(documentId: post.id)
            } catch {
                print("📱 Error checking like status: \(error)")
            }
        }
    }
    
    private func handleLikeAction() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                if isLiked {
                    try await appwrite.unlike(documentId: post.id, collectionId: AppwriteService.postsCollectionId)
                    likeCount -= 1
                } else {
                    try await appwrite.like(documentId: post.id, collectionId: AppwriteService.postsCollectionId)
                    likeCount += 1
                }
                isLiked.toggle()
            } catch {
                print("📱 Error handling like action: \(error)")
            }
            isLoading = false
        }
    }
} 