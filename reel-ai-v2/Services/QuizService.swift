import Foundation
import Appwrite
import JSONCodable
import os

// Define a type alias for our document data type
typealias DocumentData = [String: String]

enum QuizError: LocalizedError {
    case decodingError
    case encodingError
    case quizNotFound
    case invalidResponse
    case networkError(Error)
    case documentConversionError(String)
    
    var errorDescription: String? {
        switch self {
        case .decodingError:
            return "Failed to decode quiz data"
        case .encodingError:
            return "Failed to encode quiz data"
        case .quizNotFound:
            return "Quiz not found"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .documentConversionError(let details):
            return "Document conversion error: \(details)"
        }
    }
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
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.reel-ai", category: "QuizService")
    
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
            logger.info("Creating quiz for article: \(quiz.articleId)")
            
            // Log the quiz data for debugging
            logger.info("Quiz data: title=\(quiz.title), questions=\(quiz.questions.count)")
            
            // First try to encode questions to verify the data
            let encodedQuestions = try encodeQuestions(quiz.questions)
            logger.info("Successfully encoded questions")
            
            let documentData: [String: Any] = [
                "articleId": quiz.articleId,
                "title": quiz.title,
                "questions": encodedQuestions,
                "createdAt": quiz.createdAt.iso8601String,
                "articleReferenceId": quiz.articleReferenceId,
                "articleReferenceTitle": quiz.articleReferenceTitle,
                "articleReferenceThumbnail": quiz.articleReferenceThumbnail.absoluteString
            ]
            
            logger.info("Creating document...")
            
            let document = try await databases.createDocument(
                databaseId: databaseId,
                collectionId: Collection.quizzes.id,
                documentId: ID.unique(),
                data: documentData
            )
            
            logger.info("Quiz created successfully with ID: \(document.id)")
            
