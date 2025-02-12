import Foundation
import Appwrite
import JSONCodable
import UIKit

class MediaCache {
    static let shared = MediaCache()
    
    private let imageCache = NSCache<NSString, UIImage>()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    private init() {
        // Set cache limits (adjust these based on your app's memory requirements)
        imageCache.countLimit = 100  // Maximum number of images
        imageCache.totalCostLimit = 1024 * 1024 * 100  // 100 MB
        
        thumbnailCache.countLimit = 200  // Maximum number of thumbnails
        thumbnailCache.totalCostLimit = 1024 * 1024 * 50  // 50 MB
    }
    
    func cacheImage(_ image: UIImage, forKey key: String, isThumbnail: Bool = false) {
        let cache = isThumbnail ? thumbnailCache : imageCache
        cache.setObject(image, forKey: key as NSString)
    }
    
    func getImage(forKey key: String, isThumbnail: Bool = false) -> UIImage? {
        let cache = isThumbnail ? thumbnailCache : imageCache
        return cache.object(forKey: key as NSString)
    }
    
    func clearCache() {
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }
}

/// Custom errors for storage operations
enum StorageError: LocalizedError {
    case invalidImage
    case invalidVideo
    case compressionFailed
    case sizeTooLarge(size: Int)
    case uploadFailed(String)
    case invalidFormat
    case videoProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image is invalid"
        case .invalidVideo:
            return "The provided video is invalid"
        case .compressionFailed:
            return "Failed to compress the media"
        case .sizeTooLarge(let size):
            return "Media size (\(size)MB) exceeds maximum allowed size (100MB)"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .invalidFormat:
            return "Invalid format. Only JPEG, PNG, and MOV/MP4 are supported"
        case .videoProcessingFailed:
            return "Failed to process video file"
        }
    }
}

/// Custom errors for database operations
enum DatabaseError: LocalizedError {
    case invalidPost
    case creationFailed(String)
    case unauthorized
    case updateFailed(String)
    case fetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPost:
            return "Invalid post data"
        case .creationFailed(let reason):
            return "Failed to create post: \(reason)"
        case .unauthorized:
            return "You must be logged in to create a post"
        case .updateFailed(let reason):
            return "Failed to update post: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch post: \(reason)"
        }
    }
}

/// Post model for database operations
struct Post: Codable, Identifiable {
    let id: String
    let userId: String
    let author: String
    let mediaId: String
    let mediaType: MediaType
    let caption: String
    let externalLink: String
    let createdAt: Date
    let updatedAt: Date
    let category: String
    let collaborators: [String]
    let likes: Int
    let comments: Int
    let sharesCount: Int
    
    enum MediaType: String, Codable {
        case photo
        case video
    }
    
    init(id: String, userId: String, author: String, mediaId: String, mediaType: MediaType = .photo, caption: String, externalLink: String = "", createdAt: Date, updatedAt: Date = Date(), category: String = "", collaborators: [String] = [], likes: Int = 0, comments: Int = 0, sharesCount: Int = 0) {
        self.id = id
        self.userId = userId
        self.author = author
        self.mediaId = mediaId
        self.mediaType = mediaType
        self.caption = caption
        self.externalLink = externalLink
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
        self.collaborators = collaborators
        self.likes = likes
        self.comments = comments
        self.sharesCount = sharesCount
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case userId
        case author
        case mediaId
        case mediaType
        case caption
        case externalLink
        case createdAt
        case updatedAt
        case category
        case collaborators
        case likes
        case comments
        case sharesCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        author = try container.decode(String.self, forKey: .author)
        mediaId = try container.decode(String.self, forKey: .mediaId)
        mediaType = try container.decode(MediaType.self, forKey: .mediaType)
        caption = try container.decode(String.self, forKey: .caption)
        externalLink = try container.decode(String.self, forKey: .externalLink)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        category = try container.decode(String.self, forKey: .category)
        collaborators = try container.decode([String].self, forKey: .collaborators)
        likes = try container.decode(Int.self, forKey: .likes)
        comments = try container.decode(Int.self, forKey: .comments)
        sharesCount = try container.decode(Int.self, forKey: .sharesCount)
        
        // Handle ISO 8601 date format from Appwrite
        if let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                createdAt = date
            } else {
                throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Date string does not match expected format")
            }
        } else {
            createdAt = Date()
        }
    }
}

/// Add a UserInfo struct
struct UserInfo {
    let id: String
    let name: String
    let email: String
}

/// Service class to handle all Appwrite related operations
class AppwriteService {
    // MARK: - Properties
    static let shared = AppwriteService()
    
    // MARK: - Public Constants
    static let postsCollectionId = Config.shared.appwritePostsCollectionId
    static let articlesCollectionId = Config.shared.appwriteArticlesCollectionId
    static let likesCollectionId = Config.shared.appwriteLikesCollectionId
    static let commentsCollectionId = Config.shared.appwriteCommentsCollectionId
    
    // Database ID
    static let databaseId = Config.shared.appwriteDatabaseId
    
    var client: Client
    var account: Account
    var storage: Storage
    var databases: Databases
    
