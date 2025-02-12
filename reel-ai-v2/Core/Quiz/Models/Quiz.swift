import Foundation
import Appwrite

public struct Quiz: Codable, Identifiable {
    public let id: String
    public let articleId: String
    public let title: String
    public let questions: [QuizQuestion]
    public let createdAt: Date
    public let articleReferenceId: String
    public let articleReferenceTitle: String
    public let articleReferenceThumbnail: URL
    
    public enum CodingKeys: String, CodingKey {
        case id = "$id"
        case articleId
        case title
        case questions
        case createdAt
        case articleReferenceId
        case articleReferenceTitle
        case articleReferenceThumbnail
    }
}

public struct QuizQuestion: Codable, Identifiable {
    public let id: String
    public let question: String
    public let options: [String: String]
    public let correctAnswer: String
    public let explanation: String
    
    public init(id: String, question: String, options: [String: String], correctAnswer: String, explanation: String) {
        self.id = id
        self.question = question
        self.options = options
        self.correctAnswer = correctAnswer
        self.explanation = explanation
    }
}

public struct QuizAttempt: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let quizId: String
    public let articleId: String
    public let score: Int
    public let totalQuestions: Int
    public let answers: [String: String]
    public let completedAt: Date
    
    public enum CodingKeys: String, CodingKey {
        case id = "$id"
        case userId
        case quizId
        case articleId
        case score
        case totalQuestions
        case answers
        case completedAt
    }
    
    public var scorePercentage: Double {
        Double(score) / Double(totalQuestions) * 100
    }
    
    public init(id: String, userId: String, quizId: String, articleId: String, score: Int, totalQuestions: Int, answers: [String: String], completedAt: Date) {
        self.id = id
        self.userId = userId
        self.quizId = quizId
        self.articleId = articleId
        self.score = score
        self.totalQuestions = totalQuestions
        self.answers = answers
        self.completedAt = completedAt
    }
}

public struct QuizStatistics: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let totalAttempted: Int
    public let averageScore: Double
    public let completionRate: Double
    public let topPerformingTopics: [String: Double]
    public let lastUpdated: Date
    
    public enum CodingKeys: String, CodingKey {
        case id = "$id"
        case userId
        case totalAttempted
        case averageScore
        case completionRate
        case topPerformingTopics
        case lastUpdated
    }
    
    public init(id: String, userId: String, totalAttempted: Int, averageScore: Double, completionRate: Double, topPerformingTopics: [String: Double], lastUpdated: Date) {
        self.id = id
        self.userId = userId
        self.totalAttempted = totalAttempted
        self.averageScore = averageScore
        self.completionRate = completionRate
        self.topPerformingTopics = topPerformingTopics
        self.lastUpdated = lastUpdated
    }
}