            // Try to convert back to Quiz object
            do {
                let createdQuiz = try documentToQuiz(document)
                logger.info("Successfully converted document back to Quiz")
                return createdQuiz
            } catch {
                logger.error("Failed to convert created document back to Quiz: \(error.localizedDescription)")
                throw QuizError.decodingError
            }
        } catch let error as AppwriteError {
            logger.error("Appwrite error creating quiz - Type: \(String(describing: error.type)), Message: \(String(describing: error.message))")
            throw QuizError.networkError(error)
        } catch {
            logger.error("Failed to create quiz: \(error.localizedDescription)")
            logger.error("Error type: \(String(describing: type(of: error)))")
            throw QuizError.networkError(error)
        }
    }
    
    func getQuiz(id: String) async throws -> Quiz {
        do {
            logger.info("Fetching quiz with ID: \(id)")
            let document = try await databases.getDocument(
                databaseId: databaseId,
                collectionId: Collection.quizzes.id,
                documentId: id
            )
            logger.info("Quiz fetched successfully")
            return try documentToQuiz(document)
        } catch {
            logger.error("Failed to fetch quiz \(id): \(error.localizedDescription)")
            throw QuizError.networkError(error)
        }
    }
    
    func getQuizzesByArticle(articleId: String) async throws -> [Quiz] {
        do {
            logger.info("Fetching quizzes for article: \(articleId)")
            let documents = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: Collection.quizzes.id,
                queries: [
                    Query.equal("articleId", value: articleId)
                ]
            )
            logger.info("Found \(documents.documents.count) quizzes for article")
            
            var quizzes: [Quiz] = []
            var conversionErrors: [String] = []
            
            for document in documents.documents {
                do {
                    let quiz = try documentToQuiz(document)
                    quizzes.append(quiz)
                } catch {
                    let errorMsg = "Failed to convert document \(document.id): \(error.localizedDescription)"
                    logger.error("\(errorMsg)")
                    conversionErrors.append(errorMsg)
                }
            }
            
            if quizzes.isEmpty && !conversionErrors.isEmpty {
                throw QuizError.documentConversionError(conversionErrors.joined(separator: "; "))
            }
            
            return quizzes
        } catch let error as AppwriteError {
            logger.error("Appwrite error fetching quizzes - Type: \(String(describing: error.type)), Message: \(String(describing: error.message))")
            throw QuizError.networkError(error)
        } catch let error as QuizError {
            logger.error("Quiz error fetching quizzes: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Unexpected error fetching quizzes: \(error.localizedDescription)")
            throw QuizError.networkError(error)
        }
    }
    
    func saveQuizAttempt(_ attempt: QuizAttempt) async throws -> QuizAttempt {
        do {
            logger.info("Saving quiz attempt for user: \(attempt.userId), quiz: \(attempt.quizId)")
            
            // Encode answers dictionary to JSON string
            let encoder = JSONEncoder()
            guard let answersJson = try? encoder.encode(attempt.answers),
                  let answersString = String(data: answersJson, encoding: .utf8) else {
                logger.error("Failed to encode answers to JSON string")
                throw QuizError.encodingError
            }
            
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
                    "answers": answersString,
                    "completedAt": attempt.completedAt.iso8601String
                ]
            )
            logger.info("Quiz attempt saved successfully with score: \(attempt.score)/\(attempt.totalQuestions)")
            return try documentToQuizAttempt(document)
        } catch {
            logger.error("Failed to save quiz attempt: \(error.localizedDescription)")
            throw QuizError.networkError(error)
        }
    }
    
    func getUserQuizHistory(userId: String) async throws -> [QuizAttempt] {
        do {
            logger.info("Fetching quiz history for user: \(userId)")
            let documents = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: Collection.quizAttempts.id,
                queries: [
                    Query.equal("userId", value: userId),
                    Query.orderDesc("completedAt")
                ]
            )
            logger.info("Found \(documents.documents.count) quiz attempts for user")
            return try documents.documents.map { try documentToQuizAttempt($0) }
        } catch {
            logger.error("Failed to fetch quiz history for user \(userId): \(error.localizedDescription)")
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
                logger.error("Failed to convert encoded questions data to string")
                throw QuizError.encodingError
            }
            return jsonString
        } catch {
            logger.error("Failed to encode questions: \(error.localizedDescription)")
            throw QuizError.encodingError
        }
    }
    
    private func documentToQuiz(_ document: Appwrite.Document<[String: AnyCodable]>) throws -> Quiz {
        let id = document.id
        let data = document.data
        logger.info("Converting document \(id) to Quiz")
        
        // Log all available keys in the document
        logger.info("Available document keys: \(data.keys.joined(separator: ", "))")
        
        // Check and log each field
        let articleId = data["articleId"]?.value as? String
        logger.info("articleId: \(articleId ?? "nil")")
        
        let title = data["title"]?.value as? String
        logger.info("title: \(title ?? "nil")")
        
        let questionsString = data["questions"]?.value as? String
        logger.info("questionsString: \(questionsString?.prefix(100) ?? "nil")...")
        
        let createdAtString = data["createdAt"]?.value as? String
        logger.info("createdAtString: \(createdAtString ?? "nil")")
        
        let articleReferenceId = data["articleReferenceId"]?.value as? String
        logger.info("articleReferenceId: \(articleReferenceId ?? "nil")")
        
        let articleReferenceTitle = data["articleReferenceTitle"]?.value as? String
        logger.info("articleReferenceTitle: \(articleReferenceTitle ?? "nil")")
        
        let articleReferenceThumbnailString = data["articleReferenceThumbnail"]?.value as? String
        logger.info("articleReferenceThumbnail: \(articleReferenceThumbnailString ?? "nil")")
        
        // Validate all required fields are present
        guard let articleId = articleId,
              let title = title,
              let questionsString = questionsString,
              let createdAtString = createdAtString,
              let articleReferenceId = articleReferenceId,
              let articleReferenceTitle = articleReferenceTitle,
              let articleReferenceThumbnailString = articleReferenceThumbnailString else {
            logger.error("Missing required fields in document \(id)")
            throw QuizError.decodingError
        }
        
        // Try to create URL
        guard let articleReferenceThumbnail = URL(string: articleReferenceThumbnailString) else {
            logger.error("Invalid URL for articleReferenceThumbnail: \(articleReferenceThumbnailString)")
            throw QuizError.decodingError
        }
        
        // Try to parse date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let createdAt = formatter.date(from: createdAtString) else {
            logger.error("Invalid date format for createdAt: \(createdAtString)")
            throw QuizError.decodingError
        }
        
        // Try to decode questions
        guard let questionsData = questionsString.data(using: .utf8) else {
            logger.error("Failed to convert questions string to data")
            throw QuizError.decodingError
        }
        
        do {
            let questions = try JSONDecoder().decode([QuizQuestion].self, from: questionsData)
            logger.info("Successfully decoded \(questions.count) questions")
            
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
        } catch {
            logger.error("Failed to decode questions JSON: \(error.localizedDescription)")
            if let jsonString = String(data: questionsData, encoding: .utf8) {
                logger.error("Questions JSON content: \(jsonString)")
            }
            throw QuizError.decodingError
        }
    }
    
    private func documentToQuizAttempt(_ document: Appwrite.Document<[String: AnyCodable]>) throws -> QuizAttempt {
        let id = document.id
        let data = document.data
        logger.info("Converting document \(id) to QuizAttempt")
        logger.info("Available document keys: \(data.keys.joined(separator: ", "))")
        
        // Log each field's presence and type
        data.forEach { key, value in
            logger.info("\(key): \(String(describing: value.value)) (type: \(String(describing: Swift.type(of: value.value))))")
        }
        
        // Now try to extract and convert the fields
        guard let userId = data["userId"]?.value as? String,
              let quizId = data["quizId"]?.value as? String,
              let articleId = data["articleId"]?.value as? String,
              let score = data["score"]?.value as? Int,
              let totalQuestions = data["totalQuestions"]?.value as? Int,
              let answersString = data["answers"]?.value as? String,
              let completedAtString = data["completedAt"]?.value as? String else {
            logger.error("Failed to extract or convert required fields from document")
            throw QuizError.decodingError
        }
        
        // Try to parse the date with detailed error handling
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let completedAt = formatter.date(from: completedAtString) else {
            logger.error("Failed to parse completedAt date: \(completedAtString)")
            throw QuizError.decodingError
        }
        
        // Try to decode the answers JSON string
        guard let answersData = answersString.data(using: .utf8) else {
            logger.error("Failed to convert answers string to data: \(answersString)")
            throw QuizError.decodingError
        }
        
        do {
            let answers = try JSONDecoder().decode([String: String].self, from: answersData)
            logger.info("Successfully decoded answers dictionary with \(answers.count) entries")
            
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
        } catch {
            logger.error("Failed to decode answers JSON: \(error.localizedDescription)")
            logger.error("Raw answers string: \(answersString)")
            throw QuizError.decodingError
        }
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
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
} 