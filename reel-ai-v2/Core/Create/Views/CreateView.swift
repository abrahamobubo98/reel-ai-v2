import SwiftUI

// MARK: - Model & ViewModel
struct CreatePostModel {
    var mediaType: MediaType = .photo
    var caption: String = ""
    var isUploading: Bool = false
    var uploadProgress: Double = 0
    var error: String?
    var image: UIImage?
    var fileId: String?
    var post: Post?
    var shouldDismiss: Bool = false
    
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
    
    private let appwrite = AppwriteService.shared
    
    func handleMediaCapture() {
        showCamera = true
    }
    
    func handleMediaSelection() {
        showMediaPicker = true
    }
    
    func handleCapturedImage(_ image: UIImage) {
        model.image = image
        model.error = nil
        showImagePreview = true
    }
    
    func clearImage() {
        model.image = nil
        model.error = nil
        model.uploadProgress = 0
        model.isUploading = false
        model.fileId = nil
        model.post = nil
        model.shouldDismiss = false
        showImagePreview = false
    }
    
    func uploadPost() async {
        guard let image = model.image else {
            model.error = "No image selected"
            return
        }
        
        guard !model.caption.isEmpty else {
            model.error = "Please add a caption"
            return
        }
        
        model.isUploading = true
        model.error = nil
        
        do {
            // 1. Upload image
            let fileId = try await appwrite.uploadImage(image) { progress in
                self.model.uploadProgress = progress * 0.7 // Image upload is 70% of total progress
            }
            model.fileId = fileId
            
            // Update progress for database operation
            model.uploadProgress = 0.8
            
            // 2. Create post in database
            let post = try await appwrite.createPost(
                imageId: fileId,
                caption: model.caption
            )
            
            model.post = post
            model.uploadProgress = 1.0
            
            // 3. Reset and dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.model.shouldDismiss = true
                self.clearImage()
            }
            
        } catch let error as StorageError {
            model.error = error.localizedDescription
        } catch let error as DatabaseError {
            model.error = error.localizedDescription
        } catch {
            model.error = "Failed to create post: \(error.localizedDescription)"
        }
        
        model.isUploading = false
    }
}

// MARK: - View
struct CreateView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    
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
                        Button(action: {
                            Task {
                                await viewModel.uploadPost()
                            }
                        }) {
                            if viewModel.model.isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Post")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(viewModel.model.isUploading || viewModel.model.caption.isEmpty)
                    }
                    .padding()
                    
                    if let image = viewModel.model.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                        
                        if viewModel.model.isUploading {
                            ProgressView(value: viewModel.model.uploadProgress) {
                                Text("Creating post... \(Int(viewModel.model.uploadProgress * 100))%")
                                    .font(.caption)
                            }
                            .progressViewStyle(.linear)
                            .padding()
                        }
                        
                        if let error = viewModel.model.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding()
                        }
                        
                        TextField("Add a caption...", text: $viewModel.model.caption)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                            .disabled(viewModel.model.isUploading)
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
        .onChange(of: viewModel.model.shouldDismiss) { shouldDismiss in
            if shouldDismiss {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

#Preview {
    CreateView()
} 