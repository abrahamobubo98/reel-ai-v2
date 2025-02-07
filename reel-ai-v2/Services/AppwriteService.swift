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
    
    var errorDescription: String? {
        switch self {
        case .invalidPost:
            return "Invalid post data"
        case .creationFailed(let reason):
            return "Failed to create post: \(reason)"
        case .unauthorized:
            return "You must be logged in to create a post"
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
    let likes: Int
    let comments: Int
    
    enum MediaType: String, Codable {
        case photo
        case video
    }
    
    init(id: String, userId: String, author: String, mediaId: String, mediaType: MediaType = .photo, caption: String, externalLink: String = "", createdAt: Date, likes: Int, comments: Int) {
        self.id = id
        self.userId = userId
        self.author = author
        self.mediaId = mediaId
        self.mediaType = mediaType
        self.caption = caption
        self.externalLink = externalLink
        self.createdAt = createdAt
        self.likes = likes
        self.comments = comments
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
        case likes
        case comments
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
        likes = try container.decode(Int.self, forKey: .likes)
        comments = try container.decode(Int.self, forKey: .comments)
        
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
    
    var client: Client
    var account: Account
    var storage: Storage
    var databases: Databases
    
    // MARK: - Constants
    private enum Constants {
        static let endpoint = "https://cloud.appwrite.io/v1"
        static let projectId = "67a286370021b45dba67"
        static let postMediaBucketId = "67a3d0f2002c24b13472"
        static let apiKey = "standard_32a04112d6a86d68f3be5ad6d9da16ea60733860de5ee91d8f7a71ce08edae860c0c9d275d4d11f098d00b9e30b43accb846cdcac966a7b3325785b5c60932206ca460c7b8014430c9a010b4655fc2d245910267314a9a8a72fcfd7e2c9f1fa3e209995250ac0e4e1fa59f848c647cb2aeefa3907297f517eabfbdac67f9dc85"
        static let maxImageSizeMB = 10
        static let maxVideoSizeMB = 100
        static let compressionQuality: CGFloat = 0.8
        static let maxRetryAttempts = 3
        static let databaseId = "67a3d388001df90d84c0"
        static let postsCollectionId = "67a3d4320034a6727a55"
        static let articlesCollectionId = "67a58f8d001dcc4329a6"
        static let usersCollectionId = "67a64c36002fc4f4d747" // Replace with your actual collection ID
    }
    
    // Add user cache to avoid repeated fetches
    private var userCache: [String: UserInfo] = [:]
    
    private init() {
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
            debugPrint("📱 Using database ID: \(Constants.databaseId)")
            debugPrint("📱 Using collection ID: \(Constants.postsCollectionId)")
            
            let documents = try await databases.listDocuments(
                databaseId: Constants.databaseId,
                collectionId: Constants.postsCollectionId,
                queries: [
                    Query.orderDesc("createdAt"),
                    Query.limit(limit),
                    Query.offset(offset)
                ]
            )
            
            debugPrint("📱 Raw response - total documents: \(documents.total)")
            debugPrint("📱 Raw documents data: \(documents.documents)")
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            var posts: [Post] = []
            for document in documents.documents {
                let data = document.data
                debugPrint("📱 Parsing document: \(document.id)")
                
                // Extract values from AnyCodable
                let userId = (data["userId"]?.value as? String) ?? ""
                let author = (data["author"]?.value as? String) ?? "Unknown User"
                let mediaId = (data["mediaId"]?.value as? String) ?? ""
                let caption = (data["caption"]?.value as? String) ?? ""
                let dateString = (data["createdAt"]?.value as? String) ?? ""
                let likes = (data["likes"]?.value as? Int) ?? 0
                let comments = (data["comments"]?.value as? Int) ?? 0
                let mediaTypeString = (data["mediaType"]?.value as? String) ?? "photo"
                
                guard !userId.isEmpty, !mediaId.isEmpty, !dateString.isEmpty else {
                    debugPrint("📱 Missing required fields in document: \(document.id)")
                    continue
                }
                
                guard let date = formatter.date(from: dateString) else {
                    debugPrint("📱 Failed to parse date: \(dateString)")
                    continue
                }
                
                let post = Post(
                    id: document.id,
                    userId: userId,
                    author: author,
                    mediaId: mediaId,
                    mediaType: Post.MediaType(rawValue: mediaTypeString) ?? .photo,
                    caption: caption,
                    externalLink: "",
                    createdAt: date,
                    likes: likes,
                    comments: comments
                )
                
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
            
            // Create post document
            debugPrint("📱 Attempting to create document with mediaId: \(mediaId)")
            let document = try await databases.createDocument(
                databaseId: Constants.databaseId,
                collectionId: Constants.postsCollectionId,
                documentId: ID.unique(),
                data: [
                    "userId": user.id,
                    "author": user.name,
                    "mediaId": mediaId,
                    "mediaType": mediaType.rawValue,
                    "caption": caption,
                    "externalLink": externalLink,
                    "createdAt": dateString,
                    "likes": 0,
                    "comments": 0
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
                likes: document.data["likes"]?.value as? Int ?? 0,
                comments: document.data["comments"]?.value as? Int ?? 0
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
            print("📱 AppwriteService: Using database ID: \(Constants.databaseId)")
            print("📱 AppwriteService: Using collection ID: \(Constants.articlesCollectionId)")
            
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
                databaseId: Constants.databaseId,
                collectionId: Constants.articlesCollectionId,
                documentId: ID.unique(),
                data: [
                    "userId": user.id,
                    "author": user.name,  // Add author name
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
                author: document.data["author"]?.value as? String ?? user.name,  // Add author name
                title: document.data["title"]?.value as? String ?? title,
                content: document.data["content"]?.value as? String ?? content,
                coverImageId: document.data["coverImageId"]?.value as? String,
                tags: document.data["tags"]?.value as? [String] ?? [],
                createdAt: formatter.date(from: document.data["createdAt"]?.value as? String ?? dateString) ?? Date(),
                updatedAt: formatter.date(from: document.data["updatedAt"]?.value as? String ?? dateString) ?? Date(),
                likes: document.data["likes"]?.value as? Int ?? 0,
                views: document.data["views"]?.value as? Int ?? 0
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
                databaseId: Constants.databaseId,
                collectionId: Constants.articlesCollectionId,
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
                    coverImageId: data["coverImageId"]?.value as? String,
                    tags: data["tags"]?.value as? [String] ?? [],
                    createdAt: formatter.date(from: data["createdAt"]?.value as? String ?? "") ?? Date(),
                    updatedAt: formatter.date(from: data["updatedAt"]?.value as? String ?? "") ?? Date(),
                    likes: data["likes"]?.value as? Int ?? 0,
                    views: data["views"]?.value as? Int ?? 0
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
                databaseId: Constants.databaseId,
                collectionId: Constants.articlesCollectionId,
                documentId: article.id,
                data: [
                    "title": article.title,
                    "content": article.content,
                    "coverImageId": article.coverImageId ?? "",
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
                coverImageId: document.data["coverImageId"]?.value as? String,
                tags: document.data["tags"]?.value as? [String] ?? article.tags,
                createdAt: article.createdAt,
                updatedAt: formatter.date(from: updateDateString) ?? Date(),
                likes: article.likes,
                views: article.views
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
                databaseId: Constants.databaseId,
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
} 