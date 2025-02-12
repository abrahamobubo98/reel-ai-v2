import Foundation

public protocol OpenAIQuizGenerationService {
    func generateQuiz(from article: Article) async throws -> Quiz
}

public class OpenAIQuizService: OpenAIQuizGenerationService {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    public init() {
        self.apiKey = Config.shared.openAIApiKey
        guard !self.apiKey.isEmpty else {
            fatalError("OpenAI API key not configured")
        }
    }
    
    public func generateQuiz(from article: Article) async throws -> Quiz {
        // Implementation will be added later
        fatalError("Implementation needed")
    }
}