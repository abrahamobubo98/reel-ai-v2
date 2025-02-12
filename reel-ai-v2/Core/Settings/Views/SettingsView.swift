import SwiftUI
import Appwrite

struct SettingsView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var selectedTab = 0
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var showEditProfile = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Header
                ZStack(alignment: .bottomLeading) {
                    // Gray Background
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(height: 150)
                    
                    // Profile Picture
                    Image(systemName: "person.circle.fill") // TODO: Replace with actual profile picture
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .padding(.leading)
                        .padding(.bottom, -40)
                    
                    // Logout Button
                    Button(action: {
                        Task {
                            await viewModel.handleSignOut()
                        }
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .offset(x: UIScreen.main.bounds.width - 60)
                }
                
                // Bio Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.name.isEmpty ? "User" : viewModel.name) // Use dynamic name from viewModel
                        .font(.title2)
                        .bold()
                        .padding(.leading)
                        .padding(.top, 45)
                    
                    // Follower Stats
                    HStack {
                        Spacer()
                            .frame(maxWidth: 30) // Reduced left spacing
                        VStack {
                            Text("1.2K")
                                .font(.headline)
                                .bold()
                            Text("Followers")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                            .frame(maxWidth: 40) // Reduced spacing between stats
                        
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
                    
                    Text("Software developer passionate about creating amazing apps and sharing knowledge with others.") // TODO: Replace with actual bio
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // Profile Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            showEditProfile = true
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        .sheet(isPresented: $showEditProfile) {
                            EditProfileView(viewModel: viewModel)
                        }
                        
                        Button(action: {
                            // Share profile functionality will go here
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Profile")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .padding(.bottom, 8)
                }
                
                // Content Tabs
                VStack(spacing: 0) {
                    // Tab Headers
                    HStack {
                        ForEach(["Posts", "Articles", "Streams", "Classes"], id: \.self) { tab in
                            VStack {
                                Text(tab)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 8)
                                    .foregroundColor(selectedTab == getTabIndex(tab) ? .primary : .gray)
                                
                                Rectangle()
                                    .fill(selectedTab == getTabIndex(tab) ? Color.blue : Color.clear)
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                withAnimation {
                                    selectedTab = getTabIndex(tab)
                                }
                            }
                        }
                    }
                    
                    // Tab Content
                    TabView(selection: $selectedTab) {
                        PostsTabView()
                            .tag(0)
                        
                        ArticlesTabView(viewModel: homeViewModel)
                            .tag(1)
                        
                        StreamsTabView()
                            .tag(2)
                        
                        ClassesTabView()
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: UIScreen.main.bounds.height * 0.5)
                }
            }
        }
    }
    
    private func getTabIndex(_ tab: String) -> Int {
        switch tab {
        case "Posts": return 0
        case "Articles": return 1
        case "Streams": return 2
        case "Classes": return 3
        default: return 0
        }
    }
}

struct StreamsTabView: View {
    var body: some View {
        Text("Streams")
    }
}

struct ClassesTabView: View {
    var body: some View {
        Text("Classes")
    }
} 