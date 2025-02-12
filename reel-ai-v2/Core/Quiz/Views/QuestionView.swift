import SwiftUI

struct QuestionView: View {
    let question: QuizQuestion
    let selectedAnswer: String?
    let onAnswerSelected: (String) -> Void
    let questionNumber: Int
    
    @Namespace private var animation
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Question header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Question \(questionNumber)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(question.question)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Answer options
                VStack(spacing: 16) {
                    ForEach(Array(question.options.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        AnswerOptionButton(
                            optionLabel: key,
                            text: value,
                            isSelected: selectedAnswer == key,
                            namespace: animation,
                            onTap: { onAnswerSelected(key) }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct AnswerOptionButton: View {
    let optionLabel: String
    let text: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Option label (A, B, C, D)
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Text(optionLabel)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .blue)
                }
                .matchedGeometryEffect(id: "circle_\(optionLabel)", in: namespace)
                
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .matchedGeometryEffect(id: "checkmark_\(optionLabel)", in: namespace)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

#if DEBUG
struct QuestionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            QuestionView(
                question: QuizQuestion(
                    id: "1",
                    question: "What is the capital of France? This is a longer question to test multiline behavior and wrapping of text.",
                    options: [
                        "A": "London",
                        "B": "Paris",
                        "C": "Berlin",
                        "D": "Madrid"
                    ],
                    correctAnswer: "B",
                    explanation: "Paris is the capital of France"
                ),
                selectedAnswer: "B",
                onAnswerSelected: { _ in },
                questionNumber: 1
            )
            .previewDisplayName("Light Mode")
            
            // Dark mode preview
            QuestionView(
                question: QuizQuestion(
                    id: "1",
                    question: "What is the capital of France?",
                    options: [
                        "A": "London",
                        "B": "Paris",
                        "C": "Berlin",
                        "D": "Madrid"
                    ],
                    correctAnswer: "B",
                    explanation: "Paris is the capital of France"
                ),
                selectedAnswer: nil,
                onAnswerSelected: { _ in },
                questionNumber: 1
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif 