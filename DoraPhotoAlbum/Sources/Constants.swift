import Foundation

struct AppConstants {
    struct Keys {
        static let kDisplayDuration = "kDisplayDuration"
        static let kVideoMaxDuration = "kVideoMaxDuration"
        static let kContentMode = "kContentMode"
        static let kPlayBackgroundMusic = "kPlayBackgroundMusic"
        static let kPlayMusicWithVideo = "kPlayMusicWithVideo" // 是否在视频播放时继续背景音乐
        static let kWebDAVHost = "kWebDAVHost"
        static let kWebDAVUser = "kWebDAVUser"
        static let kWebDAVPassword = "kWebDAVPassword"
        static let kWebDAVSelectedPath = "kWebDAVSelectedPath"
        static let kSleepTime = "kSleepTime"
        static let kWakeTime = "kWakeTime"
        static let kSelectedPlaylist = "kSelectedPlaylist" // Name of the playlist, empty for All Songs
        static let kMusicPlaybackMode = "kMusicPlaybackMode" // 0: Sequential, 1: Shuffle, 2: Single Loop
        static let kVideoMuted = "kVideoMuted"
        static let kCacheMaxSize = "kCacheMaxSize" // Maximum cache size in bytes (default: 2GB)
    }
}

