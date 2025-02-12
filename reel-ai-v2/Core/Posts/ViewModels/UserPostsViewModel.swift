import SwiftUI
import Appwrite

class UserPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: String?
    private let appwrite = AppwriteService.shared
    
    init() {
        print("📱 UserPostsViewModel: Initialized")
    }
    
    deinit {
        print("📱 UserPostsViewModel: Deinitialized")
    }
    
    @MainActor
    func loadUserPosts() async {
        print("📱 UserPostsViewModel: Starting to load user posts")
        print("📱 UserPostsViewModel: Current posts count before loading: \(posts.count)")
        
        isLoading = true
        error = nil
        
        do {
            posts = try await appwrite.fetchPosts(limit: 50, offset: 0)
            print("📱 UserPostsViewModel: Successfully loaded \(posts.count) posts")
        } catch {
            self.error = error.localizedDescription
            print("📱 UserPostsViewModel: Error loading user posts: \(error.localizedDescription)")
        }
        
        isLoading = false
        print("📱 UserPostsViewModel: Finished loading. Current posts count: \(posts.count)")
    }
} 