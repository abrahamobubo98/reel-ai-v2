import SwiftUI

struct ArticlesTabView: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if viewModel.articles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No articles yet")
                        .font(.headline)
                    Text("Be the first to write an article!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.articles) { article in
                        ArticlePreviewView(article: article)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .refreshable {
            await viewModel.loadArticles()
        }
        .task {
            await viewModel.loadArticles()
        }
    }
} 