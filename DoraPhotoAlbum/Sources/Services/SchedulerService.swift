import UIKit

class SchedulerService {
    static let shared = SchedulerService()
    
    private var timer: Timer?
    private var overlayWindow: UIWindow?
    private var previousBrightness: CGFloat = 0.8
    private var isSleeping = false
    
    private init() {}
    
    func startMonitoring() {
        // Invalidate existing timer to prevent stacking
        timer?.invalidate()
        
        // Check every minute
        // Add to common mode to ensure it runs even during UI interactions
        timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkTime()
        }
        RunLoop.main.add(timer!, forMode: .common)
        
        // Initial check immediately
        checkTime()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        // Exit sleep mode if currently sleeping
        if isSleeping {
            exitSleepMode()
        }
    }
    
    private func checkTime() {
        let defaults = UserDefaults.standard
        
        // Check if sleep is enabled
        let sleepEnabled: Bool
        if defaults.object(forKey: AppConstants.Keys.kSleepEnabled) != nil {
            sleepEnabled = defaults.bool(forKey: AppConstants.Keys.kSleepEnabled)
        } else {
            sleepEnabled = AppConstants.Defaults.sleepEnabled
        }
        
        // Check if wake is enabled
        let wakeEnabled: Bool
        if defaults.object(forKey: AppConstants.Keys.kWakeEnabled) != nil {
            wakeEnabled = defaults.bool(forKey: AppConstants.Keys.kWakeEnabled)
        } else {
            wakeEnabled = AppConstants.Defaults.wakeEnabled
        }
        
        // If both are disabled, exit sleep mode if currently sleeping
        guard sleepEnabled || wakeEnabled else {
            if isSleeping {
                exitSleepMode()
            }
            return
        }
        
        let now = Date()
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        let currentMins = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)
        
        // Get current weekday (1=Sunday, 2=Monday, ..., 7=Saturday in Calendar)
        // Convert to our format: 1=Monday, 2=Tuesday, ..., 7=Sunday
        var currentWeekday = (currentComponents.weekday ?? 1) - 1
        if currentWeekday == 0 {
            currentWeekday = 7 // Sunday
        }
        
        // Get selected weekdays for sleep and wake
        let sleepWeekdays: Set<Int>
        if sleepEnabled, let weekdaysArray = defaults.array(forKey: AppConstants.Keys.kSleepWeekdays) as? [Int] {
            sleepWeekdays = Set(weekdaysArray)
        } else if sleepEnabled {
            sleepWeekdays = Set(1...7) // Default: all weekdays
        } else {
            sleepWeekdays = Set<Int>()
        }
        
        let wakeWeekdays: Set<Int>
        if wakeEnabled, let weekdaysArray = defaults.array(forKey: AppConstants.Keys.kWakeWeekdays) as? [Int] {
            wakeWeekdays = Set(weekdaysArray)
        } else if wakeEnabled {
            wakeWeekdays = Set(1...7) // Default: all weekdays
        } else {
            wakeWeekdays = Set<Int>()
        }
        
        // Check if current weekday is applicable
        let isSleepWeekday = sleepWeekdays.contains(currentWeekday)
        let isWakeWeekday = wakeWeekdays.contains(currentWeekday)
        
        // If current weekday is not in any selected weekdays, exit sleep mode
        guard isSleepWeekday || isWakeWeekday else {
            if isSleeping {
                exitSleepMode()
            }
            return
        }
        
        var shouldSleep = false
        
        // Get sleep and wake times (use defaults if not set)
        var sleepMins: Int?
        if sleepEnabled, isSleepWeekday {
            let sleepDate: Date
            if let savedDate = defaults.object(forKey: AppConstants.Keys.kSleepTime) as? Date {
                sleepDate = savedDate
            } else {
                sleepDate = AppConstants.Defaults.defaultSleepTime
            }
            let sleepComponents = calendar.dateComponents([.hour, .minute], from: sleepDate)
            sleepMins = (sleepComponents.hour ?? 0) * 60 + (sleepComponents.minute ?? 0)
        }
        
        var wakeMins: Int?
        if wakeEnabled, isWakeWeekday {
            let wakeDate: Date
            if let savedDate = defaults.object(forKey: AppConstants.Keys.kWakeTime) as? Date {
                wakeDate = savedDate
            } else {
                wakeDate = AppConstants.Defaults.defaultWakeTime
            }
            let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeDate)
            wakeMins = (wakeComponents.hour ?? 0) * 60 + (wakeComponents.minute ?? 0)
        }
        
        // Determine if should sleep based on time
        if let sleep = sleepMins, let wake = wakeMins {
            // Both enabled: check if current time is in sleep period
            if sleep > wake {
                // Crosses midnight (e.g. 22:00 to 07:00)
                // Sleep from sleep time to midnight, then from midnight to wake time
                shouldSleep = (currentMins >= sleep || currentMins < wake)
            } else {
                // Same day (e.g. 13:00 to 14:00)
                // Sleep between sleep time and wake time
                shouldSleep = (currentMins >= sleep && currentMins < wake)
            }
        } else if let sleep = sleepMins {
            // Only sleep enabled: sleep from sleep time until end of day
            // Then check again next day if weekday matches
            shouldSleep = (currentMins >= sleep)
        } else if let wake = wakeMins {
            // Only wake enabled: sleep from midnight until wake time
            // After wake time, don't sleep (until next day if weekday matches)
            shouldSleep = (currentMins < wake)
        }
        
        if shouldSleep {
            if !isSleeping {
                enterSleepMode()
            }
        } else {
            if isSleeping {
                exitSleepMode()
            }
        }
    }
    
    private func enterSleepMode() {
        print("Entering Sleep Mode")
        isSleeping = true
        previousBrightness = UIScreen.main.brightness
        
        DispatchQueue.main.async {
            // Dim screen
            UIScreen.main.brightness = 0.0
            
            // Show Black Overlay
            if self.overlayWindow == nil {
                if #available(iOS 13.0, *), let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    self.overlayWindow = UIWindow(windowScene: scene)
                } else {
                    self.overlayWindow = UIWindow(frame: UIScreen.main.bounds)
                }
            }
            
            guard let window = self.overlayWindow else { return }
            window.backgroundColor = .black
            window.windowLevel = .alert + 100 // Very high
            window.isHidden = false
            window.makeKeyAndVisible()
            
            // Add tap gesture to wake from sleep mode
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.tempWake))
            window.addGestureRecognizer(tap)
            
            // Notify that sleep mode has started
            NotificationCenter.default.post(name: .sleepModeChanged, object: nil, userInfo: ["isSleeping": true])
        }
    }
    
    @objc private func tempWake() {
        exitSleepMode()
        // Restart monitoring immediately after temporary wake
        // The timer will continue checking every minute
        // No need to invalidate and recreate, just ensure monitoring continues
    }
    
    private func exitSleepMode() {
        print("Exiting Sleep Mode")
        isSleeping = false
        
        DispatchQueue.main.async {
            UIScreen.main.brightness = self.previousBrightness
            
            // Hide and remove overlay window
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
            
            // Restore main window (iOS 12 compatibility)
            // In iOS 12, we need to explicitly restore the key window
            if #available(iOS 13.0, *) {
                // iOS 13+: System automatically restores the previous key window
            } else {
                // iOS 12: Explicitly restore the main window from AppDelegate
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                   let mainWindow = appDelegate.window {
                    mainWindow.makeKeyAndVisible()
                } else {
                    // Fallback: try to restore key window
                    UIApplication.shared.keyWindow?.makeKeyAndVisible()
                }
            }
            
            // Notify that sleep mode has ended
            NotificationCenter.default.post(name: .sleepModeChanged, object: nil, userInfo: ["isSleeping": false])
        }
    }
}

