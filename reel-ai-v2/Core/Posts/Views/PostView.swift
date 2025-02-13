import SwiftUI
import AVKit
import Appwrite

struct PostView: View {
    let post: Post
    let appwrite = AppwriteService.shared
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var isLoading = false
    @State private var commentText = ""
    @State private var isAddingComment = false
    @State private var showComments = false
    @State private var comments: [Comment] = []
    @State private var errorMessage: String?
    
    init(post: Post) {
        self.post = post
        self._likeCount = State(initialValue: post.likes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User info
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                Text(post.author)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Image or Video
            if post.mediaType == .video {
                let mediaUrl = appwrite.getMediaUrl(mediaId: post.mediaId, isVideo: true, forThumbnail: false)
                if let url = URL(string: mediaUrl) {
                    VideoPlayerView(url: url)
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .onAppear {
                            print("📱 Attempting to load video with URL: \(mediaUrl)")
                        }
                } else {
                    Text("Invalid video URL")
                        .foregroundColor(.red)
                }
            } else {
                AsyncImage(url: URL(string: appwrite.getMediaUrl(mediaId: post.mediaId))) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 300)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .frame(maxWidth: .infinity, minHeight: 300)
                    @unknown default:
                        EmptyView()
                    }
                }
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
            .padding(.horizontal)
            .padding(.bottom)
            
            // Description
            if !post.caption.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description:")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Text(post.caption)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }
            
            // Comments Section
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    showComments.toggle()
                    if showComments {
                        loadComments()
                    }
                }) {
                    HStack {
                        Image(systemName: "message")
                        Text("\(post.comments) Comments")
                        Spacer()
                        Image(systemName: showComments ? "chevron.up" : "chevron.down")
                    }
                    .foregroundColor(.primary)
                }
                .padding(.horizontal)
                
                if showComments {
                    // Comment Input
                    HStack {
                        TextField("Add a comment...", text: $commentText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isAddingComment)
                        
                        Button(action: addComment) {
                            if isAddingComment {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Post")
                                    .foregroundColor(commentText.isEmpty ? .gray : .blue)
                            }
                        }
                        .disabled(commentText.isEmpty || isAddingComment)
                    }
                    .padding(.horizontal)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    // Comments List
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(comment.author)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(comment.createdAt, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Text(comment.text)
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
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
    
    private func loadComments() {
        Task {
            do {
                comments = try await appwrite.fetchComments(documentId: post.id)
            } catch {
                errorMessage = "Failed to load comments"
            }
        }
    }
    
    private func addComment() {
        guard !commentText.isEmpty else { return }
        
        isAddingComment = true
        errorMessage = nil
        
        Task {
            do {
                let comment = try await appwrite.createComment(
                    text: commentText,
                    documentId: post.id,
                    collectionId: AppwriteService.postsCollectionId
                )
                
                await MainActor.run {
                    commentText = ""
                    comments.insert(comment, at: 0)
                    isAddingComment = false
                }
            } catch {
                errorMessage = "Failed to add comment"
                isAddingComment = false
            }
        }
    }
} 