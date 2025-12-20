import MediaPlayer

class MusicService {
    static let shared = MusicService()
    
    private var musicPlayer: MPMusicPlayerController?
    private var currentPlaylistName: String?
    private var hasInitializedQueue = false
    private var wasPlayingBeforeSleep = false // Track if music was playing before sleep
    
    // Playback Modes
    enum PlaybackMode: Int {
        case sequential = 0
        case shuffle = 1
        case singleLoop = 2
    }
    
    private init() {
        setupSleepModeObserver()
    }
    
    private func setupSleepModeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSleepModeChanged),
            name: .sleepModeChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleSleepModeChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isSleeping = userInfo["isSleeping"] as? Bool else {
            return
        }
        
        if isSleeping {
            // Entering sleep mode: pause music if playing
            if isPlaying {
                wasPlayingBeforeSleep = true
                pause()
            } else {
                wasPlayingBeforeSleep = false
            }
        } else {
            // Exiting sleep mode: resume music if it was playing before sleep
            if wasPlayingBeforeSleep {
                play()
                wasPlayingBeforeSleep = false
            }
        }
    }
    
    func setupMusic() {
        MPMediaLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async {
                self.musicPlayer = MPMusicPlayerController.applicationQueuePlayer
                self.updatePlaybackConfiguration()
            }
        }
    }
    
    func fetchPlaylists() -> [MPMediaItemCollection] {
        let query = MPMediaQuery.playlists()
        return query.collections ?? []
    }
    
    func updatePlaybackConfiguration() {
        updateConfigurationOnly()
        
        // Auto-play based on settings (used in SlideShowViewController)
        guard let player = musicPlayer else { return }
        let defaults = UserDefaults.standard
        let shouldPlayMusic: Bool
        if defaults.object(forKey: AppConstants.Keys.kPlayBackgroundMusic) != nil {
            shouldPlayMusic = defaults.bool(forKey: AppConstants.Keys.kPlayBackgroundMusic)
        } else {
            shouldPlayMusic = AppConstants.Defaults.playBackgroundMusic
        }
        
        if shouldPlayMusic {
             if player.playbackState != .playing {
                 player.play()
             }
        } else {
             player.pause()
        }
    }
    
    func updateConfigurationOnly() {
        // Only update configuration if player is already initialized
        // Don't initialize player here - that should only happen in SlideShowViewController
        guard let player = musicPlayer else { return }
        
        let defaults = UserDefaults.standard
        
        // Use defaults if not set
        let playlistName: String?
        if defaults.object(forKey: AppConstants.Keys.kSelectedPlaylist) != nil {
            playlistName = defaults.string(forKey: AppConstants.Keys.kSelectedPlaylist)
        } else {
            playlistName = AppConstants.Defaults.selectedPlaylist
        }
        
        let modeInt: Int
        if defaults.object(forKey: AppConstants.Keys.kMusicPlaybackMode) != nil {
            modeInt = defaults.integer(forKey: AppConstants.Keys.kMusicPlaybackMode)
        } else {
            modeInt = AppConstants.Defaults.musicPlaybackMode
        }
        let mode = PlaybackMode(rawValue: modeInt) ?? .sequential
        
        // 1. Set Queue only if changed or first time
        if !hasInitializedQueue || playlistName != currentPlaylistName {
            currentPlaylistName = playlistName
            hasInitializedQueue = true
            
            if let name = playlistName, !name.isEmpty {
                let query = MPMediaQuery.playlists()
                let predicate = MPMediaPropertyPredicate(value: name, forProperty: MPMediaPlaylistPropertyName)
                query.addFilterPredicate(predicate)
                
                if let items = query.items, !items.isEmpty {
                    player.setQueue(with: query)
                } else {
                    // Fallback to all songs if playlist not found
                    player.setQueue(with: MPMediaQuery.songs())
                }
            } else {
                player.setQueue(with: MPMediaQuery.songs())
            }
            // Only prepare, don't play
            player.prepareToPlay()
        }
        
        // 2. Set Mode
        switch mode {
        case .sequential:
            player.shuffleMode = .off
            player.repeatMode = .all
        case .shuffle:
            player.shuffleMode = .songs
            player.repeatMode = .all
        case .singleLoop:
            player.shuffleMode = .off
            player.repeatMode = .one
        }
        
        // Explicitly ensure we don't auto-play here
        // This method is called from settings, not from playback view
    }
    
    func play() {
        musicPlayer?.play()
    }
    
    func pause() {
        musicPlayer?.pause()
    }
    
    func stop() {
        musicPlayer?.stop()
    }
    
    var isPlaying: Bool {
        return musicPlayer?.playbackState == .playing
    }
    
    func toggle() {
        if musicPlayer?.playbackState == .playing {
            musicPlayer?.pause()
        } else {
            musicPlayer?.play()
        }
    }
}
