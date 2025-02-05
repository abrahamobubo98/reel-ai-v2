import Foundation
import Appwrite
import JSONCodable

/// Service class to handle all Appwrite related operations
class AppwriteService {
    // MARK: - Properties
    static let shared = AppwriteService()
    
    var client: Client
    var account: Account
    
    // MARK: - Constants
    private enum Constants {
        static let endpoint = "https://cloud.appwrite.io/v1"
        static let projectId = "67a286370021b45dba67"  // Your project ID
        static let apiKey = "standard_32a04112d6a86d68f3be5ad6d9da16ea60733860de5ee91d8f7a71ce08edae860c0c9d275d4d11f098d00b9e30b43accb846cdcac966a7b3325785b5c60932206ca460c7b8014430c9a010b4655fc2d245910267314a9a8a72fcfd7e2c9f1fa3e209995250ac0e4e1fa59f848c647cb2aeefa3907297f517eabfbdac67f9dc85" // Add your API key here
    }
    
    private init() {
        self.client = Client()
            .setEndpoint(Constants.endpoint)
            .setProject(Constants.projectId)
            .setSelfSigned() // Remove in production
        
        self.account = Account(client)
        debugPrint("📱 AppwriteService initialized")
    }
    
    // MARK: - Authentication Methods
    func register(
        _ email: String,
        _ password: String,
        username: String? = nil
    ) async throws -> User<[String: AnyCodable]> {
        debugPrint("📱 Attempting to register user: \(email)")
        do {
            var user = try await account.create(
                userId: ID.unique(),
                email: email,
                password: password
            )
            
            if let username = username {
                // Update the user's name after creation
                user = try await account.updateName(name: username)
            }
            
            debugPrint("📱 Successfully registered user: \(user.id)")
            return user
        } catch let error as AppwriteError {
            debugPrint("📱 Appwrite registration error: \(error.message)")
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
        debugPrint("📱 Attempting to login user: \(email)")
        return try await account.createEmailPasswordSession(
            email: email,
            password: password
        )
    }
    
    func logout() async throws {
        debugPrint("📱 Attempting to logout user")
        _ = try await account.deleteSession(sessionId: "current")
        debugPrint("📱 Successfully logged out user")
    }
} 