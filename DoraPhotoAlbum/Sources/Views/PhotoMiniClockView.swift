import UIKit
import AVFoundation

/// A minimal clock overlay for photo slideshow: shows only hour and minute (HH:mm) at top center.
/// This is intentionally separate from `ClockOverlayView` (used for full clock-only mode).
final class PhotoMiniClockView: UIView {
    
    private let label = UILabel()
    private var timer: Timer?
    private let formatter = DateFormatter()
    private var currentFontSize: CGFloat = 0
    
    // Chime (voice report) - separate from ClockOverlayView implementation by design.
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastChimeKey: String?
    private var calendar = Calendar.current
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        isUserInteractionEnabled = false
        // No background in photo+clock mode: keep only text + shadow.
        backgroundColor = .clear
        layer.cornerRadius = 0
        layer.masksToBounds = false
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .white
        label.numberOfLines = 1
        updateFontIfNeeded()
        
        // Shadow for readability over bright photos (since we have no background).
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.75
        label.layer.shadowRadius = 6
        label.layer.shadowOffset = CGSize(width: 0, height: 2)
        label.layer.masksToBounds = false
        
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        
        updateFormatter()
        updateText()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateFontIfNeeded()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateFontIfNeeded()
    }
    
    private func preferredFontSize() -> CGFloat {
        // Scale by the shortest side of THIS view (works better for iPad + Split View).
        // Reference: 390pt -> 40pt (phone baseline); allow larger on iPad.
        let shortSide = max(1, min(bounds.width, bounds.height))
        let isPad = traitCollection.userInterfaceIdiom == .pad
        
        let base: CGFloat = isPad ? 60.0 : 40.0
        let scaled = base * (shortSide / 390.0)
        
        let minSize: CGFloat = isPad ? 44.0 : 32.0
        let maxSize: CGFloat = isPad ? 78.0 : 60.0
        return max(minSize, min(maxSize, scaled))
    }
    
    private func updateFontIfNeeded() {
        let size = preferredFontSize()
        // Avoid resetting font repeatedly.
        if abs(size - currentFontSize) < 0.5 { return }
        currentFontSize = size
        
        if #available(iOS 13.0, *) {
            label.font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold)
        } else {
            label.font = UIFont.systemFont(ofSize: size, weight: .semibold)
        }
    }
    
    private func updateFormatter() {
        // Respect 24h setting if present, otherwise default to AppConstants.Defaults.clockFormat24H
        let defaults = UserDefaults.standard
        let is24H: Bool
        if defaults.object(forKey: AppConstants.Keys.kClockFormat24H) != nil {
            is24H = defaults.bool(forKey: AppConstants.Keys.kClockFormat24H)
        } else {
            is24H = AppConstants.Defaults.clockFormat24H
        }
        formatter.locale = Locale.current
        formatter.dateFormat = is24H ? "HH:mm" : "h:mm"
    }
    
    private func updateText() {
        let now = Date()
        label.text = formatter.string(from: now)
        handleChimeIfNeeded(now: now)
    }
    
    func startUpdating() {
        stopUpdating()
        updateFormatter()
        updateText()
        
        // Update on minute boundary for efficiency (since we only show HH:mm).
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.second], from: now)
        let sec = comps.second ?? 0
        let delay = TimeInterval(max(1, 60 - sec))
        
        Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.updateText()
            self.timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.updateText()
            }
        }
    }
    
    func stopUpdating() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Voice chime
    
    private func handleChimeIfNeeded(now: Date) {
        let mode: Int
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockChimeMode) != nil {
            mode = UserDefaults.standard.integer(forKey: AppConstants.Keys.kClockChimeMode)
        } else {
            mode = AppConstants.Defaults.clockChimeMode
        }
        // 0 = off, 1 = half-hour, 2 = hourly
        guard mode != 0 else { return }
        
        // Only check at minute boundary; our timer ticks every 60s aligned to minute.
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let hour24 = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let second = comps.second ?? 0
        
        // Be tolerant to timer drift.
        guard second <= 2 else { return }
        
        let shouldChime: Bool
        let isHalfHour: Bool
        if mode == 2 {
            shouldChime = (minute == 0)
            isHalfHour = false
        } else {
            shouldChime = (minute == 0 || minute == 30)
            isHalfHour = (minute == 30)
        }
        guard shouldChime else { return }
        
        let key = "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)-\(hour24)-\(minute)"
        guard lastChimeKey != key else { return }
        lastChimeKey = key
        
        speakChime(now: now, hour24: hour24, isHalfHour: isHalfHour)
    }
    
    private func speakChime(now: Date, hour24: Int, isHalfHour: Bool) {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let defaults = UserDefaults.standard
        let is24Hour: Bool
        if defaults.object(forKey: AppConstants.Keys.kClockFormat24H) != nil {
            is24Hour = defaults.bool(forKey: AppConstants.Keys.kClockFormat24H)
        } else {
            is24Hour = AppConstants.Defaults.clockFormat24H
        }
        
        let language = Locale.current.languageCode ?? "zh"
        let text: String
        if language.hasPrefix("zh") {
            if isHalfHour {
                if is24Hour {
                    text = "现在是\(hour24)点半"
                } else {
                    let h = hour24 % 12
                    let hour12 = (h == 0 ? 12 : h)
                    let ampmFormatter = DateFormatter()
                    ampmFormatter.locale = Locale.current
                    ampmFormatter.dateFormat = "a"
                    let ampm = ampmFormatter.string(from: now)
                    text = "现在是\(ampm)\(hour12)点半"
                }
            } else {
                if is24Hour {
                    text = "现在是\(hour24)点整"
                } else {
                    let h = hour24 % 12
                    let hour12 = (h == 0 ? 12 : h)
                    let ampmFormatter = DateFormatter()
                    ampmFormatter.locale = Locale.current
                    ampmFormatter.dateFormat = "a"
                    let ampm = ampmFormatter.string(from: now)
                    text = "现在是\(ampm)\(hour12)点整"
                }
            }
        } else {
            let h = is24Hour ? hour24 : ((hour24 % 12 == 0) ? 12 : (hour24 % 12))
            text = isHalfHour ? "It's \(h) thirty." : "It's \(h) o'clock."
        }
        
        // Configure audio session to duck other audio slightly (e.g. background music).
        let session = AVAudioSession.sharedInstance()
        do {
            if #available(iOS 10.0, *) {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            } else {
                try session.setCategory(.playback, options: [.duckOthers, .mixWithOthers])
            }
            try session.setActive(true)
        } catch {
            // Ignore and still speak.
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        if let code = Locale.current.languageCode {
            utterance.voice = AVSpeechSynthesisVoice(language: code)
        }
        speechSynthesizer.speak(utterance)
    }
}

