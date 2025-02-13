import Foundation
import Appwrite

public struct Article: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let author: String
    public let title: String
    public let content: String
    public let summary: String?
    public let thumbnailUrl: URL?
    public let createdAt: Date
    public let updatedAt: Date
    public let status: ArticleStatus
    public let tags: [String]
    public let views: Int
    public let readingTime: Int
    public let commentCount: Int
    public let likes: Int
    
    public enum ArticleStatus: String, Codable {
        case draft
        case published
        case archived
    }
    
    public init(id: String, userId: String, author: String, title: String, content: String, summary: String?, thumbnailUrl: URL?, createdAt: Date, updatedAt: Date, status: ArticleStatus, tags: [String], views: Int, readingTime: Int, commentCount: Int, likes: Int) {
        self.id = id
        self.userId = userId
        self.author = author
        self.title = title
        self.content = content
        self.summary = summary
        self.thumbnailUrl = thumbnailUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.tags = tags
        self.views = views
        self.readingTime = readingTime
        self.commentCount = commentCount
        self.likes = likes
    }
} 