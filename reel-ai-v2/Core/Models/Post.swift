import Foundation

struct Post: Identifiable {
    let id: String
    let userId: String
    let author: String
    let caption: String
    let mediaId: String
    let mediaType: MediaType
    let likes: Int
    let comments: Int
    let createdAt: Date
}

enum MediaType: String {
    case image
    case video
} 