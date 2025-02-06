import SwiftUI
import PhotosUI

struct MediaPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImageSelected: ((UIImage) -> Void)?
    let onVideoSelected: ((URL) -> Void)?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = PHPickerFilter.any(of: [PHPickerFilter.images, PHPickerFilter.videos])
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MediaPickerView
        
        init(_ parent: MediaPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.dismiss()
                return
            }
            
            // Handle image selection
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    if let error = error {
                        print("📱 Error loading image: \(error)")
                        return
                    }
                    
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            self?.parent.onImageSelected?(image)
                            self?.parent.dismiss()
                        }
                    }
                }
            }
            // Handle video selection
            else if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    if let error = error {
                        print("📱 Error loading video: \(error)")
                        return
                    }
                    
                    guard let url = url else { return }
                    
                    // Create a local copy of the video in the temporary directory
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mov")
                    
                    do {
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        DispatchQueue.main.async {
                            self?.parent.onVideoSelected?(tempURL)
                            self?.parent.dismiss()
                        }
                    } catch {
                        print("📱 Error copying video file: \(error)")
                    }
                }
            }
        }
    }
}

#Preview {
    MediaPickerView(
        onImageSelected: { _ in },
        onVideoSelected: { _ in }
    )
} 