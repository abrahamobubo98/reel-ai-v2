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
                isLiked = try await appwrite.hasLiked(documentId: article.id)
            } catch {
                // Handle error silently
            }
        }
    }
    
    private func handleLikeAction() {
        guard !isLoading else { return }
        
        isLoading = true
        
        Task {
            do {
                if isLiked {
                    try await appwrite.unlike(documentId: article.id, collectionId: AppwriteService.articlesCollectionId)
                    likeCount -= 1
                } else {
                    try await appwrite.like(documentId: article.id, collectionId: AppwriteService.articlesCollectionId)
                    likeCount += 1
                }
                isLiked.toggle()
            } catch {
                // Handle error silently
            }
            isLoading = false
        }
    }
} 