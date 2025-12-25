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
        static let kWebDAVSelectedPaths = "kWebDAVSelectedPaths" // [String]
        static let kSleepEnabled = "kSleepEnabled"
        static let kWakeEnabled = "kWakeEnabled"
        static let kSleepTime = "kSleepTime"
        static let kWakeTime = "kWakeTime"
        static let kSleepWeekdays = "kSleepWeekdays" // Set of Int (1=Monday, 7=Sunday)
        static let kWakeWeekdays = "kWakeWeekdays" // Set of Int (1=Monday, 7=Sunday)
        static let kSelectedPlaylist = "kSelectedPlaylist" // Name of the playlist, empty for All Songs
        static let kMusicPlaybackMode = "kMusicPlaybackMode" // 0: Sequential, 1: Shuffle, 2: Single Loop
        static let kVideoMuted = "kVideoMuted"
        static let kCacheMaxSize = "kCacheMaxSize" // Maximum cache size in bytes (default: 2GB)
        static let kLocalAlbumEnabled = "kLocalAlbumEnabled"
        static let kWebDAVEnabled = "kWebDAVEnabled"
        
        // Clock Settings
        static let kStartInClockMode = "kStartInClockMode"
        static let kClockFormat24H = "kClockFormat24H"
        static let kClockShowSeconds = "kClockShowSeconds"
        static let kClockShowDate = "kClockShowDate"
        static let kClockTheme = "kClockTheme" // 0: Digital, 1: Analog
    }
    
    struct Defaults {
        // Playback Settings
        static let displayDuration: Double = 5.0 // 照片播放间隔（秒）
        static let videoMaxDuration: Double = 0.0 // 视频最大播放时长（秒，0表示不限制）
        static let contentMode: Int = 1 // 图片显示模式：0=填充(裁剪), 1=适应(完整)
        static let videoMuted: Bool = false // 视频静音：false=不静音
        
        // Music Settings
        static let playBackgroundMusic: Bool = false // 播放背景音乐：false=关闭
        static let playMusicWithVideo: Bool = false // 视频播放时继续背景音乐：false=关闭
        static let musicPlaybackMode: Int = 0 // 播放模式：0=顺序播放, 1=随机播放, 2=单曲循环
        static let selectedPlaylist: String? = nil // 选择的播放列表：nil=所有歌曲
        
        // Clock Settings
        static let startInClockMode: Bool = false // 默认开启时钟模式：false=关闭
        static let clockTheme: Int = 0 // 时钟样式：0=数字时钟, 1=圆盘时钟
        static let clockFormat24H: Bool = true // 24小时制：true=开启
        static let clockShowSeconds: Bool = true // 显示秒：true=开启
        static let clockShowDate: Bool = true // 显示日期：true=开启
        
        // Schedule Settings
        static let sleepEnabled: Bool = false // 休眠时间：false=关闭
        static let wakeEnabled: Bool = false // 唤醒时间：false=关闭
        
        // Default sleep and wake times (22:00 and 07:00)
        static var defaultSleepTime: Date {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 22
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? Date()
        }
        
        static var defaultWakeTime: Date {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 7
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? Date()
        }
    }
}

extension Notification.Name {
    static let mediaSourceChanged = Notification.Name("MediaSourceChanged")
    static let clockSettingsChanged = Notification.Name("ClockSettingsChanged")
    static let sleepModeChanged = Notification.Name("SleepModeChanged")
}

