import Foundation
import UIKit

class ImageCacheService {
    static let shared = ImageCacheService()
    
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let memoryCache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "com.ipadphotoalbum.imagecache", attributes: .concurrent)
    
    // Default max cache size: 2GB
    var maxCacheSize: Int64 {
        get {
            let defaults = UserDefaults.standard
            if let value = defaults.object(forKey: AppConstants.Keys.kCacheMaxSize) as? NSNumber {
                return value.int64Value
            }
            return 2 * 1024 * 1024 * 1024 // 2GB default
        }
        set {
            UserDefaults.standard.set(NSNumber(value: newValue), forKey: AppConstants.Keys.kCacheMaxSize)
        }
    }
    
    private init() {
        // Create cache directory in Caches folder
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDir.appendingPathComponent("WebDAVCache", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Configure memory cache
        memoryCache.countLimit = 50 // Limit to 50 images in memory
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        
        // Clean cache on init if needed
        queue.async {
            self.cleanCacheIfNeeded()
        }
    }
    
    // Generate cache key from URL
    private func cacheKey(for url: URL) -> String {
        // Use URL's absolute string as key, but sanitize it for filesystem
        let key = url.absoluteString
        // Replace invalid filename characters
        let invalidChars = CharacterSet(charactersIn: "/:?#[]@!$&'()*+,;=")
        return key.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    // Get cache file path for URL
    private func cacheFilePath(for url: URL) -> URL {
        let key = cacheKey(for: url)
        return cacheDirectory.appendingPathComponent(key)
    }
    
    // Check if cached file exists
    func hasCachedImage(for url: URL) -> Bool {
        let filePath = cacheFilePath(for: url)
        return fileManager.fileExists(atPath: filePath.path)
    }
    
    // Get cached file URL if it exists
    func getCachedFileURL(for url: URL) -> URL? {
        let filePath = cacheFilePath(for: url)
        return fileManager.fileExists(atPath: filePath.path) ? filePath : nil
    }

    // Move downloaded file to cache
    func moveDownloadedFile(at tempURL: URL, for url: URL) throws {
        let destinationURL = cacheFilePath(for: url)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)
        
        // Touch file for LRU (treat as recently used)
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: destinationURL.path)
        
        // Check and clean cache asynchronously
        queue.async {
            self.cleanCacheIfNeeded()
        }
    }
    
    // Get cached image
    func getCachedImage(for url: URL) -> UIImage? {
        // First check memory cache
        let key = cacheKey(for: url)
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            return cachedImage
        }
        
        // Then check disk cache
        let filePath = cacheFilePath(for: url)
        guard fileManager.fileExists(atPath: filePath.path),
              let data = try? Data(contentsOf: filePath),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Touch file to keep LRU (update modification date on read)
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: filePath.path)
        
        // Store in memory cache for faster access
        // NSCache will automatically evict objects when limits are reached
        memoryCache.setObject(image, forKey: key as NSString)
        return image
    }
    
    // Save image to cache
    func cacheImage(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        let filePath = cacheFilePath(for: url)
        
        // Save to memory cache
        memoryCache.setObject(image, forKey: key as NSString)
        
        // Save to disk cache on background queue
        queue.async {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                do {
                    try imageData.write(to: filePath)
                    // Always enforce cache limit (rolling delete when exceeded)
                    self.cleanCacheIfNeeded()
                } catch {
                    print("ImageCacheService: Failed to cache image for \(url.absoluteString): \(error)")
                }
            }
        }
    }
    
    // Get cached image data (for video or raw data)
    func getCachedData(for url: URL) -> Data? {
        let filePath = cacheFilePath(for: url)
        guard fileManager.fileExists(atPath: filePath.path) else {
            return nil
        }
        return try? Data(contentsOf: filePath)
    }
    
    // Save data to cache (for videos or other large files)
    func cacheData(_ data: Data, for url: URL) {
        let filePath = cacheFilePath(for: url)
        queue.async {
            do {
                try data.write(to: filePath)
                // Check and clean cache after saving large file
                self.cleanCacheIfNeeded()
            } catch {
                print("ImageCacheService: Failed to cache data for \(url.absoluteString): \(error)")
            }
        }
    }
    
    // Clean cache if it exceeds max size (LRU strategy)
    private func cleanCacheIfNeeded() {
        let currentSize = getCacheSizeSync()
        
        if currentSize <= maxCacheSize {
            return // Cache size is within limit
        }
        
        print("ImageCacheService: Cache size (\(formatBytes(currentSize))) exceeds limit (\(formatBytes(maxCacheSize))), cleaning...")
        
        // Get all cache files with their modification dates and sizes
        var files: [(url: URL, date: Date, size: Int64)] = []
        
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                   let fileSize = attributes.fileSize,
                   let modDate = attributes.contentModificationDate {
                    files.append((fileURL, modDate, Int64(fileSize)))
                }
            }
        }
        
        // Sort by modification date (oldest first - LRU)
        files.sort { $0.date < $1.date }
        
        // Delete oldest files until we're under the limit
        var deletedSize: Int64 = 0
        let targetSize = maxCacheSize * 9 / 10 // Clean to 90% of max size
        
        for file in files {
            if currentSize - deletedSize <= targetSize {
                break
            }
            
            do {
                try fileManager.removeItem(at: file.url)
                deletedSize += file.size
            } catch {
                print("ImageCacheService: Failed to delete cache file \(file.url.lastPathComponent): \(error)")
            }
        }
        
        print("ImageCacheService: Cleaned \(formatBytes(deletedSize)) from cache")
    }
    
    // Synchronous version of getCacheSize for internal use
    private func getCacheSizeSync() -> Int64 {
        var size: Int64 = 0
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = attributes.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }
    
    // Format bytes to human readable string
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // Clear memory cache only (keeps disk cache)
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    // Clear cache (optional method)
    func clearCache() {
        memoryCache.removeAllObjects()
        queue.async {
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    /// Force an async eviction pass based on current `maxCacheSize`.
    func enforceCacheLimitAsync() {
        queue.async {
            self.cleanCacheIfNeeded()
        }
    }
    
    // Get cache size
    func getCacheSize() -> Int64 {
        var size: Int64 = 0
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = attributes.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }
}

