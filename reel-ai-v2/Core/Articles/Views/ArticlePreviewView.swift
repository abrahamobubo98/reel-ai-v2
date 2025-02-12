import SwiftUI

struct ArticlePreviewView: View {
    let article: Article
    @State private var showDetail = false
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var isLoading = false
    @State private var showQuiz = false
    private let appwrite = AppwriteService.shared
    
    init(article: Article) {
        self.article = article
        self._likeCount = State(initialValue: article.likes)
    }
    
    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(article.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Preview of content
                Text(article.content)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Metadata
                HStack {
                    // Author info
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                        Text(article.author)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Date
                    Text(article.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Stats
                HStack(spacing: 16) {
                    // Views
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                        Text("\(article.views)")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    
                    // Likes
                    Button(action: handleLikeAction) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundColor(isLiked ? .red : .gray)
                            Text("\(likeCount)")
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    .disabled(isLoading)
                    
                    // Comments
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                        Text("0") // TODO: Implement comments count
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            ArticleDetailView(article: article)
        }
        .task {
            // Check if user has liked the article
            do {
                debugPrint("📱 ArticlePreviewView: Checking like status for article \(article.id)")
                debugPrint("📱 ArticlePreviewView: Current like count: \(likeCount)")
                isLiked = try await appwrite.hasLiked(documentId: article.id)
                debugPrint("📱 ArticlePreviewView: Like status checked - isLiked: \(isLiked)")
            } catch {
                debugPrint("📱 ArticlePreviewView: Error checking article like status: \(error)")
                debugPrint("📱 ArticlePreviewView: Error details - \(String(describing: error))")
            }
        }
    }
    
    private func handleLikeAction() {
        guard !isLoading else {
            debugPrint("📱 ArticlePreviewView: Like action skipped - already loading")
            return
        }
        
        debugPrint("📱 ArticlePreviewView: Starting like action for article \(article.id)")
        debugPrint("📱 ArticlePreviewView: Current state - isLiked: \(isLiked), likeCount: \(likeCount)")
        isLoading = true
        
        Task {
            do {
                if isLiked {
                    debugPrint("📱 ArticlePreviewView: Attempting to unlike article \(article.id)")
                    try await appwrite.unlike(documentId: article.id, collectionId: AppwriteService.articlesCollectionId)
                    likeCount -= 1
                    debugPrint("📱 ArticlePreviewView: Successfully unliked article. New like count: \(likeCount)")
                } else {
                    debugPrint("📱 ArticlePreviewView: Attempting to like article \(article.id)")
                    try await appwrite.like(documentId: article.id, collectionId: AppwriteService.articlesCollectionId)
                    likeCount += 1
                    debugPrint("📱 ArticlePreviewView: Successfully liked article. New like count: \(likeCount)")
                }
                isLiked.toggle()
                debugPrint("📱 ArticlePreviewView: Updated isLiked state: \(isLiked)")
            } catch {
                debugPrint("📱 ArticlePreviewView: Error handling article like action: \(error)")
                debugPrint("📱 ArticlePreviewView: Error details - \(String(describing: error))")
            }
            isLoading = false
            debugPrint("📱 ArticlePreviewView: Like action completed")
        }
    }
} 