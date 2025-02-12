import UIKit

class MediaCache {
    static let shared = MediaCache()
    private let imageCache = NSCache<NSString, UIImage>()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    private init() {
        // Set cache limits (adjust these based on your app's memory requirements)
        imageCache.countLimit = 100  // Maximum number of images
        imageCache.totalCostLimit = 1024 * 1024 * 100  // 100 MB
        
        thumbnailCache.countLimit = 200  // Maximum number of thumbnails
        thumbnailCache.totalCostLimit = 1024 * 1024 * 50  // 50 MB
    }
    
    func cacheImage(_ image: UIImage, forKey key: String, isThumbnail: Bool = false) {
        let cache = isThumbnail ? thumbnailCache : imageCache
        cache.setObject(image, forKey: key as NSString)
    }
    
    func getImage(forKey key: String, isThumbnail: Bool = false) -> UIImage? {
        let cache = isThumbnail ? thumbnailCache : imageCache
        return cache.object(forKey: key as NSString)
    }
    
    func clearCache() {
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }
} 