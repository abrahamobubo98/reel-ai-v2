import SwiftUI

struct QuizResultView: View {
    let score: Int
    let totalQuestions: Int
    let onDismiss: () -> Void
    let onRetry: () -> Void
    
    private var percentage: Double {
        Double(score) / Double(totalQuestions) * 100
    }
    
    private var resultMessage: String {
        switch percentage {
        case 90...100:
            return "Excellent! You're a master!"
        case 70..<90:
            return "Great job! Keep it up!"
        case 50..<70:
            return "Good effort! Room for improvement."
        default:
            return "Keep practicing! You'll get better."
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: percentage >= 70 ? "star.circle.fill" : "star.circle")
                .font(.system(size: 80))
                .foregroundColor(percentage >= 70 ? .yellow : .gray)
                .padding()
            
            Text("Quiz Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                Text("Your Score")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("\(score) / \(totalQuestions)")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text(String(format: "%.1f%%", percentage))
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Text(resultMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            
            VStack(spacing: 16) {
                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: onDismiss) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct QuizResultView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QuizResultView(
                score: 8,
                totalQuestions: 10,
                onDismiss: {},
                onRetry: {}
            )
            
            QuizResultView(
                score: 4,
                totalQuestions: 10,
                onDismiss: {},
                onRetry: {}
            )
        }
    }
} 