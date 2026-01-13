import UIKit

class SchedulerService {
    static let shared = SchedulerService()
    
    private var timer: Timer?
    private var overlayWindow: UIWindow?
    private var previousBrightness: CGFloat = 0.8
    private var isSleeping = false
    
    private init() {}
    
    func startMonitoring() {
        // If there is no active schedule, don't run a timer.
        guard hasActiveSchedule() else {
            stopMonitoring()
            return
        }
        
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
        // Load multi-plan schedules first. If none exist, fall back to legacy behavior via migration.
        let plans = SchedulePlanStore.load()
        
        // If there is no active plan, exit sleep mode if currently sleeping.
        if !plans.contains(where: { $0.sleepEnabled || $0.wakeEnabled }) {
            if isSleeping { exitSleepMode() }
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
        
        // Determine if ANY plan requires sleeping right now.
        let shouldSleep = plans.contains { plan in
            return self.planShouldSleepNow(plan, currentMins: currentMins, currentWeekday: currentWeekday)
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
    
    private func planShouldSleepNow(_ plan: SchedulePlan, currentMins: Int, currentWeekday: Int) -> Bool {
        let sleepWeekdays = Set(plan.sleepWeekdays)
        let wakeWeekdays = Set(plan.wakeWeekdays)
        
        let isSleepWeekday = plan.sleepEnabled && sleepWeekdays.contains(currentWeekday)
        let isWakeWeekday = plan.wakeEnabled && wakeWeekdays.contains(currentWeekday)
        
        // If neither sleep nor wake applies today for this plan, it doesn't affect current state.
        guard isSleepWeekday || isWakeWeekday else { return false }
        
        let sleepMins: Int? = isSleepWeekday ? plan.sleepMinutes : nil
        let wakeMins: Int? = isWakeWeekday ? plan.wakeMinutes : nil
        
        if let sleep = sleepMins, let wake = wakeMins {
            if sleep > wake {
                // Crosses midnight (e.g. 22:00 to 07:00)
                return (currentMins >= sleep || currentMins < wake)
            } else {
                // Same day window (e.g. 13:00 to 14:00)
                return (currentMins >= sleep && currentMins < wake)
            }
        } else if let sleep = sleepMins {
            // Only sleep enabled: sleep from sleep time until end of day
            return currentMins >= sleep
        } else if let wake = wakeMins {
            // Only wake enabled: sleep from midnight until wake time
            return currentMins < wake
        }
        return false
    }
    
    private func hasActiveSchedule() -> Bool {
        let plans = SchedulePlanStore.load()
        if plans.contains(where: { $0.sleepEnabled || $0.wakeEnabled }) {
            return true
        }
        
        // Legacy fallback
        let defaults = UserDefaults.standard
        let sleepEnabled: Bool
        if defaults.object(forKey: AppConstants.Keys.kSleepEnabled) != nil {
            sleepEnabled = defaults.bool(forKey: AppConstants.Keys.kSleepEnabled)
        } else {
            sleepEnabled = AppConstants.Defaults.sleepEnabled
        }
        let wakeEnabled: Bool
        if defaults.object(forKey: AppConstants.Keys.kWakeEnabled) != nil {
            wakeEnabled = defaults.bool(forKey: AppConstants.Keys.kWakeEnabled)
        } else {
            wakeEnabled = AppConstants.Defaults.wakeEnabled
        }
        return sleepEnabled || wakeEnabled
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

