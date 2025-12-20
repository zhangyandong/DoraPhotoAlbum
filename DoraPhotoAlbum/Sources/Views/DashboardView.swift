import UIKit
import CoreLocation
import Photos
import AVFoundation

class DashboardView: UIView {
    
    private let fileTypeLabel = UILabel()
    private let metaLabel = UILabel()
    
    private var timer: Timer?
    private var currentGeocodingTask: CLGeocoder?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        startAntiBurnIn()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Blur background for readability
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        addSubview(blurView)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15)
        ])
        
        // Time: 12:45 removed
        // Date: Mon, 12 Dec removed
        
        // File Type
        fileTypeLabel.font = UIFont.systemFont(ofSize: 12)
        fileTypeLabel.textColor = UIColor(white: 0.9, alpha: 1)
        fileTypeLabel.isHidden = true
        stack.addArrangedSubview(fileTypeLabel)
        
        // Photo Meta (Hidden by default)
        metaLabel.font = UIFont.systemFont(ofSize: 12)
        metaLabel.textColor = UIColor(white: 0.9, alpha: 1)
        metaLabel.numberOfLines = 0 // Allow unlimited lines
        metaLabel.lineBreakMode = .byWordWrapping
        metaLabel.adjustsFontSizeToFitWidth = false
        metaLabel.isHidden = true
        stack.addArrangedSubview(metaLabel)
    }
    
    private func startAntiBurnIn() {
        // Prevent Burn-in: Randomly shift position slightly every min
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.shiftPosition()
        }
    }
    
    func updatePhotoMeta(_ item: UnifiedMediaItem) {
        // Cancel any ongoing geocoding task
        currentGeocodingTask?.cancelGeocode()
        currentGeocodingTask = nil
        
        // Update file type label immediately (without size/duration)
        // Size and duration will be updated asynchronously
        updateFileTypeLabel(type: item.type, fileSize: nil, videoDuration: nil)
        
        // Get file size and video duration asynchronously to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var fileSize: Int64? = nil
            var videoDuration: TimeInterval? = nil
            
            if let asset = item.localAsset {
                // Local asset: get file size from asset resources
                let resources = PHAssetResource.assetResources(for: asset)
                for resource in resources {
                    // Get the primary resource (original file)
                    if resource.type == .photo || resource.type == .video || resource.type == .fullSizePhoto || resource.type == .fullSizeVideo {
                        if let sizeValue = resource.value(forKey: "fileSize") as? NSNumber {
                            fileSize = sizeValue.int64Value
                            break
                        }
                    }
                }
                
                // Get video duration for local assets
                if item.type == .video {
                    videoDuration = asset.duration
                }
            } else if let url = item.remoteURL {
                // WebDAV remote file: check if cached locally
                if let cachedFileURL = ImageCacheService.shared.getCachedFileURL(for: url) {
                    // File is cached, get size from cached file
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: cachedFileURL.path),
                       let size = attributes[.size] as? Int64 {
                        fileSize = size
                    }
                    
                    // Get video duration from cached file if it's a video
                    if item.type == .video {
                        let asset = AVAsset(url: cachedFileURL)
                        videoDuration = CMTimeGetSeconds(asset.duration)
                        // Check if duration is valid (not NaN or invalid)
                        if videoDuration?.isNaN == true || videoDuration?.isInfinite == true {
                            videoDuration = nil
                        }
                    }
                }
                // For uncached remote URLs, skip to avoid network overhead
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self?.updateFileTypeLabel(type: item.type, fileSize: fileSize, videoDuration: videoDuration)
            }
        }
        
        // Get location name
        var locName: String? = item.locationName
        
        // If no location name but we have a local asset with location, geocode it
        if let asset = item.localAsset, let loc = asset.location, locName == nil {
            let geocoder = CLGeocoder()
            currentGeocodingTask = geocoder
            
            geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
                guard let self = self else { return }
                // Only update if this is still the current geocoding task
                if self.currentGeocodingTask === geocoder {
                    if let placemark = placemarks?.first {
                        // Build detailed location string
                        var locationParts: [String] = []
                        
                        // Add sub-locality (district/neighborhood) if available
                        if let subLocality = placemark.subLocality, !subLocality.isEmpty {
                            locationParts.append(subLocality)
                        }
                        
                        // Add locality (city) if available
                        if let locality = placemark.locality, !locality.isEmpty {
                            locationParts.append(locality)
                        }
                        
                        // Add administrative area (province/state) if available
                        if let adminArea = placemark.administrativeArea, !adminArea.isEmpty {
                            locationParts.append(adminArea)
                        }
                        
                        // Add country if available
                        // if let country = placemark.country, !country.isEmpty {
                        //     locationParts.append(country)
                        // }
                        
                        // Join parts with separator, or use name if available
                        if locationParts.isEmpty {
                            locName = placemark.name
                        } else {
                            locName = locationParts.joined(separator: ", ")
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.updateMetaLabel(date: item.creationDate, location: locName)
                    }
                    self.currentGeocodingTask = nil
                }
            }
        } else {
            // Update immediately if we already have location or no location data
            updateMetaLabel(date: item.creationDate, location: locName)
        }
    }
    
    private func updateFileTypeLabel(type: MediaType, fileSize: Int64?, videoDuration: TimeInterval?) {
        var parts: [String] = []
        
        // File type
        switch type {
        case .image:
            parts.append("图片")
        case .livePhoto:
            parts.append("Live Photo")
        case .video:
            parts.append("视频")
        }
        
        // File size
        if let size = fileSize {
            parts.append(formatFileSize(size))
        }
        
        // Video duration
        if let duration = videoDuration {
            parts.append(formatVideoDuration(duration))
        }
        
        fileTypeLabel.text = parts.joined(separator: " • ")
        fileTypeLabel.isHidden = false
    }
    
    private func updateMetaLabel(date: Date?, location: String?) {
        var textParts: [String] = []
        
        // Date with year, month, day, weekday, hour, minute
        if let date = date {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            
            // Format: 2025年12月19日 星期五 14:30
            formatter.dateFormat = "yyyy年M月d日 EEEE HH:mm"
            
            var dateText = formatter.string(from: date)
            
            // "3 Years Ago" logic
            let components = Calendar.current.dateComponents([.year], from: date, to: Date())
            if let years = components.year, years > 0 {
                dateText += " (\(years)年前)"
            }
            textParts.append(dateText)
        }
        
        // Location
        if let loc = location {
            textParts.append("📍 \(loc)")
        }
        
        if textParts.isEmpty {
            metaLabel.isHidden = true
            return
        }
        
        metaLabel.text = textParts.joined(separator: "\n")
        metaLabel.numberOfLines = 0 // Allow unlimited lines for long content
        metaLabel.isHidden = false
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatVideoDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "⏱ %d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "⏱ %d:%02d", minutes, seconds)
        }
    }
    
    private func shiftPosition() {
        // Slight random offset to prevent pixel burn-in
        let randomX = CGFloat.random(in: -2...2)
        let randomY = CGFloat.random(in: -2...2)
        transform = CGAffineTransform(translationX: randomX, y: randomY)
    }
    
    deinit {
        timer?.invalidate()
    }
}