    // MARK: - Constants
    /// Constants used throughout the service
    enum Constants {
        static let endpoint = Config.shared.appwriteEndpoint
        static let projectId = Config.shared.appwriteProjectId
        static let postMediaBucketId = Config.shared.appwritePostMediaBucketId
        static let apiKey = Config.shared.appwriteApiKey
        static let maxImageSizeMB = 10
        static let maxVideoSizeMB = 100
        static let compressionQuality: CGFloat = 0.8
        static let maxRetryAttempts = 3
        static let databaseId = Config.shared.appwriteDatabaseId
        static let usersCollectionId = Config.shared.appwriteUsersCollectionId
        static let storageId = Config.shared.appwriteStorageId
        static let bucketId = Config.shared.appwriteBucketId
    }
    
    // Add user cache to avoid repeated fetches
    private var userCache: [String: UserInfo] = [:]
    
    private init() {
        // Debug logging for configuration
        print("📱 Checking configuration:")
        print("APPWRITE_ENDPOINT: \(Constants.endpoint.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_PROJECT_ID: \(Constants.projectId.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_API_KEY: \(Constants.apiKey.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_DATABASE_ID: \(Constants.databaseId.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_POST_MEDIA_BUCKET_ID: \(Constants.postMediaBucketId.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_POSTS_COLLECTION_ID: \(Self.postsCollectionId.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_ARTICLES_COLLECTION_ID: \(Self.articlesCollectionId.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_LIKES_COLLECTION_ID: \(Self.likesCollectionId.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_COMMENTS_COLLECTION_ID: \(Self.commentsCollectionId.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_USERS_COLLECTION_ID: \(Constants.usersCollectionId.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_STORAGE_ID: \(Constants.storageId.isEmpty ? "MISSING" : "PRESENT")")
        print("APPWRITE_BUCKET_ID: \(Constants.bucketId.isEmpty ? "MISSING" : "PRESENT")")
        
        // Validate configuration
        guard !Constants.endpoint.isEmpty else {
            fatalError("Appwrite endpoint not configured")
        }
        guard !Constants.projectId.isEmpty else {
            fatalError("Appwrite project ID not configured")
        }
        guard !Constants.apiKey.isEmpty else {
            fatalError("Appwrite API key not configured")
        }
        guard !Constants.databaseId.isEmpty else {
            fatalError("Appwrite database ID not configured")
        }
        guard !Constants.postMediaBucketId.isEmpty else {
            fatalError("Appwrite post media bucket ID not configured")
        }
        guard !Self.postsCollectionId.isEmpty else {
            fatalError("Appwrite posts collection ID not configured")
        }
        guard !Self.articlesCollectionId.isEmpty else {
            fatalError("Appwrite articles collection ID not configured")
        }
        guard !Self.likesCollectionId.isEmpty else {
            fatalError("Appwrite likes collection ID not configured")
        }
        guard !Self.commentsCollectionId.isEmpty else {
            fatalError("Appwrite comments collection ID not configured")
        }
        guard !Constants.usersCollectionId.isEmpty else {
            fatalError("Appwrite users collection ID not configured")
        }
        guard !Constants.storageId.isEmpty else {
            fatalError("Appwrite storage ID not configured")
        }
        guard !Constants.bucketId.isEmpty else {
            fatalError("Appwrite bucket ID not configured")
        }
        
        self.client = Client()
            .setEndpoint(Constants.endpoint)
            .setProject(Constants.projectId)
            .setSelfSigned() // Remove in production
        
        self.account = Account(client)
        self.storage = Storage(client)
        self.databases = Databases(client)
    }
    
    // MARK: - Database Methods
    
