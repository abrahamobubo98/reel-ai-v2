import Foundation

struct Article: Codable, Identifiable {
    let id: String
    let userId: String
    let author: String
    let title: String
    let content: String
    let coverImageId: String?
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let likes: Int
    let views: Int
    let comments: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case userId
        case author
        case title
        case content
        case coverImageId
        case tags
        case createdAt
        case updatedAt
        case likes
        case views
        case comments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        author = try container.decode(String.self, forKey: .author)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        coverImageId = try container.decode(String?.self, forKey: .coverImageId)
        tags = try container.decode([String].self, forKey: .tags)
        likes = try container.decode(Int.self, forKey: .likes)
        views = try container.decode(Int.self, forKey: .views)
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
        
        if let dateString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                updatedAt = date
            } else {
                throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: container, debugDescription: "Date string does not match expected format")
            }
        } else {
            updatedAt = Date()
        }
    }
    
    init(id: String, userId: String, author: String, title: String, content: String, coverImageId: String?, tags: [String], createdAt: Date, updatedAt: Date, likes: Int, views: Int, comments: Int = 0) {
        self.id = id
        self.userId = userId
        self.author = author
        self.title = title
        self.content = content
        self.coverImageId = coverImageId
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likes = likes
        self.views = views
        self.comments = comments
    }
} 