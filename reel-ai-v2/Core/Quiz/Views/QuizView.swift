import SwiftUI
import Foundation
import Appwrite
import UIKit
import JSONCodable

struct QuizView: View {
    @StateObject var viewModel: QuizViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading Quiz...")
            } else if viewModel.isQuizCompleted {
                QuizResultView(
                    score: viewModel.score,
                    totalQuestions: viewModel.quiz?.questions.count ?? 0,
                    onDismiss: { dismiss() },
                    onRetry: { viewModel.reset() }
                )
            } else {
                quizContent
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
        .task {
            await viewModel.loadQuiz()
        }
    }
    
    private var quizContent: some View {
        VStack(spacing: 20) {
            QuizProgressView(
                progress: viewModel.progress,
                currentQuestion: viewModel.currentQuestionIndex + 1,
                totalQuestions: viewModel.quiz?.questions.count ?? 0
            )
            .padding(.top)
            
            if let currentQuestion = viewModel.currentQuestion {
                QuestionView(
                    question: currentQuestion,
                    selectedAnswer: viewModel.selectedAnswers[currentQuestion.id],
                    onAnswerSelected: { answer in
                        viewModel.selectAnswer(answer)
                    },
                    questionNumber: viewModel.currentQuestionIndex + 1
                )
            }
            
            Spacer()
            
            if let currentQuestion = viewModel.currentQuestion,
               viewModel.selectedAnswers[currentQuestion.id] != nil {
                Button(action: {
                    viewModel.nextQuestion()
                }) {
                    Text(viewModel.isLastQuestion ? "Finish Quiz" : "Next Question")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
}

#if DEBUG
// Mock services for previews
private class MockQuizService: QuizServiceProtocol {
    func createQuiz(_ quiz: Quiz) async throws -> Quiz { quiz }
    func getQuiz(id: String) async throws -> Quiz { fatalError() }
    func getQuizzesByArticle(articleId: String) async throws -> [Quiz] { [] }
    func saveQuizAttempt(_ attempt: QuizAttempt) async throws -> QuizAttempt { attempt }
    func getUserQuizHistory(userId: String) async throws -> [QuizAttempt] { [] }
    func getQuizStatistics(userId: String) async throws -> QuizStatistics { 
        QuizStatistics(id: "", userId: "", totalAttempted: 0, averageScore: 0, completionRate: 0, topPerformingTopics: [:], lastUpdated: Date())
    }
    func updateQuizStatistics(userId: String, statistics: QuizStatistics) async throws -> QuizStatistics { statistics }
}

private class MockOpenAIQuizService: OpenAIQuizGenerationService {
    func generateQuiz(from article: Article) async throws -> Quiz {
        Quiz(
            id: "mock",
            articleId: "mock",
            title: "Mock Quiz",
            questions: [],
            createdAt: Date(),
            articleReferenceId: "mock",
            articleReferenceTitle: "Mock Article",
            articleReferenceThumbnail: URL(string: "https://example.com")!
        )
    }
}

struct QuizView_Previews: PreviewProvider {
    static var previews: some View {
        QuizView(viewModel: QuizViewModel(
            quizService: MockQuizService(),
            openAIService: MockOpenAIQuizService(),
            userId: "preview-user",
            articleId: "preview-article"
        ))
    }
}
#endif 