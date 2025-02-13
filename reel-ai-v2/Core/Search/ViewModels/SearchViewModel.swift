import Foundation
import SwiftUI
import Appwrite

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCategory: SearchCategory = .all
    @Published var isLoading = false
    @Published var error: String?
    
    @Published var users: [UserInfo] = []
    @Published var articles: [Article] = []
    @Published var posts: [Post] = []
    
    private let appwrite = AppwriteService.shared
    
    func search() async {
        guard !searchText.isEmpty else {
            clearResults()
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            switch selectedCategory {
            case .users:
                users = try await searchUsers()
                articles = []
                posts = []
            case .articles:
                articles = try await searchArticles()
                users = []
                posts = []
            case .posts:
                posts = try await searchPosts()
                users = []
                articles = []
            case .all:
                async let usersTask = searchUsers()
                async let articlesTask = searchArticles()
                async let postsTask = searchPosts()
                
                let (fetchedUsers, fetchedArticles, fetchedPosts) = try await (usersTask, articlesTask, postsTask)
                users = fetchedUsers
                articles = fetchedArticles
                posts = fetchedPosts
            }
        } catch {
            self.error = error.localizedDescription
            print("❌ Search failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func searchUsers() async throws -> [UserInfo] {
        return try await appwrite.databases.listDocuments(
            databaseId: AppwriteService.databaseId,
            collectionId: AppwriteService.Constants.usersCollectionId,
            queries: [
                Query.search("name", value: searchText),
                Query.limit(10)
            ]
        ).documents.compactMap { document in
            guard let name = document.data["name"]?.value as? String,
                  let email = document.data["email"]?.value as? String else {
                return nil
            }
            return UserInfo(id: document.id, name: name, email: email)
        }
    }
    
    private func searchArticles() async throws -> [Article] {
        return try await appwrite.databases.listDocuments(
            databaseId: AppwriteService.databaseId,
            collectionId: AppwriteService.articlesCollectionId,
            queries: [
                Query.search("title", value: searchText),
                Query.orderDesc("createdAt"),
                Query.limit(10)
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
            
            let article = Article(
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
                commentCount: document.data["commentCount"]?.value as? Int ?? 0,
                likes: document.data["likes"]?.value as? Int ?? 0
            )
            return article
        }
    }
    
    private func searchPosts() async throws -> [Post] {
        return try await appwrite.databases.listDocuments(
            databaseId: AppwriteService.databaseId,
            collectionId: AppwriteService.postsCollectionId,
            queries: [
                Query.search("caption", value: searchText),
                Query.orderDesc("createdAt"),
                Query.limit(10)
            ]
        ).documents.compactMap { document in
            // Map document to Post model
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
    }
    
    private func clearResults() {
        users = []
        articles = []
        posts = []
        error = nil
    }
} 