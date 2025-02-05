import Foundation

enum AuthenticationState {
    case signIn
    case signUp
}

struct AuthenticationModel {
    var email: String = ""
    var username: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var authState: AuthenticationState = .signIn
    
    // Validation states
    var isEmailValid: Bool = true
    var isUsernameValid: Bool = true
    var isPasswordValid: Bool = true
    var isPasswordMatching: Bool = true
    
    // Error messages
    var emailErrorMessage: String = ""
    var usernameErrorMessage: String = ""
    var passwordErrorMessage: String = ""
    var confirmPasswordErrorMessage: String = ""
} 