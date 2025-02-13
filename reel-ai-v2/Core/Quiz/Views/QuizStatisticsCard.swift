import SwiftUI

struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

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

#if DEBUG
struct QuizStatisticsCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QuizStatisticsCard(
                totalQuizzes: 10,
                averageScore: 85.5,
                completionRate: 90.0
            )
            .padding()
            .previewLayout(.sizeThatFits)
            
            QuizStatisticsCard(
                totalQuizzes: 0,
                averageScore: 0,
                completionRate: 0
            )
            .padding()
            .previewLayout(.sizeThatFits)
        }
    }
}
#endif 