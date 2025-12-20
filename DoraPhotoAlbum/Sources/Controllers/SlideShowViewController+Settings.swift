import UIKit

// MARK: - Settings Management Extension
extension SlideShowViewController {
    
    func loadSettings() {
        let defaults = UserDefaults.standard
        
        // Display duration: use default if not set
        let savedDuration = defaults.double(forKey: AppConstants.Keys.kDisplayDuration)
        displayDuration = savedDuration > 0 ? savedDuration : AppConstants.Defaults.displayDuration
        
        // Video max duration: use default if not set
        if defaults.object(forKey: AppConstants.Keys.kVideoMaxDuration) != nil {
            videoMaxDuration = defaults.double(forKey: AppConstants.Keys.kVideoMaxDuration)
        } else {
            videoMaxDuration = AppConstants.Defaults.videoMaxDuration
        }
        
        // Video muted: use default if not set
        if let muted = defaults.object(forKey: AppConstants.Keys.kVideoMuted) as? Bool {
            isVideoMuted = muted
        } else {
            isVideoMuted = AppConstants.Defaults.videoMuted
        }
        
        // Play music with video: use default if not set
        if defaults.object(forKey: AppConstants.Keys.kPlayMusicWithVideo) != nil {
            playMusicWithVideo = defaults.bool(forKey: AppConstants.Keys.kPlayMusicWithVideo)
        } else {
            playMusicWithVideo = AppConstants.Defaults.playMusicWithVideo
        }
        
        // Content mode: use default if not set
        let contentModeIndex: Int
        if defaults.object(forKey: AppConstants.Keys.kContentMode) != nil {
            contentModeIndex = defaults.integer(forKey: AppConstants.Keys.kContentMode)
        } else {
            contentModeIndex = AppConstants.Defaults.contentMode
        }
        contentMode = (contentModeIndex == 1) ? .scaleAspectFit : .scaleAspectFill
        
        // Clock mode: use default if not set
        if defaults.object(forKey: AppConstants.Keys.kStartInClockMode) != nil {
            isClockMode = defaults.bool(forKey: AppConstants.Keys.kStartInClockMode)
        } else {
            isClockMode = AppConstants.Defaults.startInClockMode
        }
    }
    
    func reloadSettings() {
        loadSettings()
        
        // Update current player if playing
        videoPlayerManager?.isMuted = isVideoMuted
        
        // Sync background music state
        isBackgroundMusicOn = MusicService.shared.isPlaying
        
        // Update music playback based on settings
        let defaults = UserDefaults.standard
        let shouldPlayMusic: Bool
        if defaults.object(forKey: AppConstants.Keys.kPlayBackgroundMusic) != nil {
            shouldPlayMusic = defaults.bool(forKey: AppConstants.Keys.kPlayBackgroundMusic)
        } else {
            shouldPlayMusic = AppConstants.Defaults.playBackgroundMusic
        }
        
        if shouldPlayMusic {
            MusicService.shared.setupMusic()
        } else {
            MusicService.shared.stop()
        }
        
        // Apply content mode to image display manager
        imageDisplayManager?.updateContentMode(contentMode)
    }
}

