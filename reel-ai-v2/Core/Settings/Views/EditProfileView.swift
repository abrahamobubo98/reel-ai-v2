import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var name: String
    @State private var bio: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(viewModel: AuthenticationViewModel) {
        self.viewModel = viewModel
        _name = State(initialValue: viewModel.name)
        _bio = State(initialValue: viewModel.model.bio)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        Text("Display Name")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        TextField("Enter your name", text: $name)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Bio")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        TextEditor(text: $bio)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .padding(.vertical, 4)
                    }
                } header: {
                    Text("Profile Information")
                } footer: {
                    Text("Your name will be visible to other users")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private func saveProfile() {
        isLoading = true
        errorMessage = nil
        
        print("📱 Starting profile save - Name: \(name), Bio: \(bio)")
        
        Task {
            do {
                print("📱 Calling updateProfile...")
                try await viewModel.updateProfile(name: name, bio: bio)
                print("📱 Profile update successful")
                
                await MainActor.run {
                    print("📱 Dismissing EditProfileView")
                    dismiss()
                }
            } catch {
                print("❌ Profile save failed - Error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
} 