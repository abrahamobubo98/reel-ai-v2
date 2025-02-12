import Foundation
import os
import Appwrite

public protocol OpenAIQuizGenerationService {
    func generateQuiz(from article: Article) async throws -> Quiz
}

public class OpenAIQuizService: OpenAIQuizGenerationService {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.reel-ai", category: "OpenAIQuizService")
    
    public init() {
        self.apiKey = Config.shared.openAIApiKey
        guard !self.apiKey.isEmpty else {
            logger.error("OpenAI API key not configured")
            fatalError("OpenAI API key not configured")
        }
    }
    
    public func generateQuiz(from article: Article) async throws -> Quiz {
        logger.info("Starting quiz generation for article: \(article.id)")
        
        // Create the prompt for GPT
        let prompt = """
        Generate a multiple choice quiz based on this article. The quiz should have 5 questions.
        Each question should have 4 options (A, B, C, D) and one correct answer.
        Also provide a brief explanation for the correct answer.
        
        Article Title: \(article.title)
        Article Content: \(article.content)
        
        Respond with ONLY a JSON object in exactly this format (no other text):
        {
            "questions": [
                {
                    "id": "q1",
                    "question": "What is the main topic discussed in the article?",
                    "options": {
                        "A": "First option",
                        "B": "Second option",
                        "C": "Third option",
                        "D": "Fourth option"
                    },
                    "correctAnswer": "A",
                    "explanation": "This is the correct answer because..."
                }
            ]
        }

        Requirements:
        1. Generate exactly 5 questions
        2. Each question must have exactly 4 options labeled A, B, C, D
        3. The correctAnswer must be one of: A, B, C, or D
        4. Use simple IDs like q1, q2, q3, etc.
        5. Respond with ONLY the JSON object, no other text
        6. Ensure the JSON is properly formatted and valid
        """
        
        logger.info("Sending request to OpenAI")
        
        // Create the request
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a quiz generator that creates multiple choice questions based on article content.
                    You must ALWAYS respond with ONLY a valid JSON object containing an array of questions.
                    Do not include any other text, markdown, or formatting in your response.
                    Each question must have an id (q1, q2, etc.), a question text, four options (A, B, C, D),
                    one correct answer (A, B, C, or D), and an explanation.
                    """
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 2000,
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw QuizError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            logger.error("OpenAI API error: \(httpResponse.statusCode)")
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                logger.error("OpenAI error details: \(String(describing: errorJson))")
            }
            throw QuizError.networkError(NSError(domain: "OpenAI", code: httpResponse.statusCode))
        }
        
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            logger.info("Raw OpenAI response: \(responseString)")
        }
        
        // Parse the response step by step with logging
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("Failed to parse response as JSON")
            throw QuizError.decodingError
        }
        logger.info("Parsed initial JSON")
        
        guard let choices = json["choices"] as? [[String: Any]] else {
            logger.error("Failed to get choices array. JSON structure: \(json)")
            throw QuizError.decodingError
        }
        logger.info("Found choices array with \(choices.count) items")
        
        guard let firstChoice = choices.first else {
            logger.error("No choices returned")
            throw QuizError.decodingError
        }
        logger.info("Got first choice: \(firstChoice)")
        
        guard let message = firstChoice["message"] as? [String: Any] else {
            logger.error("Failed to get message from choice: \(firstChoice)")
            throw QuizError.decodingError
        }
        logger.info("Got message")
        
        guard let content = message["content"] as? String else {
            logger.error("Failed to get content from message: \(message)")
            throw QuizError.decodingError
        }
        logger.info("Got content: \(content)")
        
        guard let quizData = content.data(using: .utf8) else {
            logger.error("Failed to convert content to data")
            throw QuizError.decodingError
        }
        logger.info("Converted content to data")
        
        guard let quizJson = try? JSONSerialization.jsonObject(with: quizData) as? [String: Any] else {
            logger.error("Failed to parse content as JSON. Content: \(content)")
            throw QuizError.decodingError
        }
        logger.info("Parsed content as JSON")
        
        guard let questions = quizJson["questions"] as? [[String: Any]] else {
            logger.error("Failed to get questions array. Quiz JSON: \(quizJson)")
            throw QuizError.decodingError
        }
        logger.info("Found \(questions.count) questions")
        
        // Convert the questions to our model
        let quizQuestions = try questions.map { questionData -> QuizQuestion in
            guard let id = questionData["id"] as? String,
                  let question = questionData["question"] as? String,
                  let options = questionData["options"] as? [String: String],
                  let correctAnswer = questionData["correctAnswer"] as? String,
                  let explanation = questionData["explanation"] as? String else {
                throw QuizError.decodingError
            }
            
            return QuizQuestion(
                id: id,
                question: question,
                options: options,
                correctAnswer: correctAnswer,
                explanation: explanation
            )
        }
        
        logger.info("Successfully generated \(quizQuestions.count) questions")
        
        // Create the quiz
        return Quiz(
            id: ID.unique(),
            articleId: article.id,
            title: "Quiz: \(article.title)",
            questions: quizQuestions,
            createdAt: Date(),
            articleReferenceId: article.id,
            articleReferenceTitle: article.title,
            articleReferenceThumbnail: article.thumbnailUrl ?? URL(string: "https://placeholder.com/300")!
        )
    }
}