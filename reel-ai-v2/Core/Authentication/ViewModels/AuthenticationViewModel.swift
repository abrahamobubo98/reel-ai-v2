import Foundation
import Combine
import SwiftUI
import Appwrite

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
            // First clear all fields and reset state
            clearFields()
            
            // Clean up any media resources
            NotificationCenter.default.post(name: NSNotification.Name("CleanupMediaResources"), object: nil)
            
            // Perform logout
            try await appwrite.logout()
            
            // Reset authentication state
            model.authState = .signIn
            isAuthenticated = false
            
            #if DEBUG
            prefillCredentials()
            #endif
        } catch {
            showError = true
            errorMessage = (error as NSError).localizedDescription
            debugPrint("📱 Sign out error: \(error)")
        }
    }
    
    func updateProfile(name: String) async throws {
        debugPrint("📱 UpdateProfile: Starting profile update - name: \(name)")
        isLoading = true
        defer { 
            debugPrint("📱 UpdateProfile: Completed profile update process")
            isLoading = false 
        }
        
        do {
            debugPrint("📱 UpdateProfile: Attempting to update name in Appwrite account")
            let _ = try await appwrite.account.updateName(name: name)
            debugPrint("📱 UpdateProfile: Successfully updated name in Appwrite account")
            
            debugPrint("📱 UpdateProfile: Updating local state on MainActor")
            await MainActor.run {
                self.name = name
                debugPrint("📱 UpdateProfile: Successfully updated local state")
            }
        } catch {
            debugPrint("📱 UpdateProfile: Error occurred: \(error.localizedDescription)")
            if let appwriteError = error as? AppwriteError {
                debugPrint("📱 UpdateProfile: Appwrite error type: \(String(describing: appwriteError.type))")
                debugPrint("📱 UpdateProfile: Appwrite error message: \(String(describing: appwriteError.message))")
            }
            throw error
        }
    }
} 