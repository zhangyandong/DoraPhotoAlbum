import UIKit
import AVFoundation

/// Manages video playback for slideshow
class VideoPlayerManager {
    
    weak var delegate: VideoPlayerManagerDelegate?
    
    private var player: AVPlayer?
    private var videoLayer: AVPlayerLayer?
    private var currentPlayerItem: AVPlayerItem?
    private var currentVideoItemId: String?
    private var timer: Timer?
    
    var isMuted: Bool = false {
        didSet {
            player?.isMuted = isMuted
        }
    }
    
    var videoMaxDuration: TimeInterval = 0
    
    // MARK: - Playback Control
    
    func playVideo(item: UnifiedMediaItem, in containerView: UIView, itemId: String) {
        stopVideo()
        
        currentVideoItemId = itemId
        
        PhotoService.shared.requestPlayerItem(for: item) { [weak self] playerItem in
            guard let self = self else { return }
            
            // Check if this request is still valid
            guard self.currentVideoItemId == itemId else {
                print("VideoPlayerManager: Video load completed but item changed, ignoring")
                return
            }
            
            guard let playerItem = playerItem else {
                print("VideoPlayerManager: Failed to load video")
                DispatchQueue.main.async {
                    if self.currentVideoItemId == itemId {
                        self.currentVideoItemId = nil
                        self.delegate?.videoPlayerManager(self, didFailToLoad: item)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                guard self.currentVideoItemId == itemId else {
                    print("VideoPlayerManager: Video loaded but item changed, ignoring")
                    return
                }
                self.setupAndPlayVideo(item: playerItem, in: containerView)
            }
        }
    }
    
    private func setupAndPlayVideo(item: AVPlayerItem, in containerView: UIView) {
        player = AVPlayer(playerItem: item)
        player?.isMuted = isMuted
        
        videoLayer = AVPlayerLayer(player: player)
        videoLayer?.frame = containerView.bounds
        videoLayer?.videoGravity = .resizeAspect
        videoLayer?.backgroundColor = UIColor.black.cgColor
        
        if let layer = videoLayer {
            containerView.layer.addSublayer(layer)
        }
        
        player?.play()
        observeVideoCompletion(item: item)
        scheduleVideoMaxDuration()
        
        delegate?.videoPlayerManager(self, didStartPlaying: item)
    }
    
    func getVideoLayer() -> AVPlayerLayer? {
        return videoLayer
    }
    
    func stopVideo() {
        currentVideoItemId = nil
        
        // Remove observer for current player item
        if let item = currentPlayerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
            currentPlayerItem = nil
        }
        
        timer?.invalidate()
        timer = nil
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        
        videoLayer?.removeFromSuperlayer()
        videoLayer = nil
    }
    
    func pause() {
        player?.pause()
    }
    
    func resume() {
        player?.play()
    }
    
    func updateFrame(_ frame: CGRect) {
        videoLayer?.frame = frame
    }
    
    // MARK: - Private Methods
    
    private func observeVideoCompletion(item: AVPlayerItem) {
        // Remove previous observer if exists
        if let previousItem = currentPlayerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: previousItem)
        }
        
        currentPlayerItem = item
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }
    
    private func scheduleVideoMaxDuration() {
        timer?.invalidate()
        if videoMaxDuration > 0 {
            timer = Timer.scheduledTimer(withTimeInterval: videoMaxDuration, repeats: false) { [weak self] _ in
                self?.videoDidFinish()
            }
        }
    }
    
    @objc private func videoDidFinish() {
        delegate?.videoPlayerManagerDidFinish(self)
    }
    
    deinit {
        stopVideo()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - VideoPlayerManagerDelegate

protocol VideoPlayerManagerDelegate: AnyObject {
    func videoPlayerManager(_ manager: VideoPlayerManager, didStartPlaying item: AVPlayerItem)
    func videoPlayerManager(_ manager: VideoPlayerManager, didFailToLoad item: UnifiedMediaItem)
    func videoPlayerManagerDidFinish(_ manager: VideoPlayerManager)
}

