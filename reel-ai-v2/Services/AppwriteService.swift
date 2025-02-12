import Foundation
import Appwrite
import JSONCodable
import UIKit

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
            let documents = try await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.postsCollectionId,
                queries: [
                    Query.orderDesc("createdAt"),
                    Query.limit(limit),
                    Query.offset(offset)
                ]
            )
            
            var posts: [Post] = []
            for document in documents.documents {
                let userId = (document.data["userId"]?.value as? String) ?? ""
                let author = (document.data["author"]?.value as? String) ?? "Unknown User"
                let mediaId = (document.data["mediaId"]?.value as? String) ?? ""
                let caption = (document.data["caption"]?.value as? String) ?? ""
                let dateString = (document.data["createdAt"]?.value as? String) ?? ""
                let likes = (document.data["likes"]?.value as? Int) ?? 0
                let comments = (document.data["comments"]?.value as? Int) ?? 0
                let mediaTypeString = (document.data["mediaType"]?.value as? String) ?? "photo"
                
                guard !mediaId.isEmpty else { continue }
                
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = formatter.date(from: dateString) ?? Date()
                
                let post = Post(
                    id: document.id,
                    userId: userId,
                    author: author,
                    caption: caption,
                    mediaId: mediaId,
                    mediaType: MediaType(rawValue: mediaTypeString) ?? .image,
                    likes: likes,
                    comments: comments,
                    createdAt: date
                )
                
                posts.append(post)
            }
            
            return posts
            
        } catch let error as AppwriteError {
            throw DatabaseError.creationFailed("Appwrite error: \(String(describing: error.message))")
        } catch {
            throw DatabaseError.creationFailed(error.localizedDescription)
        }
    }
    
    /// Creates a new post in the database
    func createPost(mediaId: String, caption: String, mediaType: MediaType = .image, externalLink: String = "") async throws -> Post {
        do {
            // Get current user
            let user = try await account.get()
            
            // Create ISO 8601 date string
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = formatter.string(from: Date())
            
            // Create post document with all required fields
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
                    "comments": 0
                ]
            )
            
            // Create Post object from document data
            let post = Post(
                id: document.id,
                userId: document.data["userId"]?.value as? String ?? user.id,
                author: document.data["author"]?.value as? String ?? user.name,
                caption: document.data["caption"]?.value as? String ?? caption,
                mediaId: document.data["mediaId"]?.value as? String ?? mediaId,
                mediaType: MediaType(rawValue: document.data["mediaType"]?.value as? String ?? mediaType.rawValue) ?? .image,
                likes: document.data["likes"]?.value as? Int ?? 0,
                comments: document.data["comments"]?.value as? Int ?? 0,
                createdAt: formatter.date(from: document.data["createdAt"]?.value as? String ?? dateString) ?? Date()
            )
            
            return post
            
        } catch let error as AppwriteError {
            switch error.type {
            case "user_unauthorized":
                throw DatabaseError.unauthorized
            default:
                throw DatabaseError.creationFailed("Appwrite error: \(String(describing: error.message))")
            }
        } catch {
            throw DatabaseError.creationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Article Methods
    
    /// Creates a new article in the database
    func createArticle(title: String, content: String, coverImageId: String? = nil, tags: [String] = []) async throws -> Article {
        do {
            // Get current user
            let user = try await account.get()
            
            // Create ISO 8601 date string
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = formatter.string(from: Date())
            
            // Create article document
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
            
            return article
            
        } catch let error as AppwriteError {
            switch error.type {
            case "user_unauthorized":
                throw DatabaseError.unauthorized
            default:
                throw DatabaseError.creationFailed("Appwrite error: \(String(describing: error.message))")
            }
        } catch {
            throw DatabaseError.creationFailed(error.localizedDescription)
        }
    }
    
    /// Fetches articles with pagination, sorted by creation date
    func fetchArticles(limit: Int = 10, offset: Int = 0) async throws -> [Article] {
        do {
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
            
            return articles
            
        } catch {
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
        // Try to logout first to clear any stale sessions
        do {
            try await logout()
        } catch {
            // Ignore logout errors as we just want to ensure no active session
            debugPrint("📱 Logout before login attempt failed (this is usually ok): \(error)")
        }
        
        // Now attempt login
        return try await account.createEmailPasswordSession(
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
            // Return a default user info if fetch fails
            return UserInfo(id: userId, name: "User \(String(userId.prefix(4)))", email: "")
        }
    }
    
    // MARK: - Like Methods
    
    /// Likes a post or article
    func like(documentId: String, collectionId: String) async throws {
        guard let user = try? await account.get() else {
            throw DatabaseError.unauthorized
        }
        
        do {
            // First, get current likes count
            let document = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId
            )
            
            let currentLikes = (document.data["likes"]?.value as? Int) ?? 0
            
            // Then increment likes count
            _ = try await databases.updateDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId,
                data: [
                    "likes": currentLikes + 1
                ]
            )
            
            // Check if a like record already exists
            let likes = try await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.likesCollectionId,
                queries: [
                    Query.equal("userId", value: user.id),
                    Query.equal("documentId", value: documentId)
                ]
            )
            
            if let existingLike = likes.documents.first {
                var updateData: [String: Any] = [:]
                
                // Check if isLiked field exists
                if existingLike.data["isLiked"]?.value is Bool {
                    updateData["isLiked"] = true
                }
                
                if !updateData.isEmpty {
                    _ = try await databases.updateDocument(
                        databaseId: AppwriteService.databaseId,
                        collectionId: Self.likesCollectionId,
                        documentId: existingLike.id,
                        data: updateData
                    )
                }
            } else {
                // Create new like record with optional isLiked field
                let likeId = ID.unique()
                var createData: [String: Any] = [
                    "userId": user.id,
                    "documentId": documentId,
                    "collectionId": collectionId,
                    "createdAt": Date().ISO8601Format()
                ]
                
                // Check if isLiked field exists in schema
                if let existingDoc = try? await databases.listDocuments(
                    databaseId: AppwriteService.databaseId,
                    collectionId: Self.likesCollectionId,
                    queries: []
                ).documents.first {
                    if existingDoc.data["isLiked"] != nil {
                        createData["isLiked"] = true
                    }
                }
                
                _ = try await databases.createDocument(
                    databaseId: AppwriteService.databaseId,
                    collectionId: Self.likesCollectionId,
                    documentId: likeId,
                    data: createData
                )
            }
        } catch {
            throw DatabaseError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Unlikes a post or article
    func unlike(documentId: String, collectionId: String) async throws {
        guard let user = try? await account.get() else {
            throw DatabaseError.unauthorized
        }
        
        do {
            // First, get current likes count
            let document = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId
            )
            
            let currentLikes = (document.data["likes"]?.value as? Int) ?? 0
            let newLikes = max(0, currentLikes - 1) // Prevent negative likes
            
            // Then decrement likes count
            _ = try await databases.updateDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId,
                data: [
                    "likes": newLikes
                ]
            )
            
            // Find and update the like record
            let likes = try await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.likesCollectionId,
                queries: [
                    Query.equal("userId", value: user.id),
                    Query.equal("documentId", value: documentId)
                ]
            )
            
            if let likeDoc = likes.documents.first {
                var updateData: [String: Any] = [:]
                
                // Check if isLiked field exists
                if likeDoc.data["isLiked"]?.value is Bool {
                    updateData["isLiked"] = false
                }
                
                if !updateData.isEmpty {
                    _ = try await databases.updateDocument(
                        databaseId: AppwriteService.databaseId,
                        collectionId: Self.likesCollectionId,
                        documentId: likeDoc.id,
                        data: updateData
                    )
                }
            }
        } catch {
            throw DatabaseError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Checks if a user has liked a document
    func hasLiked(documentId: String) async throws -> Bool {
        guard let user = try? await account.get() else {
            throw DatabaseError.unauthorized
        }
        
        do {
            let likes = try await databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.likesCollectionId,
                queries: [
                    Query.equal("userId", value: user.id),
                    Query.equal("documentId", value: documentId)
                ]
            )
            
            let hasLiked = !likes.documents.isEmpty
            return hasLiked
        } catch {
            throw DatabaseError.fetchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Comment Methods
    
    /// Creates a new comment on a post or article
    func createComment(text: String, documentId: String, collectionId: String) async throws -> Comment {
        guard let user = try? await account.get() else {
            throw DatabaseError.unauthorized
        }
        
        do {
            // Validate text length
            guard Comment.validateText(text) else {
                throw DatabaseError.creationFailed("Comment text exceeds maximum length of \(Comment.maxTextLength) characters")
            }
            
            let commentId = ID.unique()
            let dateString = Date().ISO8601Format()
            
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
            
            // Increment comments count on the parent document
            let parentDoc = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId
            )
            
            let currentComments = (parentDoc.data["comments"]?.value as? Int) ?? 0
            
            _ = try await databases.updateDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId,
                data: [
                    "comments": currentComments + 1
                ]
            )
            
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
            throw DatabaseError.creationFailed(error.localizedDescription)
        }
    }
    
    /// Fetches comments for a post or article
    func fetchComments(documentId: String, limit: Int = 10, offset: Int = 0) async throws -> [Comment] {
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
            
            return documents.documents.compactMap { document in
                let userId = document.data["userId"]?.value as? String ?? ""
                let author = document.data["author"]?.value as? String ?? ""
                let text = document.data["text"]?.value as? String ?? ""
                let dateString = document.data["createdAt"]?.value as? String ?? ""
                
                guard let date = ISO8601DateFormatter().date(from: dateString) else {
                    return nil as Comment?
                }
                
                let comment = Comment(
                    id: document.id,
                    documentId: documentId,
                    userId: userId,
                    author: author,
                    text: text,
                    createdAt: date
                )
                return comment
            }
            
        } catch {
            throw DatabaseError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Deletes a comment
    func deleteComment(commentId: String, documentId: String, collectionId: String) async throws {
        guard let user = try? await account.get() else {
            throw DatabaseError.unauthorized
        }
        
        do {
            // First verify the comment belongs to the user
            let comment = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.commentsCollectionId,
                documentId: commentId
            )
            
            guard let commentUserId = comment.data["userId"]?.value as? String,
                  commentUserId == user.id else {
                throw DatabaseError.unauthorized
            }
            
            // Delete the comment
            _ = try await databases.deleteDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: Self.commentsCollectionId,
                documentId: commentId
            )
            
            // Decrement comments count on the parent document
            let parentDoc = try await databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId
            )
            
            let currentComments = (parentDoc.data["comments"]?.value as? Int) ?? 0
            
            _ = try await databases.updateDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: collectionId,
                documentId: documentId,
                data: [
                    "comments": max(0, currentComments - 1)
                ]
            )
            
        } catch {
            throw DatabaseError.updateFailed(error.localizedDescription)
        }
    }
} 