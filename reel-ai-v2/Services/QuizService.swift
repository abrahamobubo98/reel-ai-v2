import Foundation
import Appwrite
import JSONCodable

// Define a type alias for our document data type
typealias DocumentData = [String: String]

enum QuizError: Error {
    case decodingError
    case encodingError
    case quizNotFound
    case invalidResponse
    case networkError(Error)
}

protocol QuizServiceProtocol {
    func createQuiz(_ quiz: Quiz) async throws -> Quiz
    func getQuiz(id: String) async throws -> Quiz
    func getQuizzesByArticle(articleId: String) async throws -> [Quiz]
    func saveQuizAttempt(_ attempt: QuizAttempt) async throws -> QuizAttempt
    func getUserQuizHistory(userId: String) async throws -> [QuizAttempt]
    func getQuizStatistics(userId: String) async throws -> QuizStatistics
    func updateQuizStatistics(userId: String, statistics: QuizStatistics) async throws -> QuizStatistics
}

class QuizService: QuizServiceProtocol {
    private let databases: Databases
    private let databaseId: String
    
    enum Collection: String {
        case quizzes
        case quizAttempts
        case quizStatistics
        
        var id: String {
            switch self {
            case .quizzes:
                return Config.shared.appwriteQuizzesCollectionId
            case .quizAttempts:
                return Config.shared.appwriteQuizAttemptsCollectionId
            case .quizStatistics:
                return Config.shared.appwriteQuizStatisticsCollectionId
            }
        }
    }
    
    init(databases: Databases, databaseId: String) {
        self.databases = databases
        self.databaseId = databaseId
        
        // Verify that all collection IDs are available
        guard !Collection.quizzes.id.isEmpty,
              !Collection.quizAttempts.id.isEmpty,
              !Collection.quizStatistics.id.isEmpty else {
            fatalError("Quiz collection IDs not found in environment variables")
        }
    }
    
    func createQuiz(_ quiz: Quiz) async throws -> Quiz {
        do {
            let document = try await databases.createDocument(
                databaseId: databaseId,
                collectionId: Collection.quizzes.id,
                documentId: ID.unique(),
                data: [
                    "articleId": quiz.articleId,
                    "title": quiz.title,
                    "questions": try encodeQuestions(quiz.questions),
                    "createdAt": quiz.createdAt.iso8601String,
                    "articleReferenceId": quiz.articleReferenceId,
                    "articleReferenceTitle": quiz.articleReferenceTitle,
                    "articleReferenceThumbnail": quiz.articleReferenceThumbnail.absoluteString
                ] as [String: Any]
            )
            return try documentToQuiz(document)
        } catch {
            throw QuizError.networkError(error)
        }
    }
    
    func getQuiz(id: String) async throws -> Quiz {
        do {
            let document = try await databases.getDocument(
                databaseId: databaseId,
                collectionId: Collection.quizzes.id,
                documentId: id
            )
            return try documentToQuiz(document)
        } catch {
            throw QuizError.networkError(error)
        }
    }
    
