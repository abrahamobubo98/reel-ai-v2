import Foundation

public enum MediaType: String, Codable {
    case image
    case video
}

public struct Post: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let author: String
    public let caption: String
    public let mediaId: String
    public let mediaType: MediaType
    public let likes: Int
    public let comments: Int
    public let createdAt: Date
    
    public enum CodingKeys: String, CodingKey {
        case id = "$id"
        case userId
        case author
        case caption
        case mediaId
        case mediaType
        case likes
        case comments
        case createdAt
    }
    
    public init(id: String, userId: String, author: String, caption: String, mediaId: String, mediaType: MediaType, likes: Int, comments: Int, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.author = author
        self.caption = caption
        self.mediaId = mediaId
        self.mediaType = mediaType
        self.likes = likes
        self.comments = comments
        self.createdAt = createdAt
    }
} 