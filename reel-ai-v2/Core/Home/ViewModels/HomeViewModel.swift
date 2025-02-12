import SwiftUI
import Appwrite

class HomeViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var articles: [Article] = []
    @Published var isLoading = false
    @Published var error: String?
    private var currentOffset = 0
    private let limit = 10
    private let appwrite = AppwriteService.shared
    private var loadingTask: Task<Void, Never>?
    
    @MainActor
    func loadPosts(loadMore: Bool = false) {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Create new loading task
        loadingTask = Task {
            guard !isLoading else {
                print("📱 Loading already in progress, skipping")
                return
            }
            
            if loadMore {
                currentOffset += limit
                print("📱 Loading more posts from offset: \(currentOffset)")
            } else {
                currentOffset = 0
                posts = []
                print("📱 Loading initial posts")
            }
            
            isLoading = true
            error = nil
            
            do {
                print("📱 Fetching posts...")
                let newPosts = try await appwrite.fetchPosts(limit: limit, offset: currentOffset)
                
                // Check if task was cancelled
                if Task.isCancelled {
                    print("📱 Task was cancelled, aborting post load")
                    return
                }
                
                print("📱 Successfully fetched \(newPosts.count) posts")
                posts.append(contentsOf: newPosts)
                error = nil
            } catch {
                print("📱 Error loading posts: \(error.localizedDescription)")
                if error is CancellationError {
                    // Don't show cancellation errors to the user
                    return
                }
                self.error = "Failed to load posts. Pull to refresh and try again."
            }
            
            isLoading = false
        }
    }
    
    @MainActor
    func loadArticles() async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Create new loading task
        loadingTask = Task {
            guard !isLoading else {
                print("📱 Loading already in progress, skipping")
                return
            }
            
            isLoading = true
            error = nil
            articles = []
            
            do {
                print("📱 Fetching articles...")
                let fetchedArticles = try await appwrite.fetchArticles(limit: limit, offset: 0)
                
                // Check if task was cancelled
                if Task.isCancelled {
                    print("📱 Task was cancelled, aborting article load")
                    return
                }
                
                print("📱 Successfully fetched \(fetchedArticles.count) articles")
                articles = fetchedArticles
                error = nil
            } catch {
                print("📱 Error loading articles: \(error.localizedDescription)")
                if error is CancellationError {
                    // Don't show cancellation errors to the user
                    return
                }
                self.error = "Failed to load articles. Pull to refresh and try again."
            }
            
            isLoading = false
        }
    }
    
    deinit {
        loadingTask?.cancel()
    }
} 