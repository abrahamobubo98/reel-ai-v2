import Foundation
import SwiftUI
import Appwrite

@MainActor
class QuizHistoryViewModel: ObservableObject {
    @Published var quizAttempts: [QuizAttempt] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let quizService: QuizServiceProtocol
    private let userId: String
    
    init(quizService: QuizServiceProtocol, userId: String) {
        self.quizService = quizService
        self.userId = userId
    }
    
    func loadQuizHistory() async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            quizAttempts = try await quizService.getUserQuizHistory(userId: userId)
        } catch {
            self.error = error
        }
    }
    
    var averageScore: Double {
        guard !quizAttempts.isEmpty else { return 0 }
        let totalScore = quizAttempts.reduce(0.0) { $0 + $1.scorePercentage }
        return totalScore / Double(quizAttempts.count)
    }
    
    var completionRate: Double {
        guard !quizAttempts.isEmpty else { return 0 }
        return 100.0 // Since we only store completed attempts
    }
    
    var totalAttempted: Int {
        quizAttempts.count
    }
} 