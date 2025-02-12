import SwiftUI

struct PostsTabView: View {
    @StateObject private var viewModel = UserPostsViewModel()
    let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
    private let appwrite = AppwriteService.shared
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(viewModel.posts, id: \.id) { post in
                        PostThumbnailView(post: post)
                            .id(post.id) // Add explicit id to help SwiftUI with view identity
                    }
                }
            }
        }
        .task {
            print("📱 PostsTabView: Loading user posts")
            await viewModel.loadUserPosts()
        }
        .onAppear {
            print("📱 PostsTabView: View appeared")
            print("📱 PostsTabView: Current posts count: \(viewModel.posts.count)")
        }
        .onDisappear {
            print("📱 PostsTabView: View disappeared")
        }
    }
} 