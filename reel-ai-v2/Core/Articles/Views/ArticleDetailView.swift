import SwiftUI
import Appwrite

struct ArticleDetailView: View {
    let article: Article
    @Environment(\.dismiss) private var dismiss
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var isLoading = false
    @State private var commentText = ""
    @State private var isAddingComment = false
    @State private var showComments = false
    @State private var comments: [Comment] = []
    @State private var errorMessage: String?
    @State private var showQuiz = false
    private let appwrite = AppwriteService.shared
    
    init(article: Article) {
        self.article = article
        self._likeCount = State(initialValue: article.likes)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(article.title)
                        .font(.title)
                        .bold()
                        .padding(.bottom, 4)
                    
                    // Author and date
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle.fill")
                            Text(article.author)
                        }
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(article.createdAt, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // Content
                    Text(article.content)
                        .font(.body)
                        .lineSpacing(8)
                    
                    // Quiz Button
                    Button(action: {
                        showQuiz = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Take Quiz")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.vertical)
                    .sheet(isPresented: $showQuiz) {
                        QuizView(viewModel: QuizViewModel(
                            quizService: QuizService(databases: Databases(AppwriteService.shared.client), databaseId: Config.shared.appwriteDatabaseId),
                            openAIService: OpenAIQuizService(),
                            userId: article.userId,
                            articleId: article.id
                        ))
                    }
                    
                    // Stats
                    HStack(spacing: 24) {
                        // Views
                        HStack(spacing: 8) {
                            Image(systemName: "eye")
                            Text("\(article.views) views")
                        }
                        
                        // Likes
                        Button(action: handleLikeAction) {
                            HStack(spacing: 8) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .foregroundColor(isLiked ? .red : .gray)
                                Text("\(likeCount) likes")
                            }
                        }
                        .disabled(isLoading)
                        
                        // Comments
                        HStack(spacing: 8) {
                            Image(systemName: "message")
                            Text("0 comments") // TODO: Implement comments
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                    
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
                                Text("\(comments.count) Comments")
                                Spacer()
                                Image(systemName: showComments ? "chevron.up" : "chevron.down")
                            }
                            .foregroundColor(.primary)
                        }
                        .padding(.top, 8)
                        
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
                            
                            if let error = errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
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
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
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
        .task {
            // Check if user has liked the article
            do {
                isLiked = try await appwrite.hasLiked(documentId: article.id)
            } catch {
                print("📱 Error checking like status: \(error)")
            }
        }
    }
    
    private func loadComments() {
        Task {
            do {
                debugPrint("📱 ArticleDetailView: Loading comments for article \(article.id)")
                comments = try await appwrite.fetchComments(documentId: article.id)
                debugPrint("📱 ArticleDetailView: Successfully loaded \(comments.count) comments")
            } catch {
                debugPrint("📱 ArticleDetailView: Error loading comments: \(error)")
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
                debugPrint("📱 ArticleDetailView: Adding comment to article \(article.id)")
                debugPrint("📱 ArticleDetailView: Comment text: \(commentText)")
                
                let comment = try await appwrite.createComment(
                    text: commentText,
                    documentId: article.id,
                    collectionId: AppwriteService.articlesCollectionId
                )
                
                debugPrint("📱 ArticleDetailView: Successfully added comment: \(comment)")
                
                await MainActor.run {
                    commentText = ""
                    comments.insert(comment, at: 0)
                    isAddingComment = false
                }
            } catch {
                debugPrint("📱 ArticleDetailView: Error adding comment: \(error)")
                errorMessage = "Failed to add comment"
                isAddingComment = false
            }
        }
    }
    
    private func handleLikeAction() {
        guard !isLoading else {
            debugPrint("📱 ArticleDetailView: Like action skipped - already loading")
            return
        }
        
        debugPrint("📱 ArticleDetailView: Starting like action for article \(article.id)")
        debugPrint("📱 ArticleDetailView: Current state - isLiked: \(isLiked), likeCount: \(likeCount)")
        isLoading = true
        
        Task {
            do {
                if isLiked {
                    debugPrint("📱 ArticleDetailView: Attempting to unlike article \(article.id)")
                    try await appwrite.unlike(documentId: article.id, collectionId: AppwriteService.articlesCollectionId)
                    likeCount -= 1
                    debugPrint("📱 ArticleDetailView: Successfully unliked article. New like count: \(likeCount)")
                } else {
                    debugPrint("📱 ArticleDetailView: Attempting to like article \(article.id)")
                    try await appwrite.like(documentId: article.id, collectionId: AppwriteService.articlesCollectionId)
                    likeCount += 1
                    debugPrint("📱 ArticleDetailView: Successfully liked article. New like count: \(likeCount)")
                }
                isLiked.toggle()
                debugPrint("📱 ArticleDetailView: Updated isLiked state: \(isLiked)")
            } catch {
                debugPrint("📱 ArticleDetailView: Error handling article like action: \(error)")
                debugPrint("📱 ArticleDetailView: Error details - \(String(describing: error))")
            }
            isLoading = false
            debugPrint("📱 ArticleDetailView: Like action completed")
        }
    }
} 