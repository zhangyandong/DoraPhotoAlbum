import CoreLocation
import Photos

enum MediaType {
    case image
    case video
    case livePhoto
}

struct UnifiedMediaItem {
    let id: String
    let type: MediaType
    let creationDate: Date?
    
    // Local Asset
    let localAsset: PHAsset?
    
    // Remote/WebDAV Resource
    let remoteURL: URL?
    
    // Metadata
    var locationName: String?
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.localAsset = asset
        self.remoteURL = nil
        self.creationDate = asset.creationDate
        
        switch asset.mediaType {
        case .image:
            if asset.mediaSubtypes.contains(.photoLive) {
                self.type = .livePhoto
            } else {
                self.type = .image
            }
        case .video:
            self.type = .video
        default:
            self.type = .image
        }
    }
    
    init(url: URL, type: MediaType, date: Date?) {
        self.id = url.absoluteString
        self.localAsset = nil
        self.remoteURL = url
        self.type = type
        self.creationDate = date
    }
}
