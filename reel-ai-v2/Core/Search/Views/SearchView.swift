import SwiftUI
import Appwrite

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Categories
                Picker("Search Category", selection: $viewModel.selectedCategory) {
                    Text("All").tag(SearchCategory.all)
                    Text("Users").tag(SearchCategory.users)
                    Text("Articles").tag(SearchCategory.articles)
                    Text("Posts").tag(SearchCategory.posts)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Search Results
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if let error = viewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                        } else {
                            // Show results based on selected category
                            switch viewModel.selectedCategory {
                            case .users:
                                if !viewModel.users.isEmpty {
                                    ForEach(viewModel.users, id: \.id) { user in
                                        NavigationLink(destination: ProfileView(userId: user.id)) {
                                            UserSearchResultView(user: user)
                                        }
                                    }
                                }
                                
                            case .articles:
                                if !viewModel.articles.isEmpty {
                                    ForEach(viewModel.articles) { article in
                                        NavigationLink(destination: ArticleDetailView(article: article)) {
                                            ArticlePreviewView(article: article)
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                
                            case .posts:
                                if !viewModel.posts.isEmpty {
                                    ForEach(viewModel.posts, id: \.id) { post in
                                        PostSearchResultView(post: post)
                                            .padding(.horizontal)
                                    }
                                }
                                
                            case .all:
                                if !viewModel.users.isEmpty {
                                    Section(header: Text("Users").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)) {
                                        ForEach(viewModel.users, id: \.id) { user in
                                            NavigationLink(destination: ProfileView(userId: user.id)) {
                                                UserSearchResultView(user: user)
                                            }
                                        }
                                    }
                                }
                                
                                if !viewModel.articles.isEmpty {
                                    Section(header: Text("Articles").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)) {
                                        ForEach(viewModel.articles) { article in
                                            NavigationLink(destination: ArticleDetailView(article: article)) {
                                                ArticlePreviewView(article: article)
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                                
                                if !viewModel.posts.isEmpty {
                                    Section(header: Text("Posts").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)) {
                                        ForEach(viewModel.posts, id: \.id) { post in
                                            PostSearchResultView(post: post)
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                                
                                if viewModel.users.isEmpty && viewModel.articles.isEmpty && viewModel.posts.isEmpty && !viewModel.searchText.isEmpty {
                                    ContentUnavailableView(
                                        "No Results",
                                        systemImage: "magnifyingglass",
                                        description: Text("Try searching for something else")
                                    )
                                    .padding()
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search...")
            .onChange(of: viewModel.searchText) { oldValue, newValue in
                Task {
                    await viewModel.search()
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct UserSearchResultView: View {
    let user: UserInfo
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct PostSearchResultView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author info
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.subheadline)
                Text(post.author)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Caption
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.body)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
} 