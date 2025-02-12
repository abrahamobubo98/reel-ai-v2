import Foundation

enum ConfigError: Error {
    case configFileNotFound
    case invalidValue(key: String)
}

final class Config {
    static let shared = Config()
    
    // MARK: - Appwrite Configuration
    let appwriteEndpoint: String
    let appwriteProjectId: String
    let appwriteApiKey: String
    let appwriteDatabaseId: String
    let appwritePostsCollectionId: String
    let appwriteArticlesCollectionId: String
    let appwriteLikesCollectionId: String
    let appwriteCommentsCollectionId: String
    let appwriteUsersCollectionId: String
    let appwriteStorageId: String
    let appwriteBucketId: String
    let appwritePostMediaBucketId: String
    let appwriteQuizzesCollectionId: String
    let appwriteQuizAttemptsCollectionId: String
    let appwriteQuizStatisticsCollectionId: String
    
    // MARK: - OpenAI Configuration
    let openAIApiKey: String
    
    private init() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("Config.plist not found")
        }
        
        // Initialize Appwrite configuration
        guard let appwriteEndpoint = config["APPWRITE_ENDPOINT"] as? String,
              let appwriteProjectId = config["APPWRITE_PROJECT_ID"] as? String,
              let appwriteApiKey = config["APPWRITE_API_KEY"] as? String,
              let appwriteDatabaseId = config["APPWRITE_DATABASE_ID"] as? String,
              let appwritePostsCollectionId = config["APPWRITE_POSTS_COLLECTION_ID"] as? String,
              let appwriteArticlesCollectionId = config["APPWRITE_ARTICLES_COLLECTION_ID"] as? String,
              let appwriteLikesCollectionId = config["APPWRITE_LIKES_COLLECTION_ID"] as? String,
              let appwriteCommentsCollectionId = config["APPWRITE_COMMENTS_COLLECTION_ID"] as? String,
              let appwriteUsersCollectionId = config["APPWRITE_USERS_COLLECTION_ID"] as? String,
              let appwriteStorageId = config["APPWRITE_STORAGE_ID"] as? String,
              let appwriteBucketId = config["APPWRITE_BUCKET_ID"] as? String,
              let appwritePostMediaBucketId = config["APPWRITE_POST_MEDIA_BUCKET_ID"] as? String,
              let appwriteQuizzesCollectionId = config["APPWRITE_QUIZZES_COLLECTION_ID"] as? String,
              let appwriteQuizAttemptsCollectionId = config["APPWRITE_QUIZ_ATTEMPTS_COLLECTION_ID"] as? String,
              let appwriteQuizStatisticsCollectionId = config["APPWRITE_QUIZ_STATISTICS_COLLECTION_ID"] as? String,
              let openAIApiKey = config["OPENAI_API_KEY"] as? String else {
            fatalError("Missing required configuration values in Config.plist")
        }
        
        self.appwriteEndpoint = appwriteEndpoint
        self.appwriteProjectId = appwriteProjectId
        self.appwriteApiKey = appwriteApiKey
        self.appwriteDatabaseId = appwriteDatabaseId
        self.appwritePostsCollectionId = appwritePostsCollectionId
        self.appwriteArticlesCollectionId = appwriteArticlesCollectionId
        self.appwriteLikesCollectionId = appwriteLikesCollectionId
        self.appwriteCommentsCollectionId = appwriteCommentsCollectionId
        self.appwriteUsersCollectionId = appwriteUsersCollectionId
        self.appwriteStorageId = appwriteStorageId
        self.appwriteBucketId = appwriteBucketId
        self.appwritePostMediaBucketId = appwritePostMediaBucketId
        self.appwriteQuizzesCollectionId = appwriteQuizzesCollectionId
        self.appwriteQuizAttemptsCollectionId = appwriteQuizAttemptsCollectionId
        self.appwriteQuizStatisticsCollectionId = appwriteQuizStatisticsCollectionId
        self.openAIApiKey = openAIApiKey
    }
} 