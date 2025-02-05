import SwiftUI

// MARK: - Model & ViewModel
struct CreatePostModel {
    var mediaType: MediaType = .photo
    var caption: String = ""
    var isUploading: Bool = false
    
    enum MediaType {
        case photo
        case video
    }
}

@MainActor
class CreatePostViewModel: ObservableObject {
    @Published var model = CreatePostModel()
    @Published var showCamera = false
    @Published var showMediaPicker = false
    
    func handleMediaCapture() {
        showCamera = true
    }
    
    func handleMediaSelection() {
        showMediaPicker = true
    }
}

// MARK: - View
struct CreateView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create")
                .font(.largeTitle)
                .bold()
            
            VStack(spacing: 15) {
                Button(action: {
                    viewModel.handleMediaCapture()
                }) {
                    Label("Take Photo or Video", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    viewModel.handleMediaSelection()
                }) {
                    Label("Choose from Library", systemImage: "photo.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    CreateView()
} 