    /// Fetches posts with pagination, sorted by creation date
    func fetchPosts(limit: Int = 10, offset: Int = 0) async throws -> [Post] {
        do {
            debugPrint("📱 Fetching posts with limit: \(limit), offset: \(offset)")
            debugPrint("📱 Using database ID: \(AppwriteService.databaseId)")
            debugPrint("📱 Using collection ID: \(Self.postsCollectionId)")
            
            let documents = try await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.postsCollectionId,
                queries: [
                    Query.orderDesc("createdAt"),
                    Query.limit(limit),
                    Query.offset(offset)
                ]
            )
            
            debugPrint("📱 Raw response - total documents: \(documents.total)")
            
            var posts: [Post] = []
            for document in documents.documents {
                debugPrint("📱 Processing document: \(document.id)")
                debugPrint("📱 Document data: \(document.data)")
                
                // Extract values from AnyCodable with detailed logging
                let userId = (document.data["userId"]?.value as? String) ?? ""
                let author = (document.data["author"]?.value as? String) ?? "Unknown User"
                let mediaId = (document.data["mediaId"]?.value as? String) ?? ""
                let caption = (document.data["caption"]?.value as? String) ?? ""
                let dateString = (document.data["createdAt"]?.value as? String) ?? ""
                let updatedDateString = (document.data["updatedAt"]?.value as? String) ?? dateString
                let category = (document.data["category"]?.value as? String) ?? ""
                let collaborators = (document.data["collaborators"]?.value as? [String]) ?? []
                let likes = (document.data["likes"]?.value as? Int) ?? 0
                let comments = (document.data["comments"]?.value as? Int) ?? 0
                let sharesCount = (document.data["sharesCount"]?.value as? Int) ?? 0
                let mediaTypeString = (document.data["mediaType"]?.value as? String) ?? "photo"
                
                debugPrint("📱 Extracted fields - userId: \(userId), mediaId: \(mediaId), dateString: \(dateString)")
                
                // Skip documents that don't have required fields
                guard !mediaId.isEmpty else {
                    debugPrint("📱 Skipping document \(document.id) - missing mediaId")
                    continue
                }
                
                // Create post with all fields
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = formatter.date(from: dateString) ?? Date()
                let updatedDate = formatter.date(from: updatedDateString) ?? date
                
                let post = Post(
                    id: document.id,
                    userId: userId,
                    author: author,
                    mediaId: mediaId,
                    mediaType: Post.MediaType(rawValue: mediaTypeString) ?? .photo,
                    caption: caption,
                    externalLink: (document.data["externalLink"]?.value as? String) ?? "",
                    createdAt: date,
                    updatedAt: updatedDate,
                    category: category,
                    collaborators: collaborators,
                    likes: likes,
                    comments: comments,
                    sharesCount: sharesCount
                )
                
                debugPrint("📱 Successfully created post: \(post.id)")
                posts.append(post)
            }
            
            debugPrint("📱 Successfully parsed \(posts.count) posts")
            return posts
            
        } catch let error as AppwriteError {
            debugPrint("📱 Appwrite error fetching posts: \(String(describing: error.type)) - \(String(describing: error.message))")
            throw DatabaseError.creationFailed("Appwrite error: \(String(describing: error.message))")
        } catch {
            debugPrint("📱 Unexpected error fetching posts: \(error)")
            throw DatabaseError.creationFailed(error.localizedDescription)
        }
    }
    
    /// Creates a new post in the database
    func createPost(mediaId: String, caption: String, mediaType: Post.MediaType = .photo, externalLink: String = "") async throws -> Post {
        do {
            debugPrint("📱 Starting post creation process...")
            
            // Get current user
            let user = try await account.get()
            debugPrint("📱 Got user: \(user.id)")
            
            // Create ISO 8601 date string
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = formatter.string(from: Date())
            debugPrint("📱 Created date string: \(dateString)")
            
            // Create post document with all required fields
            debugPrint("📱 Attempting to create document with mediaId: \(mediaId)")
            let document = try await databases.createDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.postsCollectionId,
                documentId: ID.unique(),
                data: [
                    "userId": user.id,
                    "author": user.name,
                    "mediaId": mediaId,
                    "mediaType": mediaType.rawValue,
                    "caption": caption,
                    "externalLink": externalLink,
                    "createdAt": dateString,
                    "updatedAt": dateString,
                    "likes": 0,
                    "comments": 0,
                    "category": "",
                    "collaborators": [],
                    "sharesCount": 0
                ]
            )
            debugPrint("📱 Document created successfully with ID: \(document.id)")
            
            // Create Post object from document data
            let post = Post(
                id: document.id,
                userId: document.data["userId"]?.value as? String ?? user.id,
                author: document.data["author"]?.value as? String ?? user.name,
                mediaId: document.data["mediaId"]?.value as? String ?? mediaId,
                mediaType: Post.MediaType(rawValue: document.data["mediaType"]?.value as? String ?? mediaType.rawValue) ?? mediaType,
                caption: document.data["caption"]?.value as? String ?? caption,
                externalLink: document.data["externalLink"]?.value as? String ?? externalLink,
                createdAt: formatter.date(from: document.data["createdAt"]?.value as? String ?? dateString) ?? Date(),
                updatedAt: formatter.date(from: document.data["updatedAt"]?.value as? String ?? dateString) ?? Date(),
                category: document.data["category"]?.value as? String ?? "",
                collaborators: document.data["collaborators"]?.value as? [String] ?? [],
                likes: document.data["likes"]?.value as? Int ?? 0,
                comments: document.data["comments"]?.value as? Int ?? 0,
                sharesCount: document.data["sharesCount"]?.value as? Int ?? 0
            )
            
            debugPrint("📱 Post object created successfully: \(post)")
            return post
            
        } catch let error as AppwriteError {
            debugPrint("📱 Appwrite error during post creation: \(String(describing: error.type)) - \(String(describing: error.message))")
            switch error.type {
            case "user_unauthorized":
                throw DatabaseError.unauthorized
            default:
                throw DatabaseError.creationFailed("Appwrite error: \(String(describing: error.message))")
            }
        } catch {
            debugPrint("📱 Unexpected error during post creation: \(error)")
            throw DatabaseError.creationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Article Methods
    
    /// Creates a new article in the database
    func createArticle(title: String, content: String, coverImageId: String? = nil, tags: [String] = []) async throws -> Article {
        do {
            print("📱 AppwriteService: Starting article creation")
            print("📱 AppwriteService: Using database ID: \(AppwriteService.databaseId)")
            print("📱 AppwriteService: Using collection ID: \(Self.articlesCollectionId)")
            
            // Get current user
            let user = try await account.get()
            print("📱 AppwriteService: Got user: \(user.id)")
            
            // Create ISO 8601 date string
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = formatter.string(from: Date())
            print("📱 AppwriteService: Created date string: \(dateString)")
            
            // Create article document
            print("📱 AppwriteService: Attempting to create article document")
            let document = try await databases.createDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.articlesCollectionId,
                documentId: ID.unique(),
                data: [
                    "userId": user.id,
                    "author": user.name,
                    "title": title,
                    "content": content,
                    "coverImageId": coverImageId ?? "",
                    "tags": tags,
                    "createdAt": dateString,
                    "updatedAt": dateString,
                    "likes": 0,
                    "views": 0
                ]
            )
            print("📱 AppwriteService: Document created successfully with ID: \(document.id)")
            print("📱 AppwriteService: Raw document data: \(document.data)")
            
            // Create Article object from document data
            let article = Article(
                id: document.id,
                userId: document.data["userId"]?.value as? String ?? user.id,
                author: document.data["author"]?.value as? String ?? user.name,
                title: document.data["title"]?.value as? String ?? title,
                content: document.data["content"]?.value as? String ?? content,
                summary: nil,
                thumbnailUrl: nil,
                createdAt: formatter.date(from: document.data["createdAt"]?.value as? String ?? dateString) ?? Date(),
                updatedAt: formatter.date(from: document.data["updatedAt"]?.value as? String ?? dateString) ?? Date(),
                status: .published,
                tags: document.data["tags"]?.value as? [String] ?? [],
                likes: document.data["likes"]?.value as? Int ?? 0,
                views: document.data["views"]?.value as? Int ?? 0,
                readingTime: 0,
                commentCount: 0
            )
            
            print("📱 AppwriteService: Article object created successfully: \(article)")
            return article
            
        } catch let error as AppwriteError {
            print("📱 AppwriteService: Appwrite error during article creation: \(String(describing: error.type)) - \(String(describing: error.message))")
            switch error.type {
            case "user_unauthorized":
                throw DatabaseError.unauthorized
            default:
                throw DatabaseError.creationFailed("Appwrite error: \(String(describing: error.message))")
            }
        } catch {
            print("📱 AppwriteService: Unexpected error during article creation: \(error)")
            throw DatabaseError.creationFailed(error.localizedDescription)
        }
    }
    
    /// Fetches articles with pagination, sorted by creation date
    func fetchArticles(limit: Int = 10, offset: Int = 0) async throws -> [Article] {
        do {
            debugPrint("📱 Fetching articles with limit: \(limit), offset: \(offset)")
            
            let documents = try await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.articlesCollectionId,
                queries: [
                    Query.orderDesc("createdAt"),
                    Query.limit(limit),
                    Query.offset(offset)
                ]
            )
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            var articles: [Article] = []
            for document in documents.documents {
                let data = document.data
                
                let article = Article(
                    id: document.id,
                    userId: data["userId"]?.value as? String ?? "",
                    author: data["author"]?.value as? String ?? "Unknown User",
                    title: data["title"]?.value as? String ?? "",
                    content: data["content"]?.value as? String ?? "",
                    summary: nil,
                    thumbnailUrl: nil,
                    createdAt: formatter.date(from: data["createdAt"]?.value as? String ?? "") ?? Date(),
                    updatedAt: formatter.date(from: data["updatedAt"]?.value as? String ?? "") ?? Date(),
                    status: .published,
                    tags: data["tags"]?.value as? [String] ?? [],
                    likes: data["likes"]?.value as? Int ?? 0,
                    views: data["views"]?.value as? Int ?? 0,
                    readingTime: 0,
                    commentCount: 0
                )
                
                articles.append(article)
            }
            
            debugPrint("📱 Successfully fetched \(articles.count) articles")
            return articles
            
        } catch {
            debugPrint("📱 Error fetching articles: \(error)")
            throw error
        }
    }
    
    /// Updates an existing article
    func updateArticle(_ article: Article) async throws -> Article {
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let updateDateString = formatter.string(from: Date())
            
            let document = try await databases.updateDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.articlesCollectionId,
                documentId: article.id,
                data: [
                    "title": article.title,
                    "content": article.content,
                    "thumbnailUrl": article.thumbnailUrl?.absoluteString ?? "",
                    "tags": article.tags,
                    "updatedAt": updateDateString
                ]
            )
            
            return Article(
                id: document.id,
                userId: article.userId,
                author: article.author,
                title: document.data["title"]?.value as? String ?? article.title,
                content: document.data["content"]?.value as? String ?? article.content,
                summary: nil,
                thumbnailUrl: nil,
                createdAt: article.createdAt,
                updatedAt: formatter.date(from: updateDateString) ?? Date(),
                status: article.status,
                tags: document.data["tags"]?.value as? [String] ?? article.tags,
                likes: article.likes,
                views: article.views,
                readingTime: article.readingTime,
                commentCount: article.commentCount
            )
            
        } catch {
            debugPrint("📱 Error updating article: \(error)")
            throw error
        }
    }
    
    // MARK: - Storage Methods
    
    /// Validates an image before upload
    private func validateImage(_ image: UIImage) throws {
        // Check image validity
        guard image.size.width > 0 && image.size.height > 0 else {
            throw StorageError.invalidImage
        }
        
        // Convert to data to check size
        guard let imageData = image.jpegData(compressionQuality: Constants.compressionQuality) else {
            throw StorageError.compressionFailed
        }
        
        // Check file size (in MB)
        let imageSizeMB = Double(imageData.count) / 1_000_000
        guard imageSizeMB <= Double(Constants.maxImageSizeMB) else {
            throw StorageError.sizeTooLarge(size: Int(imageSizeMB))
        }
    }
    
    /// Uploads an image with progress tracking and retry logic
    func uploadImage(
        _ image: UIImage,
        progress: ((Double) -> Void)? = nil
    ) async throws -> String {
        // Validate image
        try validateImage(image)
        
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: Constants.compressionQuality) else {
            throw StorageError.compressionFailed
        }
        
        // Create file input
        let file = InputFile.fromData(
            imageData,
            filename: "\(UUID().uuidString).jpg",
            mimeType: "image/jpeg"
        )
        
        // Upload with retry
        return try await uploadWithRetry(file: file, progress: progress)
    }
    
    /// Uploads a video file with progress tracking and retry logic
    func uploadVideo(
        from videoURL: URL,
        progress: ((Double) -> Void)? = nil
    ) async throws -> String {
        // Get video file size without loading entire file
        let resourceValues = try videoURL.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = resourceValues.fileSize else {
            throw StorageError.invalidVideo
        }
        
        let videoSizeMB = Double(fileSize) / 1_000_000
        guard videoSizeMB <= Double(Constants.maxVideoSizeMB) else {
            throw StorageError.sizeTooLarge(size: Int(videoSizeMB))
        }
        
        // Create file input using URL instead of loading data into memory
        let file = InputFile.fromPath(videoURL.path)
        
        // Upload with retry
        return try await uploadWithRetry(file: file, progress: progress)
    }
    
    /// Internal method to handle upload retries
    private func uploadWithRetry(
        file: InputFile,
        progress: ((Double) -> Void)?,
        attempt: Int = 1
    ) async throws -> String {
        do {
            // Simulate progress updates (since Appwrite SDK doesn't provide native progress)
            if let progress = progress {
                let progressSteps = 10
                for step in 1...progressSteps {
                    await MainActor.run {
                        progress(Double(step) / Double(progressSteps))
                    }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            
            let result = try await storage.createFile(
                bucketId: Constants.postMediaBucketId,
                fileId: ID.unique(),
                file: file
            )
            
            if let progress = progress {
                await MainActor.run {
                    progress(1.0)
                }
            }
            return result.id
            
        } catch {
            if attempt < Constants.maxRetryAttempts {
                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)
                return try await uploadWithRetry(file: file, progress: progress, attempt: attempt + 1)
            } else {
                throw StorageError.uploadFailed(error.localizedDescription)
            }
        }
    }
    
    func getMediaUrl(mediaId: String, isVideo: Bool = false, forThumbnail: Bool = false) -> String {
        let baseUrl = "\(Constants.endpoint)/storage/buckets/\(Constants.postMediaBucketId)/files/\(mediaId)"
        var url = baseUrl
        
        if isVideo {
            if forThumbnail {
                // For video thumbnails, use preview endpoint
                url += "/preview?width=400&height=400&gravity=center&quality=100&output=jpeg"
                url += "&project=\(Constants.projectId)"
            } else {
                // For video playback, use view endpoint
                url += "/view?project=\(Constants.projectId)"
            }
        } else {
            // For images, use view endpoint
            url += "/view?project=\(Constants.projectId)"
        }
        
        // Add API key
        url += "&key=\(Constants.apiKey)"
        
        return url
    }
    
    // Keep the old method for backward compatibility but mark as deprecated
    @available(*, deprecated, message: "Use getMediaUrl instead")
    func getImageUrl(fileId: String) -> String {
        return getMediaUrl(mediaId: fileId)
    }
    
    // MARK: - Authentication Methods
    func register(
        _ email: String,
        _ password: String,
        name: String? = nil
    ) async throws -> User<[String: AnyCodable]> {
        do {
            let user = try await account.create(
                userId: ID.unique(),
                email: email,
                password: password,
                name: name ?? ""  // Set name during account creation
            )
            
            return user
        } catch let error as AppwriteError {
            switch error.type {
            case "user_unauthorized":
                throw NSError(domain: "AppwriteService",
                            code: 401,
                            userInfo: [NSLocalizedDescriptionKey: "Unable to create account. Please ensure user registration is enabled in Appwrite console."])
            case "user_already_exists":
                throw NSError(domain: "AppwriteService",
                            code: 409,
                            userInfo: [NSLocalizedDescriptionKey: "An account with this email already exists."])
            default:
                throw error
            }
        }
    }
    
    func login(
        _ email: String,
        _ password: String
    ) async throws -> Session {
        try await account.createEmailPasswordSession(
            email: email,
            password: password
        )
    }
    
    func logout() async throws {
        _ = try await account.deleteSession(sessionId: "current")
    }
    
    // Add method to fetch user info
    func getUserInfo(userId: String) async throws -> UserInfo {
        // Check cache first
        if let cachedUser = userCache[userId] {
            return cachedUser
        }
        
        do {
            let document = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: Constants.usersCollectionId,
                documentId: userId
            )
            
            let userInfo = UserInfo(
                id: userId,
                name: document.data["name"]?.value as? String ?? "Unknown User",
                email: document.data["email"]?.value as? String ?? ""
            )
            
            // Cache the result
            userCache[userId] = userInfo
            
            return userInfo
        } catch {
            debugPrint("📱 Error fetching user info: \(error)")
            // Return a default user info if fetch fails
            return UserInfo(id: userId, name: "User \(String(userId.prefix(4)))", email: "")
        }
    }
    
    // MARK: - Like Methods
    
    /// Likes a post or article
    func like(documentId: String, collectionId: String) async throws {
        debugPrint("📱 Like: Starting like operation for document \(documentId) in collection \(collectionId)")
        
        guard let user = try? await account.get() else {
            debugPrint("📱 Like: Failed - User not authenticated")
            throw DatabaseError.unauthorized
        }
        debugPrint("📱 Like: User authenticated with ID: \(user.id)")
        
        do {
            // First, get current likes count
            debugPrint("📱 Like: Fetching current document")
            let document = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId
            )
            
            let currentLikes = (document.data["likes"]?.value as? Int) ?? 0
            debugPrint("📱 Like: Current likes count: \(currentLikes)")
            
            // Then increment likes count
            debugPrint("📱 Like: Updating likes count to \(currentLikes + 1)")
            _ = try await databases.updateDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId,
                data: [
                    "likes": currentLikes + 1
                ]
            )
            debugPrint("📱 Like: Successfully updated likes count")
            
            // Check if a like record already exists
            debugPrint("📱 Like: Checking for existing like record")
            let likes = try await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.likesCollectionId,
                queries: [
                    Query.equal("userId", value: user.id),
                    Query.equal("documentId", value: documentId)
                ]
            )
            debugPrint("📱 Like: Found \(likes.documents.count) existing like records")
            
            if let existingLike = likes.documents.first {
                debugPrint("📱 Like: Found existing like record with ID: \(existingLike.id)")
                // Update existing like record with optional isLiked field
                var updateData: [String: Any] = [:]
                
                // Check if isLiked field exists
                if let isLikedValue = existingLike.data["isLiked"]?.value as? Bool {
                    debugPrint("📱 Like: Existing record has isLiked field with value: \(isLikedValue)")
                    updateData["isLiked"] = true
                } else {
                    debugPrint("📱 Like: Existing record does not have isLiked field")
                }
                
                if !updateData.isEmpty {
                    debugPrint("📱 Like: Updating existing record with data: \(updateData)")
                    _ = try await databases.updateDocument(
                        databaseId: AppwriteService.databaseId,
                        collectionId: Self.likesCollectionId,
                        documentId: existingLike.id,
                        data: updateData
                    )
                    debugPrint("📱 Like: Successfully updated existing like record")
                } else {
                    debugPrint("📱 Like: No update needed for existing record")
                }
            } else {
                // Create new like record with optional isLiked field
                let likeId = ID.unique()
                debugPrint("📱 Like: Creating new like record with ID: \(likeId)")
                var createData: [String: Any] = [
                    "userId": user.id,
                    "documentId": documentId,
                    "collectionId": collectionId,
                    "createdAt": Date().ISO8601Format()
                ]
                
                // Check if isLiked field exists in schema
                debugPrint("📱 Like: Checking if isLiked field exists in schema")
                if let existingDoc = try? await databases.listDocuments(
                    databaseId: AppwriteService.databaseId,
                    collectionId: Self.likesCollectionId,
                    queries: []
                ).documents.first {
                    if existingDoc.data["isLiked"] != nil {
                        debugPrint("📱 Like: isLiked field exists in schema, adding to create data")
                        createData["isLiked"] = true
                    } else {
                        debugPrint("📱 Like: isLiked field does not exist in schema")
                    }
                }
                
                debugPrint("📱 Like: Creating new record with data: \(createData)")
                _ = try await databases.createDocument(
                    databaseId: AppwriteService.databaseId,
                    collectionId: Self.likesCollectionId,
                    documentId: likeId,
                    data: createData
                )
                debugPrint("📱 Like: Successfully created new like record")
            }
        } catch {
            debugPrint("📱 Like: Error occurred: \(error.localizedDescription)")
            if let appwriteError = error as? AppwriteError {
                debugPrint("📱 Like: Appwrite error type: \(String(describing: appwriteError.type))")
                debugPrint("📱 Like: Appwrite error message: \(String(describing: appwriteError.message))")
            }
            throw DatabaseError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Unlikes a post or article
    func unlike(documentId: String, collectionId: String) async throws {
        debugPrint("📱 Unlike: Starting unlike operation for document \(documentId) in collection \(collectionId)")
        
        guard let user = try? await account.get() else {
            debugPrint("📱 Unlike: Failed - User not authenticated")
            throw DatabaseError.unauthorized
        }
        debugPrint("📱 Unlike: User authenticated with ID: \(user.id)")
        
        do {
            // First, get current likes count
            debugPrint("📱 Unlike: Fetching current document")
            let document = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId
            )
            
            let currentLikes = (document.data["likes"]?.value as? Int) ?? 0
            let newLikes = max(0, currentLikes - 1) // Prevent negative likes
            debugPrint("📱 Unlike: Current likes: \(currentLikes), New likes: \(newLikes)")
            
            // Then decrement likes count
            debugPrint("📱 Unlike: Updating likes count")
            _ = try await databases.updateDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId,
                data: [
                    "likes": newLikes
                ]
            )
            debugPrint("📱 Unlike: Successfully updated likes count")
            
            // Find and update the like record
            debugPrint("📱 Unlike: Finding like record")
            let likes = try await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.likesCollectionId,
                queries: [
                    Query.equal("userId", value: user.id),
                    Query.equal("documentId", value: documentId)
                ]
            )
            
            if let likeDoc = likes.documents.first {
                debugPrint("📱 Unlike: Found like record with ID: \(likeDoc.id)")
                var updateData: [String: Any] = [:]
                
                // Check if isLiked field exists
                if let isLikedValue = likeDoc.data["isLiked"]?.value as? Bool {
                    debugPrint("📱 Unlike: Existing record has isLiked field with value: \(isLikedValue)")
                    updateData["isLiked"] = false
                } else {
                    debugPrint("📱 Unlike: Existing record does not have isLiked field")
                }
                
                if !updateData.isEmpty {
                    debugPrint("📱 Unlike: Updating record with data: \(updateData)")
                    _ = try await databases.updateDocument(
                        databaseId: AppwriteService.databaseId,
                        collectionId: Self.likesCollectionId,
                        documentId: likeDoc.id,
                        data: updateData
                    )
                    debugPrint("📱 Unlike: Successfully updated like record")
                } else {
                    debugPrint("📱 Unlike: No update needed for record")
                }
            } else {
                debugPrint("📱 Unlike: No like record found to update")
            }
        } catch {
            debugPrint("📱 Unlike: Error occurred: \(error.localizedDescription)")
            if let appwriteError = error as? AppwriteError {
                debugPrint("📱 Unlike: Appwrite error type: \(String(describing: appwriteError.type))")
                debugPrint("📱 Unlike: Appwrite error message: \(String(describing: appwriteError.message))")
            }
            throw DatabaseError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Checks if a user has liked a document
    func hasLiked(documentId: String) async throws -> Bool {
        debugPrint("📱 HasLiked: Checking like status for document \(documentId)")
        
        guard let user = try? await account.get() else {
            debugPrint("📱 HasLiked: Failed - User not authenticated")
            throw DatabaseError.unauthorized
        }
        debugPrint("📱 HasLiked: User authenticated with ID: \(user.id)")
        
        do {
            debugPrint("📱 HasLiked: Building query conditions")
            var queries: [String] = [
                Query.equal("userId", value: user.id),
                Query.equal("documentId", value: documentId)
            ]
            
            // Check if isLiked field exists in schema
            debugPrint("📱 HasLiked: Checking if isLiked field exists in schema")
            if let existingDoc = try? await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.likesCollectionId,
                queries: []
            ).documents.first {
                if existingDoc.data["isLiked"] != nil {
                    debugPrint("📱 HasLiked: isLiked field exists in schema, adding to query")
                    queries.append(Query.equal("isLiked", value: true))
                } else {
                    debugPrint("📱 HasLiked: isLiked field does not exist in schema")
                }
            }
            
            debugPrint("📱 HasLiked: Executing query with conditions: \(queries)")
            let likes = try await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.likesCollectionId,
                queries: queries
            )
            
            let hasLiked = !likes.documents.isEmpty
            debugPrint("📱 HasLiked: Found \(likes.documents.count) matching records")
            debugPrint("📱 HasLiked: Result - \(hasLiked)")
            return hasLiked
        } catch {
            debugPrint("📱 HasLiked: Error occurred: \(error.localizedDescription)")
            if let appwriteError = error as? AppwriteError {
                debugPrint("📱 HasLiked: Appwrite error type: \(String(describing: appwriteError.type))")
                debugPrint("📱 HasLiked: Appwrite error message: \(String(describing: appwriteError.message))")
            }
            throw DatabaseError.fetchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Comment Methods
    
    /// Creates a new comment on a post or article
    func createComment(text: String, documentId: String, collectionId: String) async throws -> Comment {
        debugPrint("📱 CreateComment: Starting comment creation for document \(documentId)")
        
        guard let user = try? await account.get() else {
            debugPrint("📱 CreateComment: Failed - User not authenticated")
            throw DatabaseError.unauthorized
        }
        debugPrint("📱 CreateComment: User authenticated with ID: \(user.id)")
        
        do {
            // Validate text length
            guard Comment.validateText(text) else {
                throw DatabaseError.creationFailed("Comment text exceeds maximum length of \(Comment.maxTextLength) characters")
            }
            
            let commentId = ID.unique()
            let dateString = Date().ISO8601Format()
            
            debugPrint("📱 CreateComment: Creating comment document")
            let document = try await databases.createDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.commentsCollectionId,
                documentId: commentId,
                data: [
                    "userId": user.id,
                    "author": user.name,
                    "documentId": documentId,
                    "text": text,
                    "createdAt": dateString
                ]
            )
            debugPrint("📱 CreateComment: Comment created with ID: \(commentId)")
            
            // Increment comments count on the parent document
            debugPrint("📱 CreateComment: Updating comments count on parent document")
            let parentDoc = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId
            )
            
            let currentComments = (parentDoc.data["comments"]?.value as? Int) ?? 0
            debugPrint("📱 CreateComment: Current comments count: \(currentComments)")
            
            _ = try await databases.updateDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId,
                data: [
                    "comments": currentComments + 1
                ]
            )
            debugPrint("📱 CreateComment: Updated comments count to \(currentComments + 1)")
            
            // Create and return Comment object
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let comment = Comment(
                id: document.id,
                documentId: documentId,
                userId: user.id,
                author: user.name,
                text: text,
                createdAt: formatter.date(from: dateString) ?? Date()
            )
            return comment
            
        } catch {
            debugPrint("📱 CreateComment: Error occurred: \(error.localizedDescription)")
            if let appwriteError = error as? AppwriteError {
                debugPrint("📱 CreateComment: Appwrite error type: \(String(describing: appwriteError.type))")
                debugPrint("📱 CreateComment: Appwrite error message: \(String(describing: appwriteError.message))")
            }
            throw DatabaseError.creationFailed(error.localizedDescription)
        }
    }
    
    /// Fetches comments for a post or article
    func fetchComments(documentId: String, limit: Int = 10, offset: Int = 0) async throws -> [Comment] {
        debugPrint("📱 FetchComments: Starting fetch for document \(documentId)")
        
        do {
            let documents = try await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.commentsCollectionId,
                queries: [
                    Query.equal("documentId", value: documentId),
                    Query.orderDesc("createdAt"),
                    Query.limit(limit),
                    Query.offset(offset)
                ]
            )
            
            debugPrint("📱 FetchComments: Found \(documents.documents.count) comments")
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            return documents.documents.compactMap { document in
                debugPrint("📱 FetchComments: Processing document ID: \(document.id)")
                debugPrint("📱 FetchComments: Raw document data: \(document.data)")
                
                let userId = document.data["userId"]?.value as? String ?? ""
                let author = document.data["author"]?.value as? String ?? ""
                let text = document.data["text"]?.value as? String ?? ""
                let dateString = document.data["createdAt"]?.value as? String ?? ""
                
                debugPrint("📱 FetchComments: Extracted values - userId: \(userId), author: \(author), text: \(text), dateString: \(dateString)")
                
                guard let date = formatter.date(from: dateString) else {
                    debugPrint("📱 FetchComments: Failed to parse date string: \(dateString)")
                    return nil as Comment?
                }
                
                debugPrint("📱 FetchComments: Successfully parsed date: \(date)")
                
                let comment = Comment(
                    id: document.id,
                    documentId: documentId,
                    userId: userId,
                    author: author,
                    text: text,
                    createdAt: date
                )
                debugPrint("📱 FetchComments: Successfully created Comment object: \(comment)")
                return comment
            }
            
        } catch {
            debugPrint("📱 FetchComments: Error occurred: \(error.localizedDescription)")
            if let appwriteError = error as? AppwriteError {
                debugPrint("📱 FetchComments: Appwrite error type: \(String(describing: appwriteError.type))")
                debugPrint("📱 FetchComments: Appwrite error message: \(String(describing: appwriteError.message))")
            }
            throw DatabaseError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Deletes a comment
    func deleteComment(commentId: String, documentId: String, collectionId: String) async throws {
        debugPrint("📱 DeleteComment: Starting deletion of comment \(commentId)")
        
        guard let user = try? await account.get() else {
            debugPrint("📱 DeleteComment: Failed - User not authenticated")
            throw DatabaseError.unauthorized
        }
        debugPrint("📱 DeleteComment: User authenticated with ID: \(user.id)")
        
        do {
            // First verify the comment belongs to the user
            let comment = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.commentsCollectionId,
                documentId: commentId
            )
            
            guard let commentUserId = comment.data["userId"]?.value as? String,
                  commentUserId == user.id else {
                debugPrint("📱 DeleteComment: Failed - User not authorized to delete this comment")
                throw DatabaseError.unauthorized
            }
            
            // Delete the comment
            debugPrint("📱 DeleteComment: Deleting comment document")
            _ = try await databases.deleteDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.commentsCollectionId,
                documentId: commentId
            )
            
            // Decrement comments count on the parent document
            debugPrint("📱 DeleteComment: Updating comments count on parent document")
            let parentDoc = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId
            )
            
            let currentComments = (parentDoc.data["comments"]?.value as? Int) ?? 0
            debugPrint("📱 DeleteComment: Current comments count: \(currentComments)")
            
            _ = try await databases.updateDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId,
                data: [
                    "comments": max(0, currentComments - 1)
                ]
            )
            debugPrint("📱 DeleteComment: Updated comments count to \(max(0, currentComments - 1))")
            
        } catch {
            debugPrint("📱 DeleteComment: Error occurred: \(error.localizedDescription)")
            if let appwriteError = error as? AppwriteError {
                debugPrint("📱 DeleteComment: Appwrite error type: \(String(describing: appwriteError.type))")
                debugPrint("📱 DeleteComment: Appwrite error message: \(String(describing: appwriteError.message))")
            }
            throw DatabaseError.updateFailed(error.localizedDescription)
        }
    }
} 