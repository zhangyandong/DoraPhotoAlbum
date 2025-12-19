import MediaPlayer

class MusicService {
    static let shared = MusicService()
    
    private var musicPlayer: MPMusicPlayerController?
    private var currentPlaylistName: String?
    private var hasInitializedQueue = false
    
    // Playback Modes
    enum PlaybackMode: Int {
        case sequential = 0
        case shuffle = 1
        case singleLoop = 2
    }
    
    private init() {}
    
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
        guard let player = musicPlayer else { return }
        
        let defaults = UserDefaults.standard
        let playlistName = defaults.string(forKey: AppConstants.Keys.kSelectedPlaylist)
        let modeInt = defaults.integer(forKey: AppConstants.Keys.kMusicPlaybackMode)
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
        
        if defaults.bool(forKey: AppConstants.Keys.kPlayBackgroundMusic) {
             if player.playbackState != .playing {
                 player.play()
             }
        } else {
             player.pause()
        }
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
