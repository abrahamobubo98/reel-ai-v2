import SwiftUI

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 12) // Increased vertical padding
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    
    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                HomeView(viewModel: viewModel)
            } else {
                VStack(spacing: 20) {
                    // Header
                    Text(viewModel.model.authState == .signIn ? "Sign In" : "Sign Up")
                        .font(.largeTitle)
                        .bold()
                    
                    // Form Fields
                    VStack(spacing: 15) {
                        if viewModel.model.authState == .signUp {
                            // Username field (only for sign up)
                            TextField("Username", text: $viewModel.username)
                                .textFieldStyle(CustomTextFieldStyle())
                                .autocapitalization(.none)
                        }
                        
                        // Email field
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        // Password field
                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(CustomTextFieldStyle())
                        
                        if viewModel.model.authState == .signUp {
                            // Confirm Password field (only for sign up)
                            SecureField("Confirm Password", text: $viewModel.confirmPassword)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if viewModel.showError {
                        Text(viewModel.errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    // Submit Button
                    Button(action: {
                        Task {
                            await viewModel.handleAuthentication()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(viewModel.model.authState == .signIn ? "Sign In" : "Sign Up")
                                .bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Toggle Button
                    Button(action: {
                        viewModel.toggleAuthState()
                    }) {
                        Text(viewModel.model.authState == .signIn ? 
                             "Don't have an account? Sign Up" : 
                             "Already have an account? Sign In")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    AuthenticationView()
} 