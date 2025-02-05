import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    
    var body: some View {
        TabView {
            // Home Tab
            VStack(spacing: 20) {
                Text("Hello, \(viewModel.username)")
                    .font(.largeTitle)
                    .bold()
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
            VStack(spacing: 20) {
                Text("Create")
                    .font(.largeTitle)
                    .bold()
            }
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
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.largeTitle)
                    .bold()
                
                Button(action: {
                    Task {
                        await viewModel.handleSignOut()
                    }
                }) {
                    Text("Sign out")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
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