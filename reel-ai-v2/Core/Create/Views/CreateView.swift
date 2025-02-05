import SwiftUI

// MARK: - Model & ViewModel
struct CreatePostModel {
    var mediaType: MediaType = .photo
    var caption: String = ""
    var isUploading: Bool = false
    var image: UIImage?
    
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
    @Published var showImagePreview = false
    
    func handleMediaCapture() {
        showCamera = true
    }
    
    func handleMediaSelection() {
        showMediaPicker = true
    }
    
    func handleCapturedImage(_ image: UIImage) {
        model.image = image
        showImagePreview = true
    }
    
    func clearImage() {
        model.image = nil
        showImagePreview = false
    }
}

// MARK: - View
struct CreateView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.showImagePreview {
                VStack {
                    HStack {
                        Button(action: {
                            viewModel.clearImage()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Button("Post") {
                            // TODO: Implement post functionality
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    
                    if let image = viewModel.model.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                        
                        TextField("Add a caption...", text: .constant(""))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                    }
                }
            } else {
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
        }
        .padding()
        .sheet(isPresented: $viewModel.showCamera) {
            CameraView { image in
                viewModel.handleCapturedImage(image)
            }
        }
    }
}

#Preview {
    CreateView()
} 