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

struct SettingsView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Header
                ZStack(alignment: .bottomLeading) {
                    // Gray Background
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(height: 150)
                    
                    // Profile Picture
                    Image(systemName: "person.circle.fill") // TODO: Replace with actual profile picture
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .padding(.leading)
                        .padding(.bottom, -40)
                    
                    // Logout Button
                    Button(action: {
                        Task {
                            await viewModel.handleSignOut()
                        }
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .offset(x: UIScreen.main.bounds.width - 60)
                }
                
                // Bio Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.name.isEmpty ? "User" : viewModel.name) // Use dynamic name from viewModel
                        .font(.title2)
                        .bold()
                        .padding(.leading)
                        .padding(.top, 45)
                    
                    // Follower Stats
                    HStack {
                        Spacer()
                            .frame(maxWidth: 30) // Reduced left spacing
                        VStack {
                            Text("1.2K")
                                .font(.headline)
                                .bold()
                            Text("Followers")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                            .frame(maxWidth: 40) // Reduced spacing between stats
                        
                        VStack {
                            Text("850")
                                .font(.headline)
                                .bold()
                            Text("Following")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    Text("Software developer passionate about creating amazing apps and sharing knowledge with others.") // TODO: Replace with actual bio
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // Profile Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            // Edit profile functionality will go here
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            // Share profile functionality will go here
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Profile")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .padding(.bottom, 8)
                }
                
                // Content Tabs
                VStack(spacing: 0) {
                    // Tab Headers
                    HStack {
                        ForEach(["Posts", "Articles", "Streams", "Classes"], id: \.self) { tab in
                            VStack {
                                Text(tab)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 8)
                                    .foregroundColor(selectedTab == getTabIndex(tab) ? .primary : .gray)
                                
                                Rectangle()
                                    .fill(selectedTab == getTabIndex(tab) ? Color.blue : Color.clear)
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                withAnimation {
                                    selectedTab = getTabIndex(tab)
                                }
                            }
                        }
                    }
                    
                    // Tab Content
                    TabView(selection: $selectedTab) {
                        PostsTabView()
                            .tag(0)
                        
                        ArticlesTabView()
                            .tag(1)
                        
                        StreamsTabView()
                            .tag(2)
                        
                        ClassesTabView()
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: UIScreen.main.bounds.height * 0.5)
                }
            }
        }
    }
    
    private func getTabIndex(_ tab: String) -> Int {
        switch tab {
        case "Posts": return 0
        case "Articles": return 1
        case "Streams": return 2
        case "Classes": return 3
        default: return 0
        }
    }
}

// Placeholder Tab Views
struct PostsTabView: View {
    // Sample data - replace with actual posts later
    let posts = ["post1", "post2", "post3", "post4", "post5", "post6", "post7", "post8", "post9"]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(posts, id: \.self) { post in
                    Color(.systemGray6) // Placeholder for actual image
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundColor(.gray)
                        )
                }
            }
        }
    }
}

struct ArticlesTabView: View {
    var body: some View {
        Text("Articles")
    }
}

struct StreamsTabView: View {
    var body: some View {
        Text("Streams")
    }
}

struct ClassesTabView: View {
    var body: some View {
        Text("Classes")
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
            SettingsView(viewModel: viewModel)
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