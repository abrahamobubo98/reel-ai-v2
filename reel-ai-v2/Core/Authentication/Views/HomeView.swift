import SwiftUI
import AVKit
import AVFoundation

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

class VideoThumbnailLoader: ObservableObject {
    @Published var thumbnail: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadThumbnail(from urlString: String) {
        print("📱 VideoThumbnailLoader: Starting thumbnail generation for URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            let error = NSError(domain: "VideoThumbnailLoader", code: -1, 
                              userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
            print("📱 VideoThumbnailLoader Error: \(error.localizedDescription)")
            self.error = error
            return
        }
        
        isLoading = true
        print("📱 VideoThumbnailLoader: Creating AVAsset")
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 400, height: 400)
        
        // Request thumbnail at 0.1 seconds to avoid black frames at the start
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        Task {
            do {
                print("📱 VideoThumbnailLoader: Starting thumbnail generation")
                
                // First, check if the asset is ready to generate thumbnails
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard !tracks.isEmpty else {
                    throw NSError(domain: "VideoThumbnailLoader", code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "No video tracks found in asset"])
                }
                
                if #available(iOS 16.0, *) {
                    print("📱 VideoThumbnailLoader: Using iOS 16+ method")
                    let cgImage = try await imageGenerator.image(at: time).image
                    await MainActor.run {
                        self.thumbnail = UIImage(cgImage: cgImage)
                        self.isLoading = false
                        print("📱 VideoThumbnailLoader: Successfully generated thumbnail (iOS 16+)")
                    }
                } else {
                    print("📱 VideoThumbnailLoader: Using pre-iOS 16 method")
                    var actualTime = CMTime.zero
                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: &actualTime)
                    await MainActor.run {
                        self.thumbnail = UIImage(cgImage: cgImage)
                        self.isLoading = false
                        print("📱 VideoThumbnailLoader: Successfully generated thumbnail (pre-iOS 16)")
                    }
                }
            } catch {
                print("📱 VideoThumbnailLoader Error: \(error.localizedDescription)")
                if let avError = error as? AVError {
                    print("📱 VideoThumbnailLoader AVError Code: \(avError.code.rawValue)")
                }
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

class VideoPlayerViewModel: NSObject, ObservableObject {
    @Published var error: Error?
    let player: AVPlayer
    
    init(url: URL) {
        self.player = AVPlayer(url: url)
        super.init()
        player.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
    }
    
    deinit {
        player.removeObserver(self, forKeyPath: "status")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let player = object as? AVPlayer {
            print("📱 Video player status changed: \(player.status.rawValue)")
            if player.status == .failed {
                print("📱 Video player error: \(String(describing: player.error))")
                DispatchQueue.main.async {
                    self.error = player.error
                }
            }
        }
    }
}

struct VideoPlayerView: View {
    let url: URL
    @StateObject private var viewModel: VideoPlayerViewModel
    
    init(url: URL) {
        self.url = url
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(url: url))
    }
    
    var body: some View {
        VideoPlayer(player: viewModel.player)
            .onAppear {
                print("📱 Attempting to play video from URL: \(url.absoluteString)")
            }
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
                Text(getUserName(from: post.userId))
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
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    // Helper function to get user name from ID
    private func getUserName(from userId: String) -> String {
        // For now, return a formatted name. In a real app, this would fetch the actual user name
        return "User \(String(userId.prefix(4)))"
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

struct PostsTabView: View {
    @StateObject private var viewModel = UserPostsViewModel()
    let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
    private let appwrite = AppwriteService.shared
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(viewModel.posts, id: \.id) { post in
                        PostThumbnailView(post: post)
                            .id(post.id) // Add explicit id to help SwiftUI with view identity
                    }
                }
            }
        }
        .task {
            print("📱 PostsTabView: Loading user posts")
            await viewModel.loadUserPosts()
        }
        .onAppear {
            print("📱 PostsTabView: View appeared")
            print("📱 PostsTabView: Current posts count: \(viewModel.posts.count)")
        }
        .onDisappear {
            print("📱 PostsTabView: View disappeared")
        }
    }
}

struct VideoThumbnailContent: View {
    let post: Post
    @ObservedObject var thumbnailLoader: VideoThumbnailLoader
    let cache: MediaCache
    
    var body: some View {
        if let cachedThumbnail = cache.getImage(forKey: post.mediaId, isThumbnail: true) {
            Image(uiImage: cachedThumbnail)
                .resizable()
                .scaledToFill()
        } else if thumbnailLoader.isLoading {
            ProgressView()
        } else if let thumbnail = thumbnailLoader.thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .onAppear {
                    cache.cacheImage(thumbnail, forKey: post.mediaId, isThumbnail: true)
                }
        } else if thumbnailLoader.error != nil {
            Image(systemName: "video.slash.fill")
                .font(.title)
                .foregroundColor(.gray)
        } else {
            Color.clear
                .onAppear {
                    print("📱 Loading video thumbnail for post \(post.id)")
                    let videoUrl = AppwriteService.shared.getMediaUrl(mediaId: post.mediaId, isVideo: true, forThumbnail: false)
                    print("📱 Using video URL for thumbnail generation: \(videoUrl)")
                    thumbnailLoader.loadThumbnail(from: videoUrl)
                }
        }
    }
}

