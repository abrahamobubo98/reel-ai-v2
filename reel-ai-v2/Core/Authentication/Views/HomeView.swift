import SwiftUI
import AVKit
import AVFoundation

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
        let asset = AVURLAsset(url: url)
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
            
            // Caption
            Text(post.caption)
                .padding(.horizontal)
            
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
                debugPrint("📱 PostView: Loading comments for post \(post.id)")
                comments = try await appwrite.fetchComments(documentId: post.id)
                debugPrint("📱 PostView: Successfully loaded \(comments.count) comments")
            } catch {
                debugPrint("📱 PostView: Error loading comments: \(error)")
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
                debugPrint("📱 PostView: Adding comment to post \(post.id)")
                debugPrint("📱 PostView: Comment text: \(commentText)")
                
                let comment = try await appwrite.createComment(
                    text: commentText,
                    documentId: post.id,
                    collectionId: AppwriteService.postsCollectionId
                )
                
                debugPrint("📱 PostView: Successfully added comment: \(comment)")
                
                await MainActor.run {
                    commentText = ""
                    comments.insert(comment, at: 0)
                    isAddingComment = false
                }
            } catch {
                debugPrint("📱 PostView: Error adding comment: \(error)")
                errorMessage = "Failed to add comment"
                isAddingComment = false
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var selectedTab = 0
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var showEditProfile = false
    
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
                            showEditProfile = true
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
                        .sheet(isPresented: $showEditProfile) {
                            EditProfileView(viewModel: viewModel)
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
                        
                        ArticlesTabView(viewModel: homeViewModel)
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

struct ArticlesTabView: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if viewModel.articles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No articles yet")
                        .font(.headline)
                    Text("Be the first to write an article!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.articles) { article in
                        ArticlePreviewView(article: article)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .refreshable {
            await viewModel.loadArticles()
        }
        .task {
            await viewModel.loadArticles()
        }
    }
}

struct ArticlePreviewView: View {
    let article: Article
    @State private var showDetail = false
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var isLoading = false
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

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var name: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(viewModel: AuthenticationViewModel) {
        self.viewModel = viewModel
        _name = State(initialValue: viewModel.name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Name", text: $name)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private func saveProfile() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await viewModel.updateProfile(name: name)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
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
                        if homeViewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if let error = homeViewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                        } else if homeViewModel.posts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("No posts yet")
                                    .font(.headline)
                                Text("Be the first to share something!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 20) {
                                ForEach(homeViewModel.posts, id: \.id) { post in
                                    PostView(post: post)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                    } else {
                        // Articles View
                        if homeViewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if let error = homeViewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                        } else if homeViewModel.articles.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("No articles yet")
                                    .font(.headline)
                                Text("Be the first to write an article!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(homeViewModel.articles) { article in
                                    ArticlePreviewView(article: article)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
                .refreshable {
                    if selectedFeed == .posts {
                        homeViewModel.loadPosts()
                    } else {
                        Task {
                            await homeViewModel.loadArticles()
                        }
                    }
                }
            }
            .onChange(of: selectedFeed) { oldValue, newValue in
                if newValue == .posts {
                    homeViewModel.loadPosts()
                } else {
                    Task {
                        await homeViewModel.loadArticles()
                    }
                }
            }
            .onAppear {
                if selectedFeed == .posts {
                    homeViewModel.loadPosts()
                } else {
                    Task {
                        await homeViewModel.loadArticles()
                    }
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

#Preview {
    let viewModel = AuthenticationViewModel()
    return HomeView(viewModel: viewModel)
} 