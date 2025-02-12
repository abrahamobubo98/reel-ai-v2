import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var name: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(viewModel: AuthenticationViewModel) {
        self.viewModel = viewModel
        _name = State(initialValue: viewModel.name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Name", text: $name)
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
        
        Task {
            do {
                try await viewModel.updateProfile(name: name)
                await MainActor.run {
                    dismiss()
                }
            } catch {
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