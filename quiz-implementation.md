# Quiz Implementation Plan

## Overview
This document outlines the implementation plan for adding AI-powered quiz generation functionality to the Reel AI application. The system will generate quizzes from articles and track user progress.

## Table of Contents
1. [Data Models](#data-models)
2. [AI Integration](#ai-integration)
3. [Database Structure](#database-structure)
4. [Services](#services)
5. [User Interface](#user-interface)
6. [Implementation Steps](#implementation-steps)

## Data Models

### Quiz Model
```swift
struct Quiz: Codable, Identifiable {
    let id: String
    let articleId: String
    let title: String
    let questions: [QuizQuestion]
    let createdAt: Date
    var articleReference: ArticleReference
}

struct QuizQuestion: Codable {
    let id: String
    let question: String
    let options: [String: String]  // e.g., ["A": "Option 1", "B": "Option 2"]
    let correctAnswer: String
    let explanation: String
}

struct ArticleReference: Codable {
    let id: String
    let title: String
    let thumbnailUrl: String?
}
```

### Quiz Attempt Model
```swift
struct QuizAttempt: Codable, Identifiable {
    let id: String
    let userId: String
    let quizId: String
    let articleId: String
    let score: Int
    let totalQuestions: Int
    let answers: [String: String]  // questionId: selectedAnswer
    let completedAt: Date
    
    var scorePercentage: Double {
        Double(score) / Double(totalQuestions) * 100
    }
}
```

## AI Integration

### OpenAI Service
```swift
class OpenAIService {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    func generateQuiz(from article: Article) async throws -> Quiz {
        let prompt = createQuizPrompt(from: article)
        let response = try await makeOpenAIRequest(prompt: prompt)
        return try parseResponse(response, articleId: article.id)
    }
}
```

### Prompt Structure
```swift
private func createQuizPrompt(from article: Article) -> String {
    """
    You are a professional quiz creator. Create a multiple-choice quiz based on the following article.
    
    Article Title: \(article.title)
    Article Content: \(article.content)
    
    Generate 5 multiple choice questions following these rules:
    1. Questions should test understanding, not just memorization
    2. Each question should have exactly 4 options (A, B, C, D)
    3. Only one option should be correct
    4. Include a brief explanation for why the correct answer is right
    
    Format your response in JSON like this:
    {
        "questions": [
            {
                "question": "Question text here?",
                "options": {
                    "A": "First option",
                    "B": "Second option",
                    "C": "Third option",
                    "D": "Fourth option"
                },
                "correctAnswer": "A",
                "explanation": "Explanation why A is correct"
            }
        ]
    }
    """
}
```

## Database Structure

### Appwrite Collections
1. **Quizzes Collection**
   - Document ID: Auto-generated
   - Fields:
     - articleId (string)
     - title (string)
     - questions (array)
     - createdAt (datetime)
     - articleReference (object)

2. **Quiz Attempts Collection**
   - Document ID: Auto-generated
   - Fields:
     - userId (string)
     - quizId (string)
     - articleId (string)
     - score (number)
     - totalQuestions (number)
     - answers (object)
     - completedAt (datetime)

### Indexes
```swift
// Create indexes for efficient querying
try await databases.createIndex(
    databaseId: databaseId,
    collectionId: "quiz_attempts",
    key: "user_quiz_index",
    type: "key",
    attributes: ["userId", "quizId"]
)
```

### Profile Statistics Collection
```swift
// Add new collection for aggregated statistics
try await databases.createCollection(
    databaseId: databaseId,
    collectionId: "quiz_statistics",
    name: "Quiz Statistics"
)

// Fields
- userId (string)
- totalAttempted (number)
- averageScore (number)
- completionRate (number)
- topPerformingTopics (object)
- lastUpdated (datetime)
```

## Services

### Quiz History Service
```swift
protocol QuizHistoryService {
    func saveQuizAttempt(_ attempt: QuizAttempt) async throws
    func getUserQuizHistory(userId: String) async throws -> [QuizAttempt]
    func getQuizAttempt(id: String) async throws -> QuizAttempt?
    func getArticleQuizzes(articleId: String) async throws -> [Quiz]
}
```

### Quiz Generation Service
```swift
protocol QuizGenerationService {
    func generateQuiz(from article: Article) async throws -> Quiz
}
```

## User Interface

### Main Views
1. **QuizHistoryView**
   - Displays list of past quiz attempts
   - Shows statistics and progress
   - Links to individual quiz reviews

2. **QuizView**
   - Presents quiz questions
   - Handles answer selection
   - Shows immediate feedback
   - Displays final score

3. **QuizDetailView**
   - Shows detailed review of completed quiz
   - Displays correct/incorrect answers
   - Provides explanations
   - Links back to original article

4. **ArticleDetailView Updates**
   - Add quiz section at bottom of article
   ```swift
   struct ArticleDetailView: View {
       @StateObject var viewModel: ArticleDetailViewModel
       @State private var showingQuiz = false
       
       var body: some View {
           ScrollView {
               // Existing article content
               
               // Quiz Section
               VStack(spacing: 16) {
                   if let existingQuiz = viewModel.articleQuiz {
                       QuizPreviewCard(quiz: existingQuiz)
                   }
                   
                   Button(action: {
                       showingQuiz = true
                   }) {
                       Label("Take Quiz", systemImage: "pencil.circle")
                           .font(.headline)
                           .foregroundColor(.white)
                           .frame(maxWidth: .infinity)
                           .padding()
                           .background(Color.blue)
                           .cornerRadius(10)
                   }
               }
               .padding()
           }
           .sheet(isPresented: $showingQuiz) {
               QuizView(articleId: viewModel.article.id)
           }
       }
   }
   ```

5. **ProfileView Updates**
   - Add quiz statistics section
   ```swift
   struct ProfileView: View {
       @StateObject var viewModel: ProfileViewModel
       
       var body: some View {
           List {
               // Existing profile content
               
               // Quiz Statistics Section
               Section("Quiz Performance") {
                   QuizStatisticsCard(
                       totalQuizzes: viewModel.quizStats.totalAttempted,
                       averageScore: viewModel.quizStats.averageScore,
                       completionRate: viewModel.quizStats.completionRate
                   )
                   
                   NavigationLink("View Quiz History") {
                       QuizHistoryView(userId: viewModel.userId)
                   }
               }
           }
       }
   }
   ```

3. **QuizStatisticsCard**
   ```swift
   struct QuizStatisticsCard: View {
       let totalQuizzes: Int
       let averageScore: Double
       let completionRate: Double
       
       var body: some View {
           VStack(spacing: 16) {
               HStack(spacing: 20) {
                   StatisticItem(
                       title: "Total Quizzes",
                       value: "\(totalQuizzes)",
                       icon: "list.bullet"
                   )
                   
                   StatisticItem(
                       title: "Avg. Score",
                       value: "\(Int(averageScore))%",
                       icon: "chart.bar.fill"
                   )
                   
                   StatisticItem(
                       title: "Completion",
                       value: "\(Int(completionRate))%",
                       icon: "checkmark.circle.fill"
                   )
               }
           }
           .padding()
           .background(Color(.systemBackground))
           .cornerRadius(12)
           .shadow(radius: 2)
       }
   }
   ```

### View Models

### ArticleDetailViewModel
```swift
class ArticleDetailViewModel: ObservableObject {
    @Published var article: Article
    @Published var articleQuiz: Quiz?
    @Published var isLoadingQuiz = false
    @Published var error: Error?
    
    private let quizService: QuizGenerationService
    
    func loadOrGenerateQuiz() async {
        isLoadingQuiz = true
        defer { isLoadingQuiz = false }
        
        do {
            // Try to load existing quiz
            if let quiz = try await quizService.getArticleQuizzes(articleId: article.id).first {
                articleQuiz = quiz
                return
            }
            
            // Generate new quiz if none exists
            articleQuiz = try await quizService.generateQuiz(from: article)
        } catch {
            self.error = error
        }
    }
}
```

### ProfileViewModel
```swift
class ProfileViewModel: ObservableObject {
    @Published var quizStats: QuizStatistics
    @Published var isLoading = false
    
    private let quizHistoryService: QuizHistoryService
    let userId: String
    
    struct QuizStatistics {
        let totalAttempted: Int
        let averageScore: Double
        let completionRate: Double
        let recentQuizzes: [QuizAttempt]
        let topPerformingTopics: [String: Double]
    }
    
    func loadQuizStatistics() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let attempts = try await quizHistoryService.getUserQuizHistory(userId: userId)
            quizStats = calculateStatistics(from: attempts)
        } catch {
            // Handle error
        }
    }
    
    private func calculateStatistics(from attempts: [QuizAttempt]) -> QuizStatistics {
        // Calculate comprehensive statistics
        let total = attempts.count
        let avgScore = attempts.reduce(0.0) { $0 + $1.scorePercentage } / Double(total)
        let completion = Double(attempts.filter { $0.score > 0 }.count) / Double(total) * 100
        
        // Calculate topic performance
        var topicScores: [String: (total: Double, count: Int)] = [:]
        for attempt in attempts {
            // Aggregate scores by topic/category
        }
        
        return QuizStatistics(
            totalAttempted: total,
            averageScore: avgScore,
            completionRate: completion,
            recentQuizzes: Array(attempts.prefix(5)),
            topPerformingTopics: topicScores.mapValues { $0.total / Double($0.count) }
        )
    }
}
```

## Implementation Steps

### Phase 1: Foundation
1. Create data models
2. Set up Appwrite collections and indexes
3. Implement basic services
4. Add quiz generation button to ArticleDetailView
5. Set up profile statistics collection

### Phase 2: AI Integration
1. Set up OpenAI service
2. Implement quiz generation
3. Add caching mechanism
4. Implement quiz caching per article
5. Add background quiz generation

### Phase 3: User Interface
1. Create quiz taking interface
2. Implement history view
3. Add statistics and progress tracking
4. Integrate quiz UI with articles
5. Add profile statistics view
6. Implement detailed analytics dashboard

### Phase 4: Enhancement
1. Add difficulty levels
2. Implement spaced repetition
3. Add quiz sharing capabilities

## Security Considerations

1. **API Key Protection**
   - Store OpenAI API key securely
   - Use environment variables
   - Implement API proxy if needed

2. **Rate Limiting**
   - Implement request throttling
   - Cache generated quizzes
   - Monitor API usage

3. **Data Privacy**
   - Secure user quiz history
   - Implement proper access controls
   - Follow data retention policies

## Performance Optimization

1. **Caching Strategy**
   - Cache generated quizzes
   - Implement local storage
   - Use lazy loading for history

2. **API Usage**
   - Batch quiz generation
   - Implement retry logic
   - Handle timeout scenarios

## Testing Strategy

1. **Unit Tests**
   - Test quiz generation
   - Validate scoring logic
   - Check history tracking

2. **Integration Tests**
   - Test API integration
   - Verify database operations
   - Check user flow

3. **UI Tests**
   - Test quiz interface
   - Verify navigation
   - Check accessibility

## Future Enhancements

1. **Features**
   - Multiple quiz formats
   - Collaborative quizzes
   - Custom quiz creation

2. **Analytics**
   - Detailed performance metrics
   - Learning pattern analysis
   - Progress tracking

3. **Social Features**
   - Quiz sharing
   - Leaderboards
   - Achievement system 