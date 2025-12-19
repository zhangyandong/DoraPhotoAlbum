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
        DispatchQueue.global(qos: .userInitiated).async {
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
        DispatchQueue.global(qos: .userInitiated).async {
            // Check cache first for video using file URL (avoid memory load)
            if let cachedFileURL = ImageCacheService.shared.getCachedFileURL(for: url) {
                let playerItem = AVPlayerItem(url: cachedFileURL)
                print("PhotoService: Loading video from cache: \(cachedFileURL.lastPathComponent)")
                DispatchQueue.main.async {
                    completion(playerItem)
                }
                return
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
            
            // Create authenticated request
            let config = WebDAVConfig(host: host, username: user, password: pass)
            let client = WebDAVClient(config: config)
            let request = client.authenticatedRequest(for: url)
            
            print("PhotoService: Downloading video from WebDAV")
            
            // Use downloadTask instead of dataTask for memory efficiency
            let task = URLSession.shared.downloadTask(with: request) { localURL, response, error in
                guard let localURL = localURL, error == nil else {
                    print("PhotoService: Failed to download video: \(String(describing: error))")
                    
                    // Fallback to direct URL (streaming) if download fails
                    // Note: This might still fail auth if not embedded in URL, but it's a last resort
                    self.fallbackToDirectURL(url: url, host: host, user: user, pass: pass, completion: completion)
                    return
                }
                
                do {
                    // Move downloaded file to cache
                    try ImageCacheService.shared.moveDownloadedFile(at: localURL, for: url)
                    
                    // Get the final cache URL
                    if let cachedFileURL = ImageCacheService.shared.getCachedFileURL(for: url) {
                        let playerItem = AVPlayerItem(url: cachedFileURL)
                        print("PhotoService: Video downloaded and cached")
                        DispatchQueue.main.async {
                            completion(playerItem)
                        }
                    } else {
                        // This shouldn't happen if move succeeded
                        throw NSError(domain: "PhotoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to locate file after move"])
                    }
                } catch {
                    print("PhotoService: Failed to process downloaded video: \(error)")
                    self.fallbackToDirectURL(url: url, host: host, user: user, pass: pass, completion: completion)
                }
            }
            task.resume()
        }
    }
    
    private func fallbackToDirectURL(url: URL, host: String, user: String, pass: String, completion: @escaping (AVPlayerItem?) -> Void) {
        // Construct authenticated URL for streaming
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              let hostComponent = components.host else {
            DispatchQueue.main.async {
                let playerItem = AVPlayerItem(url: url)
                completion(playerItem)
            }
            return
        }
        
        var urlString = "\(scheme)://"
        
        // Add credentials if not already in URL
        if components.user == nil {
            if let encodedUser = user.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed),
               let encodedPass = pass.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) {
                urlString += "\(encodedUser):\(encodedPass)@"
            }
        }
        
        urlString += hostComponent
        if let port = components.port {
            urlString += ":\(port)"
        }
        if !components.path.isEmpty {
            urlString += components.path
        }
        if let query = components.query {
            urlString += "?\(query)"
        }
        
        if let authURL = URL(string: urlString) {
            print("PhotoService: Falling back to direct streaming URL")
            DispatchQueue.main.async {
                let playerItem = AVPlayerItem(url: authURL)
                completion(playerItem)
            }
        } else {
            DispatchQueue.main.async {
                let playerItem = AVPlayerItem(url: url)
                completion(playerItem)
            }
        }
    }
}
