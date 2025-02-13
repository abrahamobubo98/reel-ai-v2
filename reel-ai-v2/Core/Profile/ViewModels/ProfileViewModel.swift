import Foundation
import SwiftUI
import Appwrite

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var bio = ""
    @Published var selectedTab = 0
    @Published var isLoading = false
    @Published var error: String?
    
    @Published var posts: [Post] = []
    @Published var articles: [Article] = []
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
    private let appwrite = AppwriteService.shared
    
    func loadProfile(userId: String) async {
        isLoading = true
        error = nil
        
        do {
            // Load user info
            print("📱 Loading profile for user: \(userId)")
            let userDoc = try await appwrite.databases.getDocument(
                databaseId: AppwriteService.databaseId,
                collectionId: AppwriteService.Constants.usersCollectionId,
                documentId: userId
            )
            
            name = userDoc.data["name"]?.value as? String ?? "Unknown User"
            bio = userDoc.data["bio"]?.value as? String ?? ""
            print("📱 Loaded user info - Name: \(name), Bio: \(bio)")
            
            // Load user's posts
            print("📱 Loading user's posts...")
            posts = try await appwrite.databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: AppwriteService.postsCollectionId,
                queries: [
                    Query.equal("userId", value: userId),
                    Query.orderDesc("createdAt"),
                    Query.limit(50)
                ]
            ).documents.compactMap { document in
                guard let userId = document.data["userId"]?.value as? String,
                      let author = document.data["author"]?.value as? String,
                      let mediaId = document.data["mediaId"]?.value as? String,
                      let caption = document.data["caption"]?.value as? String,
                      let dateString = document.data["createdAt"]?.value as? String,
                      let mediaTypeString = document.data["mediaType"]?.value as? String else {
                    return nil
                }
                
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = formatter.date(from: dateString) ?? Date()
                
                return Post(
                    id: document.id,
                    userId: userId,
                    author: author,
                    caption: caption,
                    mediaId: mediaId,
                    mediaType: MediaType(rawValue: mediaTypeString) ?? .image,
                    likes: document.data["likes"]?.value as? Int ?? 0,
                    comments: document.data["comments"]?.value as? Int ?? 0,
                    createdAt: date
                )
            }
            print("📱 Loaded \(posts.count) posts")
            
            // Load user's articles
            print("📱 Loading user's articles...")
            articles = try await appwrite.databases.listDocuments(
                databaseId: AppwriteService.databaseId,
                collectionId: AppwriteService.articlesCollectionId,
                queries: [
                    Query.equal("userId", value: userId),
                    Query.orderDesc("createdAt"),
                    Query.limit(50)
                ]
            ).documents.compactMap { document in
                guard let title = document.data["title"]?.value as? String,
                      let content = document.data["content"]?.value as? String,
                      let author = document.data["author"]?.value as? String,
                      let userId = document.data["userId"]?.value as? String,
                      let dateString = document.data["createdAt"]?.value as? String else {
                    return nil
                }
                
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = formatter.date(from: dateString) ?? Date()
                
                return Article(
                    id: document.id,
                    userId: userId,
                    author: author,
                    title: title,
                    content: content,
                    summary: document.data["summary"]?.value as? String,
                    thumbnailUrl: URL(string: document.data["thumbnailUrl"]?.value as? String ?? ""),
                    createdAt: date,
                    updatedAt: date,
                    status: .published,
                    tags: document.data["tags"]?.value as? [String] ?? [],
                    views: document.data["views"]?.value as? Int ?? 0,
                    readingTime: document.data["readingTime"]?.value as? Int ?? 0,
                    commentCount: document.data["comments"]?.value as? Int ?? 0,
                    likes: document.data["likes"]?.value as? Int ?? 0
                )
            }
            print("📱 Loaded \(articles.count) articles")
            
        } catch {
            print("❌ Failed to load profile: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
} 