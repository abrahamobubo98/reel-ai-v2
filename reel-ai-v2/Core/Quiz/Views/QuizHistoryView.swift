import SwiftUI
import Appwrite

struct QuizHistoryView: View {
    @StateObject private var viewModel: QuizHistoryViewModel
    
    init(userId: String) {
        let quizService = QuizService(
            databases: Databases(AppwriteService.shared.client),
            databaseId: Config.shared.appwriteDatabaseId
        )
        _viewModel = StateObject(wrappedValue: QuizHistoryViewModel(
            quizService: quizService,
            userId: userId
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                QuizStatisticsCard(
                    totalQuizzes: viewModel.totalAttempted,
                    averageScore: viewModel.averageScore,
                    completionRate: viewModel.completionRate
                )
                .padding(.horizontal)
                
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.quizAttempts.isEmpty {
                    ContentUnavailableView(
                        "No Quiz History",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Complete some quizzes to see your history here.")
                    )
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.quizAttempts) { attempt in
                            QuizHistoryItemView(attempt: attempt)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Quiz History")
        .task {
            await viewModel.loadQuizHistory()
        }
        .refreshable {
            await viewModel.loadQuizHistory()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }
}

#if DEBUG
struct QuizHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            QuizHistoryView(userId: "preview-user")
        }
    }
}
#endif 