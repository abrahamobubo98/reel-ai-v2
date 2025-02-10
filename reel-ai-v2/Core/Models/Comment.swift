import Foundation

struct Comment: Identifiable, Codable {
    let id: String          // 36 characters (UUID)
    let documentId: String  // 36 characters (UUID)
    let userId: String      // 36 characters (UUID)
    let author: String      // Max 100 characters
    let text: String        // Max 1000 characters
    let createdAt: Date
    
    static let maxTextLength = 1000
    static let maxAuthorLength = 100
    
    init(id: String, documentId: String, userId: String, author: String, text: String, createdAt: Date) {
        self.id = id
        self.documentId = documentId
        self.userId = userId
        self.author = author
        self.text = text
        self.createdAt = createdAt
    }
    
    static func validateText(_ text: String) -> Bool {
        !text.isEmpty && text.count <= maxTextLength
    }
    
    static func validateAuthor(_ author: String) -> Bool {
        !author.isEmpty && author.count <= maxAuthorLength
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case documentId
        case userId
        case author
        case text
        case createdAt = "$createdAt"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        documentId = try container.decode(String.self, forKey: .documentId)
        userId = try container.decode(String.self, forKey: .userId)
        author = try container.decode(String.self, forKey: .author)
        text = try container.decode(String.self, forKey: .text)
        
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