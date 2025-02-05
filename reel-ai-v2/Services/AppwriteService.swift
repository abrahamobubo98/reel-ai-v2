import Foundation
import Appwrite
import JSONCodable
import UIKit

/// Custom errors for storage operations
enum StorageError: LocalizedError {
    case invalidImage
    case compressionFailed
    case sizeTooLarge(size: Int)
    case uploadFailed(String)
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image is invalid"
        case .compressionFailed:
            return "Failed to compress the image"
        case .sizeTooLarge(let size):
            return "Image size (\(size)MB) exceeds maximum allowed size (10MB)"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .invalidFormat:
            return "Invalid image format. Only JPEG and PNG are supported"
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
struct Post: Codable {
    let id: String
    let userId: String
    let imageId: String
    let caption: String
    let createdAt: Date
    let likes: Int
    let comments: Int
    
    init(id: String, userId: String, imageId: String, caption: String, createdAt: Date, likes: Int, comments: Int) {
        self.id = id
        self.userId = userId
        self.imageId = imageId
        self.caption = caption
        self.createdAt = createdAt
        self.likes = likes
        self.comments = comments
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case userId
        case imageId
        case caption
        case createdAt
        case likes
        case comments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        imageId = try container.decode(String.self, forKey: .imageId)
        caption = try container.decode(String.self, forKey: .caption)
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
        static let projectId = "67a286370021b45dba67"  // Your project ID
        static let postMediaBucketId = "67a3d0f2002c24b13472"    // Bucket ID for post media
        static let apiKey = "standard_32a04112d6a86d68f3be5ad6d9da16ea60733860de5ee91d8f7a71ce08edae860c0c9d275d4d11f098d00b9e30b43accb846cdcac966a7b3325785b5c60932206ca460c7b8014430c9a010b4655fc2d245910267314a9a8a72fcfd7e2c9f1fa3e209995250ac0e4e1fa59f848c647cb2aeefa3907297f517eabfbdac67f9dc85"
        static let maxImageSizeMB = 10
        static let compressionQuality: CGFloat = 0.8
        static let maxRetryAttempts = 3
        static let databaseId = "67a3d388001df90d84c0"    // Database ID from Appwrite Console
        static let postsCollectionId = "67a3d4320034a6727a55"    // Replace with your actual collection ID from Appwrite Console URL
    }
    
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
    
    /// Creates a new post in the database
    func createPost(imageId: String, caption: String) async throws -> Post {
        do {
            // Get current user
            let user = try await account.get()
            
            // Create ISO 8601 date string
            let formatter = ISO8601DateFormatter()
            let dateString = formatter.string(from: Date())
            
            // Create post document
            let document = try await databases.createDocument(
                databaseId: Constants.databaseId,
                collectionId: Constants.postsCollectionId,
                documentId: ID.unique(),
                data: [
                    "userId": user.id,
                    "imageId": imageId,
                    "caption": caption,
                    "createdAt": dateString,
                    "likes": 0,
                    "comments": 0
                ]
            )
            
            // Create Post object directly from document data
            let post = Post(
                id: document.id,
                userId: document.data["userId"]?.value as? String ?? user.id,
                imageId: document.data["imageId"]?.value as? String ?? imageId,
                caption: document.data["caption"]?.value as? String ?? caption,
                createdAt: formatter.date(from: document.data["createdAt"]?.value as? String ?? dateString) ?? Date(),
                likes: document.data["likes"]?.value as? Int ?? 0,
                comments: document.data["comments"]?.value as? Int ?? 0
            )
            
            return post
            
        } catch let error as AppwriteError {
            switch error.type {
            case "user_unauthorized":
                throw DatabaseError.unauthorized
            default:
                throw DatabaseError.creationFailed(error.message)
            }
        } catch {
            throw DatabaseError.creationFailed(error.localizedDescription)
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
    
    func getImageUrl(fileId: String) -> String {
        return "\(Constants.endpoint)/storage/buckets/\(Constants.postMediaBucketId)/files/\(fileId)/view"
    }
    
    // MARK: - Authentication Methods
    func register(
        _ email: String,
        _ password: String,
        username: String? = nil
    ) async throws -> User<[String: AnyCodable]> {
        do {
            var user = try await account.create(
                userId: ID.unique(),
                email: email,
                password: password
            )
            
            if let username = username {
                user = try await account.updateName(name: username)
            }
            
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
} 