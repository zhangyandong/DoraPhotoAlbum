import Foundation
import Photos
import UIKit
import AVFoundation

class PhotoService {
    static let shared = PhotoService()
    
    private init() {}
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    func fetchLocalMedia() -> [UnifiedMediaItem] {
        var items: [UnifiedMediaItem] = []
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // Fetch Images and Live Photos (Video is separate type in PHAsset, but we handle it)
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        
        assets.enumerateObjects { (asset, _, _) in
            // Filter only Image and Video
            if asset.mediaType == .image || asset.mediaType == .video {
                items.append(UnifiedMediaItem(asset: asset))
            }
        }
        
        return items
    }
    
    @discardableResult
    func requestImage(for item: UnifiedMediaItem, targetSize: CGSize, contentMode: PHImageContentMode = .aspectFit, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID? {
        // Handle local assets
        if let asset = item.localAsset {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            
            return PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, _ in
                completion(image)
            }
        }
        
        // Handle remote WebDAV URLs
        if let url = item.remoteURL {
            loadImageFromWebDAV(url: url, completion: completion)
            return nil // Return nil for remote requests as there's no PHImageRequestID
        }
        
        completion(nil)
        return nil
    }
    
    private func loadImageFromWebDAV(url: URL, completion: @escaping (UIImage?) -> Void) {
        // Check cache first
        if let cachedImage = ImageCacheService.shared.getCachedImage(for: url) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        // Get WebDAV credentials from UserDefaults
        let defaults = UserDefaults.standard
        guard let host = defaults.string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
              let user = defaults.string(forKey: AppConstants.Keys.kWebDAVUser),
              let pass = defaults.string(forKey: AppConstants.Keys.kWebDAVPassword) else {
            print("PhotoService: No WebDAV credentials found")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        let config = WebDAVConfig(host: host, username: user, password: pass)
        let client = WebDAVClient(config: config)
        let request = client.authenticatedRequest(for: url)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let image = UIImage(data: data) else {
                print("PhotoService: Failed to load image from \(url.absoluteString), error: \(String(describing: error))")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // Cache the image
            ImageCacheService.shared.cacheImage(image, for: url)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }
        task.resume()
    }
    
    func requestPlayerItem(for item: UnifiedMediaItem, completion: @escaping (AVPlayerItem?) -> Void) {
        // Handle local assets
        if let asset = item.localAsset, item.type == .video {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
                completion(playerItem)
            }
            return
        }
        
        // Handle remote WebDAV video URLs
        if let url = item.remoteURL, item.type == .video {
            loadVideoFromWebDAV(url: url, completion: completion)
            return
        }
        
        completion(nil)
    }
    
    private func loadVideoFromWebDAV(url: URL, completion: @escaping (AVPlayerItem?) -> Void) {
        // Check cache first for video
        if let cachedData = ImageCacheService.shared.getCachedData(for: url),
           cachedData.count > 0 {
            // Create a local file URL for cached video
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".mp4")
            
            do {
                try cachedData.write(to: tempFile)
                let playerItem = AVPlayerItem(url: tempFile)
                print("PhotoService: Loading video from cache")
                DispatchQueue.main.async {
                    completion(playerItem)
                }
                return
            } catch {
                print("PhotoService: Failed to write cached video to temp file: \(error)")
            }
        }
        
        // Get WebDAV credentials from UserDefaults
        let defaults = UserDefaults.standard
        guard let host = defaults.string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
              let user = defaults.string(forKey: AppConstants.Keys.kWebDAVUser),
              let pass = defaults.string(forKey: AppConstants.Keys.kWebDAVPassword) else {
            print("PhotoService: No WebDAV credentials found for video")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // For WebDAV video, we need to embed credentials in URL
        // Format: http://user:pass@host/path
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              let hostComponent = components.host else {
            // Fallback: try direct URL
            print("PhotoService: Cannot parse URL components, falling back to direct URL")
            let playerItem = AVPlayerItem(url: url)
            DispatchQueue.main.async {
                completion(playerItem)
            }
            return
        }
        
        var urlString = "\(scheme)://"
        
        // Add credentials if not already in URL
        if components.user == nil {
            // URL encode user and password
            if let encodedUser = user.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed),
               let encodedPass = pass.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) {
                urlString += "\(encodedUser):\(encodedPass)@"
            }
        }
        
        urlString += hostComponent
        if let port = components.port {
            urlString += ":\(port)"
        }
        // path is not optional, it's always a String (may be empty)
        if !components.path.isEmpty {
            urlString += components.path
        }
        if let query = components.query {
            urlString += "?\(query)"
        }
        
        guard let authURL = URL(string: urlString) else {
            // Fallback: try direct URL
            print("PhotoService: Cannot create authenticated URL, falling back to direct URL")
            let playerItem = AVPlayerItem(url: url)
            DispatchQueue.main.async {
                completion(playerItem)
            }
            return
        }
        
        print("PhotoService: Downloading video from WebDAV")
        
        // Download video data
        let config = WebDAVConfig(host: host, username: user, password: pass)
        let client = WebDAVClient(config: config)
        let request = client.authenticatedRequest(for: url)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("PhotoService: Failed to download video: \(String(describing: error))")
                // Fallback to direct URL
                let playerItem = AVPlayerItem(url: authURL)
                DispatchQueue.main.async {
                    completion(playerItem)
                }
                return
            }
            
            // Cache the video data
            ImageCacheService.shared.cacheData(data, for: url)
            
            // Create a local file URL for the video
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".mp4")
            
            do {
                try data.write(to: tempFile)
                let playerItem = AVPlayerItem(url: tempFile)
                print("PhotoService: Video downloaded and cached")
                DispatchQueue.main.async {
                    completion(playerItem)
                }
            } catch {
                print("PhotoService: Failed to write video to temp file: \(error)")
                // Fallback to direct URL
                let playerItem = AVPlayerItem(url: authURL)
                DispatchQueue.main.async {
                    completion(playerItem)
                }
            }
        }
        task.resume()
    }
}

