import SwiftUI

struct QuizProgressView: View {
    let progress: Double
    let currentQuestion: Int
    let totalQuestions: Int
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .foregroundColor(.blue)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)
            
            Text("Question \(currentQuestion) of \(totalQuestions)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct QuizProgressView_Previews: PreviewProvider {
    static var previews: some View {
        QuizProgressView(
            progress: 0.5,
            currentQuestion: 5,
            totalQuestions: 10
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
} 