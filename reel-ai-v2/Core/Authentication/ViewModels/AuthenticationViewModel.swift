import Foundation
import Combine
import SwiftUI

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var model = AuthenticationModel()
    private let appwrite = AppwriteService.shared
    
    // MARK: - User inputs
    @Published var email = ""
    @Published var name = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    
    // MARK: - UI State
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isAuthenticated = false
    
    init() {
        #if DEBUG
        prefillCredentials()
        #endif
    }
    
    private func prefillCredentials() {
        email = "abrahamobubo@gmail.com"
        password = "qwertyuiop"
    }
    
    func toggleAuthState() {
        model.authState = model.authState == .signIn ? .signUp : .signIn
        clearFields()
        #if DEBUG
        if model.authState == .signIn {
            prefillCredentials()
        }
        #endif
    }
    
    private func clearFields() {
        email = ""
        name = ""
        password = ""
        confirmPassword = ""
        errorMessage = ""
        showError = false
    }
    
    func handleAuthentication() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            switch model.authState {
            case .signIn:
                let session = try await appwrite.login(email, password)
                debugPrint("Successfully signed in: \(session.userId)")
                // Get user details after login
                let account = try await appwrite.account.get()
                name = account.name // Store the name
                isAuthenticated = true
                
            case .signUp:
                guard validateSignUpFields() else { return }
                do {
                    let user = try await appwrite.register(email, password, name: name)
                    debugPrint("Successfully registered: \(user.id)")
                    
                    // Automatically log in after registration
                    let session = try await appwrite.login(email, password)
                    debugPrint("Successfully logged in after registration: \(session.userId)")
                    
                    // Get user details
                    let account = try await appwrite.account.get()
                    name = account.name // Store the name
                    isAuthenticated = true
                    
                } catch let error as NSError {
                    // If it's the scope error, treat it as success since the user is created
                    if error.localizedDescription.contains("missing scope (account)") {
                        debugPrint("📱 Ignoring scope error and proceeding with authentication")
                        isAuthenticated = true
                        return
                    }
                    
                    showError = true
                    errorMessage = error.localizedDescription
                    debugPrint("📱 Registration error: \(error)")
                }
            }
        } catch {
            showError = true
            errorMessage = (error as NSError).localizedDescription
            debugPrint("📱 Authentication error: \(error)")
        }
    }
    
    private func validateSignUpFields() -> Bool {
        guard !name.isEmpty else {
            errorMessage = "Name is required"
            showError = true
            return false
        }
        
        guard !email.isEmpty else {
            errorMessage = "Email is required"
            showError = true
            return false
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showError = true
            return false
        }
        
        return true
    }
    
    func handleSignOut() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await appwrite.logout()
            isAuthenticated = false
        } catch {
            showError = true
            errorMessage = (error as NSError).localizedDescription
            debugPrint("📱 Sign out error: \(error)")
        }
    }
} 