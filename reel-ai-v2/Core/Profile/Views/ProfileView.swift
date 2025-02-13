import SwiftUI
import Appwrite

struct ProfileView: View {
    let userId: String
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Header
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(height: 150)
                    
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .padding(.leading)
                        .padding(.bottom, -40)
                }
                
                // Bio Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.name)
                        .font(.title2)
                        .bold()
                        .padding(.leading)
                        .padding(.top, 45)
                    
                    // Follower Stats
                    HStack {
                        Spacer()
                            .frame(maxWidth: 30)
                        VStack {
                            Text("1.2K")
                                .font(.headline)
                                .bold()
                            Text("Followers")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                            .frame(maxWidth: 40)
                        
                        VStack {
                            Text("850")
                                .font(.headline)
                                .bold()
                            Text("Following")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    if !viewModel.bio.isEmpty {
                        Text(viewModel.bio)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                }
                
                // Content Tabs
                VStack(spacing: 0) {
                    // Tab Headers
                    HStack {
                        ForEach(["Posts", "Articles"], id: \.self) { tab in
                            VStack {
                                Text(tab)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 8)
                                    .foregroundColor(viewModel.selectedTab == getTabIndex(tab) ? .primary : .gray)
                                
                                Rectangle()
                                    .fill(viewModel.selectedTab == getTabIndex(tab) ? Color.blue : Color.clear)
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                withAnimation {
                                    viewModel.selectedTab = getTabIndex(tab)
                                }
                            }
                        }
                    }
                    
                    // Tab Content
                    TabView(selection: $viewModel.selectedTab) {
                        // Posts Tab
                        LazyVGrid(columns: viewModel.columns, spacing: 1) {
                            ForEach(viewModel.posts, id: \.id) { post in
                                PostThumbnailView(post: post)
                                    .id(post.id)
                            }
                        }
                        .tag(0)
                        
                        // Articles Tab
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.articles) { article in
                                ArticlePreviewView(article: article)
                                    .padding(.horizontal)
                            }
                        }
                        .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: UIScreen.main.bounds.height * 0.5)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(userId: userId)
        }
        .refreshable {
            await viewModel.loadProfile(userId: userId)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
    
    private func getTabIndex(_ tab: String) -> Int {
        switch tab {
        case "Posts": return 0
        case "Articles": return 1
        default: return 0
        }
    }
} 