    func getQuizzesByArticle(articleId: String) async throws -> [Quiz] {
        do {
            let documents = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: Collection.quizzes.id,
                queries: [
                    Query.equal("articleId", value: articleId)
                ]
            )
            return try documents.documents.map { try documentToQuiz($0) }
        } catch {
            throw QuizError.networkError(error)
        }
    }
    
    func saveQuizAttempt(_ attempt: QuizAttempt) async throws -> QuizAttempt {
        do {
            let document = try await databases.createDocument(
                databaseId: databaseId,
                collectionId: Collection.quizAttempts.id,
                documentId: ID.unique(),
                data: [
                    "userId": attempt.userId,
                    "quizId": attempt.quizId,
                    "articleId": attempt.articleId,
                    "score": attempt.score,
                    "totalQuestions": attempt.totalQuestions,
                    "answers": attempt.answers,
                    "completedAt": attempt.completedAt.iso8601String
                ]
            )
            return try documentToQuizAttempt(document)
        } catch {
            throw QuizError.networkError(error)
        }
    }
    
    func getUserQuizHistory(userId: String) async throws -> [QuizAttempt] {
        do {
            let documents = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: Collection.quizAttempts.id,
                queries: [
                    Query.equal("userId", value: userId),
                    Query.orderDesc("completedAt")
                ]
            )
            return try documents.documents.map { try documentToQuizAttempt($0) }
        } catch {
            throw QuizError.networkError(error)
        }
    }
    
    func getQuizStatistics(userId: String) async throws -> QuizStatistics {
        do {
            let documents = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: Collection.quizStatistics.id,
                queries: [Query.equal("userId", value: userId)]
            )
            
            guard let document = documents.documents.first else {
                throw QuizError.quizNotFound
            }
            
            return try documentToQuizStatistics(document)
        } catch {
            throw QuizError.networkError(error)
        }
    }
    
    func updateQuizStatistics(userId: String, statistics: QuizStatistics) async throws -> QuizStatistics {
        do {
            let document = try await databases.updateDocument(
                databaseId: databaseId,
                collectionId: Collection.quizStatistics.id,
                documentId: statistics.id,
                data: [
                    "totalAttempted": statistics.totalAttempted,
                    "averageScore": statistics.averageScore,
                    "completionRate": statistics.completionRate,
                    "topPerformingTopics": statistics.topPerformingTopics,
                    "lastUpdated": statistics.lastUpdated.iso8601String
                ]
            )
            return try documentToQuizStatistics(document)
        } catch {
            throw QuizError.networkError(error)
        }
    }
    
    // Helper methods
    private func encodeQuestions(_ questions: [QuizQuestion]) throws -> String {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(questions)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw QuizError.encodingError
            }
            return jsonString
        } catch {
            throw QuizError.encodingError
        }
    }
    
    private func documentToQuiz(_ document: Appwrite.Document<[String: AnyCodable]>) throws -> Quiz {
        let id = document.id
        let data = document.data
        guard let articleId = data["articleId"]?.value as? String,
              let title = data["title"]?.value as? String,
              let questionsString = data["questions"]?.value as? String,
              let createdAtString = data["createdAt"]?.value as? String,
              let articleReferenceId = data["articleReferenceId"]?.value as? String,
              let articleReferenceTitle = data["articleReferenceTitle"]?.value as? String,
              let articleReferenceThumbnailString = data["articleReferenceThumbnail"]?.value as? String,
              let articleReferenceThumbnail = URL(string: articleReferenceThumbnailString),
              let createdAt = ISO8601DateFormatter().date(from: createdAtString),
              let questionsData = questionsString.data(using: String.Encoding.utf8),
              let questions = try? JSONDecoder().decode([QuizQuestion].self, from: questionsData) else {
            throw QuizError.decodingError
        }
        
        return Quiz(
            id: id,
            articleId: articleId,
            title: title,
            questions: questions,
            createdAt: createdAt,
            articleReferenceId: articleReferenceId,
            articleReferenceTitle: articleReferenceTitle,
            articleReferenceThumbnail: articleReferenceThumbnail
        )
    }
    
    private func documentToQuizAttempt(_ document: Appwrite.Document<[String: AnyCodable]>) throws -> QuizAttempt {
        let id = document.id
        let data = document.data
        guard let userId = data["userId"]?.value as? String,
              let quizId = data["quizId"]?.value as? String,
              let articleId = data["articleId"]?.value as? String,
              let score = data["score"]?.value as? Int,
              let totalQuestions = data["totalQuestions"]?.value as? Int,
              let answers = data["answers"]?.value as? [String: String],
              let completedAtString = data["completedAt"]?.value as? String,
              let completedAt = ISO8601DateFormatter().date(from: completedAtString) else {
            throw QuizError.decodingError
        }
        
        return QuizAttempt(
            id: id,
            userId: userId,
            quizId: quizId,
            articleId: articleId,
            score: score,
            totalQuestions: totalQuestions,
            answers: answers,
            completedAt: completedAt
        )
    }
    
    private func documentToQuizStatistics(_ document: Appwrite.Document<[String: AnyCodable]>) throws -> QuizStatistics {
        let id = document.id
        let data = document.data
        guard let userId = data["userId"]?.value as? String,
              let totalAttempted = data["totalAttempted"]?.value as? Int,
              let averageScore = data["averageScore"]?.value as? Double,
              let completionRate = data["completionRate"]?.value as? Double,
              let topPerformingTopics = data["topPerformingTopics"]?.value as? [String: Double],
              let lastUpdatedString = data["lastUpdated"]?.value as? String,
              let lastUpdated = ISO8601DateFormatter().date(from: lastUpdatedString) else {
            throw QuizError.decodingError
        }
        
        return QuizStatistics(
            id: id,
            userId: userId,
            totalAttempted: totalAttempted,
            averageScore: averageScore,
            completionRate: completionRate,
            topPerformingTopics: topPerformingTopics,
            lastUpdated: lastUpdated
        )
    }
}

// Helper extension for Date
extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: self)
    }
} 