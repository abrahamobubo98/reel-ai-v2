import SwiftUI
import AVKit
import Appwrite

struct HomeView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var selectedFeed: FeedType = .posts
    
    enum FeedType {
        case posts
        case articles
    }
    
    var body: some View {
        TabView {
            // Home Tab
            VStack(spacing: 0) {
                // Feed Toggle
                HStack {
                    Picker("Feed Type", selection: $selectedFeed) {
                        Text("Posts").tag(FeedType.posts)
                        Text("Articles").tag(FeedType.articles)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // Content
                ScrollView {
                    if selectedFeed == .posts {
                        if homeViewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if let error = homeViewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                        } else if homeViewModel.posts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("No posts yet")
                                    .font(.headline)
                                Text("Be the first to share something!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 20) {
                                ForEach(homeViewModel.posts, id: \.id) { post in
                                    PostView(post: post)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                    } else {
                        // Articles View
                        if homeViewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if let error = homeViewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                        } else if homeViewModel.articles.isEmpty {
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
                                ForEach(homeViewModel.articles) { article in
                                    ArticlePreviewView(article: article)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
                .refreshable {
                    if selectedFeed == .posts {
                        homeViewModel.loadPosts()
                    } else {
                        Task {
                            await homeViewModel.loadArticles()
                        }
                    }
                }
            }
            .onChange(of: selectedFeed) { oldValue, newValue in
                if newValue == .posts {
                    homeViewModel.loadPosts()
                } else {
                    Task {
                        await homeViewModel.loadArticles()
                    }
                }
            }
            .onAppear {
                if selectedFeed == .posts {
                    homeViewModel.loadPosts()
                } else {
                    Task {
                        await homeViewModel.loadArticles()
                    }
                }
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            
            // Search Tab
            VStack(spacing: 20) {
                Text("Search")
                    .font(.largeTitle)
                    .bold()
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            
            // Create Tab
            CreateView()
                .tabItem {
                    Image(systemName: "plus.square.fill")
                    Text("Create")
                }
            
            // Notifications Tab
            VStack(spacing: 20) {
                Text("Notifications")
                    .font(.largeTitle)
                    .bold()
            }
            .tabItem {
                Image(systemName: "bell.fill")
                Text("Notifications")
            }
            
            // Settings Tab
            SettingsView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

#Preview {
    let viewModel = AuthenticationViewModel()
    return HomeView(viewModel: viewModel)
} 