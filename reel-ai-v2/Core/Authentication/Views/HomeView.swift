import SwiftUI
import AVKit

class HomeViewModel: ObservableObject {
    @Published var posts: [Post] = []
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
    
    deinit {
        loadingTask?.cancel()
    }
}

struct PostView: View {
    let post: Post
    let appwrite = AppwriteService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User info
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                Text(post.userId) // TODO: Replace with actual name when available
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Image or Video
            if post.mediaType == .video {
                VideoPlayer(player: AVPlayer(url: URL(string: appwrite.getMediaUrl(mediaId: post.mediaId, isVideo: true))!))
                    .frame(maxWidth: .infinity, minHeight: 300)
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
            
            // Caption
            Text(post.caption)
                .padding(.horizontal)
            
            // Metadata
            HStack {
                Image(systemName: "heart")
                Text("\(post.likes)")
                
                Image(systemName: "message")
                Text("\(post.comments)")
                
                Spacer()
                
                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            // Debug JSON Data
            VStack(alignment: .leading, spacing: 4) {
                Text("Debug Data:")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("Post ID: \(post.id)")
                    Text("User ID: \(post.userId)")
                    Text("Media ID: \(post.mediaId)")
                    Text("Media Type: \(post.mediaType.rawValue)")
                    Text("Media URL: \(appwrite.getMediaUrl(mediaId: post.mediaId, isVideo: post.mediaType == .video))")
                    Text("Caption: \(post.caption)")
                    Text("Created: \(post.createdAt.formatted())")
                    Text("Likes: \(post.likes)")
                    Text("Comments: \(post.comments)")
                }
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct HomeView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @StateObject private var homeViewModel = HomeViewModel()
    
    var body: some View {
        TabView {
            // Home Tab
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(homeViewModel.posts, id: \.id) { post in
                        PostView(post: post)
                            .padding(.horizontal)
                    }
                    
                    if homeViewModel.isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    if let error = homeViewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                homeViewModel.loadPosts()
            }
            .onAppear {
                homeViewModel.loadPosts()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            
            // Search Tab
            VStack(spacing: 20) {
                Text("Search")
                    .font(.largeTitle)
                    .bold()
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            
            // Create Tab
            CreateView()
            .tabItem {
                Image(systemName: "plus.square.fill")
                Text("Create")
            }
            
            // Notifications Tab
            VStack(spacing: 20) {
                Text("Notifications")
                    .font(.largeTitle)
                    .bold()
            }
            .tabItem {
                Image(systemName: "bell.fill")
                Text("Notifications")
            }
            
            // Settings Tab
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.largeTitle)
                    .bold()
                
                Button(action: {
                    Task {
                        await viewModel.handleSignOut()
                    }
                }) {
                    Text("Sign out")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
        }
    }
}

#Preview {
    let viewModel = AuthenticationViewModel()
    return HomeView(viewModel: viewModel)
} 