struct ImageThumbnailContent: View {
    let post: Post
    let cache: MediaCache
    let appwrite: AppwriteService
    @State private var displayImage: UIImage?
    
    var body: some View {
        ZStack {
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // First try to get from cache
        if let cachedImage = cache.getImage(forKey: post.mediaId) {
            print("📱 ImageThumbnailContent: Loading from cache for post \(post.id)")
            displayImage = cachedImage
            return
        }
        
        // If not in cache, load from URL
        let imageUrl = appwrite.getMediaUrl(mediaId: post.mediaId, isVideo: false)
        print("📱 ImageThumbnailContent: Loading from URL for post \(post.id): \(imageUrl)")
        
        guard let url = URL(string: imageUrl) else {
            print("📱 ImageThumbnailContent: Invalid URL for post \(post.id)")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("📱 ImageThumbnailContent: Error loading image for post \(post.id): \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("📱 ImageThumbnailContent: Invalid image data for post \(post.id)")
                return
            }
            
            DispatchQueue.main.async {
                print("📱 ImageThumbnailContent: Successfully loaded image for post \(post.id)")
                self.cache.cacheImage(image, forKey: post.mediaId)
                self.displayImage = image
            }
        }.resume()
    }
}

struct PostThumbnailView: View {
    let post: Post
    @State private var showDetail = false
    @StateObject private var thumbnailLoader = VideoThumbnailLoader()
    private let appwrite = AppwriteService.shared
    private let cache = MediaCache.shared
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if post.mediaType == .video {
                    VideoThumbnailContent(post: post, thumbnailLoader: thumbnailLoader, cache: cache)
                } else {
                    ImageThumbnailContent(post: post, cache: cache, appwrite: appwrite)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipped()
            .overlay(
                Group {
                    if post.mediaType == .video {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                }
            )
            .onTapGesture {
                showDetail = true
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .sheet(isPresented: $showDetail) {
            PostDetailView(post: post)
        }
    }
}

// Add extension to convert SwiftUI Image to UIImage
extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        
        // Ensure the controller's view is using the correct size
        let targetSize = controller.view.intrinsicContentSize
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = .clear
        
        // Render synchronously to avoid lifecycle issues
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let uiImage = renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: false)
        }
        
        return uiImage.cgImage != nil ? uiImage : nil
    }
}

struct PostDetailView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    private let appwrite = AppwriteService.shared
    private let cache = MediaCache.shared
    
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
                            Text(post.userId)
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
                            Image(systemName: "heart")
                            Text("\(post.likes)")
                            
                            Image(systemName: "message")
                                .padding(.leading)
                            Text("\(post.comments)")
                            
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
    @State private var selectedFeed: FeedType = .posts
    
    enum FeedType {
        case posts
        case articles
    }
    
    var body: some View {
        TabView {
            // Home Tab
            VStack(spacing: 0) {
                // Feed Toggle
                HStack {
                    Picker("Feed Type", selection: $selectedFeed) {
                        Text("Posts").tag(FeedType.posts)
                        Text("Articles").tag(FeedType.articles)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // Content
                ScrollView {
                    if selectedFeed == .posts {
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
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(1...5, id: \.self) { index in
                                ArticlePreviewView(index: index)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .refreshable {
                    if selectedFeed == .posts {
                        homeViewModel.loadPosts()
                    }
                }
            }
            .onAppear {
                if selectedFeed == .posts {
                    homeViewModel.loadPosts()
                }
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

struct ArticlePreviewView: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                Text("Author \(index)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
            
            // Article Title
            Text("Sample Article \(index)")
                .font(.title2)
                .fontWeight(.bold)
            
            // Article Preview
            Text("This is a placeholder for article \(index). It will contain a preview of the article content. The actual implementation will fetch real articles from the backend.")
                .font(.body)
                .foregroundColor(.gray)
                .lineLimit(3)
            
            // Metadata
            HStack {
                Image(systemName: "eye")
                Text("\(Int.random(in: 100...1000))")
                
                Image(systemName: "hand.thumbsup")
                    .padding(.leading)
                Text("\(Int.random(in: 10...100))")
                
                Image(systemName: "message")
                    .padding(.leading)
                Text("\(Int.random(in: 5...50))")
                
                Spacer()
                
                Text("\(Int.random(in: 1...24))h ago")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

#Preview {
    let viewModel = AuthenticationViewModel()
    return HomeView(viewModel: viewModel)
} 