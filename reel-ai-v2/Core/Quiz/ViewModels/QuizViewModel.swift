import Foundation
import SwiftUI
import Appwrite

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
            // Try to load existing quiz
            let existingQuizzes = try await quizService.getQuizzesByArticle(articleId: articleId)
            if let existingQuiz = existingQuizzes.first {
                self.quiz = existingQuiz
                return
            }
            
            // Generate new quiz if none exists
            let article = try await loadArticle()
            let generatedQuiz = try await openAIService.generateQuiz(from: article)
            self.quiz = try await quizService.createQuiz(generatedQuiz)
        } catch {
            self.error = error
        }
    }
    
    func selectAnswer(_ answer: String) {
        guard let currentQuestion = currentQuestion else { return }
        selectedAnswers[currentQuestion.id] = answer
    }
    
    func nextQuestion() {
        guard let quiz = quiz, currentQuestionIndex < quiz.questions.count else { return }
        currentQuestionIndex += 1
        
        if currentQuestionIndex == quiz.questions.count {
            completeQuiz()
        }
    }
    
    private func completeQuiz() {
        guard let quiz = quiz else { return }
        
        // Calculate score
        var correctAnswers = 0
        for question in quiz.questions {
            if selectedAnswers[question.id] == question.correctAnswer {
                correctAnswers += 1
            }
        }
        
        score = correctAnswers
        isQuizCompleted = true
        
        // Save quiz attempt
        Task {
            do {
                let attempt = QuizAttempt(
                    id: ID.unique(),
                    userId: userId,
                    quizId: quiz.id,
                    articleId: articleId,
                    score: score,
                    totalQuestions: quiz.questions.count,
                    answers: selectedAnswers,
                    completedAt: Date()
                )
                
                _ = try await quizService.saveQuizAttempt(attempt)
            } catch {
                self.error = error
            }
        }
    }
    
    private func loadArticle() async throws -> Article {
        // Implement article loading logic here
        // This should fetch the article from your ArticleService
        fatalError("Article loading not implemented")
    }
    
    func reset() {
        currentQuestionIndex = 0
        selectedAnswers.removeAll()
        isQuizCompleted = false
        score = 0
    }
} 