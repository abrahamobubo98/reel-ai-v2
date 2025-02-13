import SwiftUI

struct QuizHistoryItemView: View {
    let attempt: QuizAttempt
    
    private var scoreColor: Color {
        let percentage = Double(attempt.score) / Double(attempt.totalQuestions) * 100
        switch percentage {
        case 80...100:
            return .green
        case 60..<80:
            return .yellow
        default:
            return .red
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: attempt.completedAt)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quiz Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(attempt.score)/\(attempt.totalQuestions)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.1f%%", attempt.scorePercentage))
                        .font(.headline)
                        .foregroundColor(scoreColor)
                }
            }
            
            Divider()
        }
        .padding(.vertical, 8)
    }
}

#if DEBUG
struct QuizHistoryItemView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            QuizHistoryItemView(attempt: QuizAttempt(
                id: "preview",
                userId: "user",
                quizId: "quiz",
                articleId: "article",
                score: 8,
                totalQuestions: 10,
                answers: [:],
                completedAt: Date()
            ))
            
            QuizHistoryItemView(attempt: QuizAttempt(
                id: "preview2",
                userId: "user",
                quizId: "quiz",
                articleId: "article",
                score: 5,
                totalQuestions: 10,
                answers: [:],
                completedAt: Date().addingTimeInterval(-86400)
            ))
        }
        .listStyle(.inset)
    }
}
#endif 