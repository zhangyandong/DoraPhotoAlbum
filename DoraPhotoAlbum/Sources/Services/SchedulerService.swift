import UIKit

class SchedulerService {
    static let shared = SchedulerService()
    
    private var timer: Timer?
    private var overlayWindow: UIWindow?
    private var previousBrightness: CGFloat = 0.5
    private var isSleeping = false
    
    private init() {}
    
    func startMonitoring() {
        // Invalidate existing timer to prevent stacking
        timer?.invalidate()
        
        // Check every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkTime()
        }
        // Initial check delay to let app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkTime()
        }
    }
    
    private func checkTime() {
        let defaults = UserDefaults.standard
        guard let sleepDate = defaults.object(forKey: AppConstants.Keys.kSleepTime) as? Date,
              let wakeDate = defaults.object(forKey: AppConstants.Keys.kWakeTime) as? Date else {
            return
        }
        
        let now = Date()
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)
        let sleepComponents = calendar.dateComponents([.hour, .minute], from: sleepDate)
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeDate)
        
        let currentMins = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)
        let sleepMins = (sleepComponents.hour ?? 0) * 60 + (sleepComponents.minute ?? 0)
        let wakeMins = (wakeComponents.hour ?? 0) * 60 + (wakeComponents.minute ?? 0)
        
        var shouldSleep = false
        
        if sleepMins > wakeMins {
            // Crosses midnight (e.g. 22:00 to 07:00)
            shouldSleep = (currentMins >= sleepMins || currentMins < wakeMins)
        } else {
            // Same day (e.g. 13:00 to 14:00)
            shouldSleep = (currentMins >= sleepMins && currentMins < wakeMins)
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
            
            // Add a label to tap to wake temporarily?
            let label = UILabel()
            label.text = "Sleeping... Tap to Wake"
            label.textColor = .darkGray
            label.alpha = 0.1
            label.sizeToFit()
            label.center = window.center
            window.addSubview(label)
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.tempWake))
            window.addGestureRecognizer(tap)
        }
    }
    
    @objc private func tempWake() {
        exitSleepMode()
        // Snooze check for 5 mins?
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            self?.startMonitoring() // Restart loop
        }
    }
    
    private func exitSleepMode() {
        print("Exiting Sleep Mode")
        isSleeping = false
        
        DispatchQueue.main.async {
            UIScreen.main.brightness = self.previousBrightness
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
            
            // Restore Key Window
            if #available(iOS 13.0, *) {
                // Scene delegate usually handles this, finding the main window
                 UIApplication.shared.windows.first { $0.isKeyWindow == false }?.makeKeyAndVisible()
            } else {
                UIApplication.shared.keyWindow?.makeKeyAndVisible()
            }
        }
    }
}

