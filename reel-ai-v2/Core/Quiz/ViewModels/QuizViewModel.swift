import Foundation
import SwiftUI
import Appwrite
import os

class QuizViewModel: ObservableObject {
    @Published var quiz: Quiz?
    @Published var currentQuestionIndex = 0
    @Published var selectedAnswers: [String: String] = [:]  // questionId: selectedAnswer
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isQuizCompleted = false
    @Published var score: Int = 0
    
    private let quizService: QuizServiceProtocol
    private let openAIService: OpenAIQuizGenerationService
    private let userId: String
    private let articleId: String
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.reel-ai", category: "QuizViewModel")
    private let appwrite = AppwriteService.shared
    
    var currentQuestion: QuizQuestion? {
        guard let quiz = quiz, currentQuestionIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentQuestionIndex]
    }
    
    var progress: Double {
        guard let quiz = quiz else { return 0 }
        return Double(currentQuestionIndex) / Double(quiz.questions.count)
    }
    
    var isLastQuestion: Bool {
        guard let quiz = quiz else { return true }
        return currentQuestionIndex == quiz.questions.count - 1
    }
    
    init(quizService: QuizServiceProtocol, openAIService: OpenAIQuizGenerationService, userId: String, articleId: String) {
        self.quizService = quizService
        self.openAIService = openAIService
        self.userId = userId
        self.articleId = articleId
    }
    
    @MainActor
    func loadQuiz() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            logger.info("Starting quiz load for article: \(self.articleId)")
            // Try to load existing quiz
            let existingQuizzes = try await quizService.getQuizzesByArticle(articleId: articleId)
            if let existingQuiz = existingQuizzes.first {
                logger.info("Found existing quiz: \(existingQuiz.id)")
                self.quiz = existingQuiz
                return
            }
            
            logger.info("No existing quiz found, generating new quiz")
            // Generate new quiz if none exists
            let article = try await loadArticle()
            logger.info("Article loaded successfully, generating quiz")
            let generatedQuiz = try await openAIService.generateQuiz(from: article)
            logger.info("Quiz generated successfully, saving to database")
            self.quiz = try await quizService.createQuiz(generatedQuiz)
            logger.info("Quiz saved successfully with ID: \(self.quiz?.id ?? "unknown")")
        } catch {
            logger.error("Failed to load/generate quiz: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    func selectAnswer(_ answer: String) {
        guard let currentQuestion = currentQuestion else {
            logger.error("Attempted to select answer but no current question exists")
            return
        }
        logger.info("Selected answer '\(answer)' for question \(currentQuestion.id) [\(self.currentQuestionIndex + 1)/\(self.quiz?.questions.count ?? 0)]")
        selectedAnswers[currentQuestion.id] = answer
    }
    
    func nextQuestion() {
        guard let quiz = quiz, currentQuestionIndex < quiz.questions.count else {
            logger.error("Attempted to move to next question but no more questions exist")
            return
        }
        
        let previousQuestionIndex = self.currentQuestionIndex
        currentQuestionIndex += 1
        logger.info("Moving from question \(previousQuestionIndex + 1) to \(self.currentQuestionIndex + 1)")
        
        if currentQuestionIndex == quiz.questions.count {
            logger.info("Reached end of quiz, completing")
            completeQuiz()
        }
    }
    
    private func completeQuiz() {
        guard let quiz = quiz else {
            logger.error("Attempted to complete quiz but no quiz exists")
            return
        }
        
        logger.info("Starting quiz completion process")
        
        // Calculate score
        var correctAnswers = 0
        for question in quiz.questions {
            let selectedAnswer = selectedAnswers[question.id]
            let isCorrect = selectedAnswer == question.correctAnswer
            logger.info("Question \(question.id): selected=\(selectedAnswer ?? "none") correct=\(question.correctAnswer) isCorrect=\(isCorrect)")
            if isCorrect {
                correctAnswers += 1
            }
        }
        
        // Ensure UI updates happen on the main thread
        Task { @MainActor in
            self.score = correctAnswers
            self.isQuizCompleted = true
            
            logger.info("Quiz completed - Score: \(self.score)/\(quiz.questions.count) (\(Double(self.score) / Double(quiz.questions.count) * 100)%)")
        }
        
        // Save quiz attempt
        Task {
            do {
                logger.info("Saving quiz attempt")
                let attempt = QuizAttempt(
                    id: ID.unique(),
                    userId: userId,
                    quizId: quiz.id,
                    articleId: articleId,
                    score: correctAnswers,
                    totalQuestions: quiz.questions.count,
                    answers: selectedAnswers,
                    completedAt: Date()
                )
                
                _ = try await quizService.saveQuizAttempt(attempt)
                logger.info("Quiz attempt saved successfully")
            } catch {
                // Ensure error updates happen on the main thread
                await MainActor.run {
                    logger.error("Failed to save quiz attempt: \(error.localizedDescription)")
                    self.error = error
                }
            }
        }
    }
    
    private func loadArticle() async throws -> Article {
        logger.info("Loading article with ID: \(self.articleId)")
        
        // Get the article from the database
        let documents = try await appwrite.databases.listDocuments(
            databaseId: AppwriteService.databaseId,
            collectionId: AppwriteService.articlesCollectionId,
            queries: [Query.equal("$id", value: self.articleId)]
        )
        
        guard let document = documents.documents.first else {
            logger.error("Article not found with ID: \(self.articleId)")
            throw QuizError.quizNotFound
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let userId = document.data["userId"]?.value as? String,
              let author = document.data["author"]?.value as? String,
              let title = document.data["title"]?.value as? String,
              let content = document.data["content"]?.value as? String,
              let createdAtString = document.data["createdAt"]?.value as? String,
              let updatedAtString = document.data["updatedAt"]?.value as? String,
              let createdAt = formatter.date(from: createdAtString),
              let updatedAt = formatter.date(from: updatedAtString),
              let tags = document.data["tags"]?.value as? [String],
              let likes = document.data["likes"]?.value as? Int,
              let views = document.data["views"]?.value as? Int else {
            logger.error("Failed to parse article data")
            throw QuizError.decodingError
        }
        
        let article = Article(
            id: document.id,
            userId: userId,
            author: author,
            title: title,
            content: content,
            summary: nil,
            thumbnailUrl: nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: .published,
            tags: tags,
            views: views,
            readingTime: 0,
            commentCount: 0,
            likes: likes
        )
        
        logger.info("Successfully loaded article: \(article.title)")
        return article
    }
    
    func reset() {
        logger.info("Resetting quiz state")
        currentQuestionIndex = 0
        selectedAnswers.removeAll()
        isQuizCompleted = false
        score = 0
    }
} 