import UIKit
import AVFoundation

class ClockOverlayView: UIView {
    
    // MARK: - UI Components
    
    // Digital clock (segmented)
    private let digitalContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let timeRow: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        // Keep digits aligned on baseline; we'll nudge ":" separately via baselineOffset.
        stack.alignment = .lastBaseline
        stack.spacing = 8
        return stack
    }()
    
    private let hourLabel = ClockOverlayView.makeDigitLabel(alignment: .center)
    private let colon1Label = ClockOverlayView.makeColonLabel()
    private let minuteLabel = ClockOverlayView.makeDigitLabel(alignment: .center)
    private let secondLabel = ClockOverlayView.makeDigitLabel(alignment: .center)
    private let ampmLabel = ClockOverlayView.makeSuffixLabel()
    
    private var hourWidthConstraint: NSLayoutConstraint?
    private var minuteWidthConstraint: NSLayoutConstraint?
    private var secondWidthConstraint: NSLayoutConstraint?
    private var ampmTopConstraint: NSLayoutConstraint?
    private var ampmLeadingConstraint: NSLayoutConstraint?
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.textAlignment = .center
        
        // Use SF Rounded on iOS 13+, system font on iOS 12
        if #available(iOS 13.0, *) {
            let font = UIFont.systemFont(ofSize: 40, weight: .regular)
            let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
            label.font = UIFont(descriptor: descriptor, size: 40)
        } else {
            label.font = UIFont.systemFont(ofSize: 40, weight: .regular)
        }
        
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 3
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4) // Slight dim for readability
        // view.layer.cornerRadius = 20
        return view
    }()
    
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        return stack
    }()
    
    private var analogClock: AnalogClockView?
    private var analogWidthConstraint: NSLayoutConstraint?
    private var analogHeightConstraint: NSLayoutConstraint?
    private var analogAspectConstraint: NSLayoutConstraint?
    
    // MARK: - Properties
    
    private var timer: Timer?
    private var calendar = Calendar.current
    
    // Hourly chime
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastChimeKey: String?
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        updateSettings()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateSettings), name: .clockSettingsChanged, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopUpdating()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Enable user interaction so gestures can be handled by containerView
        isUserInteractionEnabled = true
        
        addSubview(containerView)
        containerView.addSubview(contentStackView)
        
        setupDigitalRow()
        setupDigitalContainer()
        contentStackView.addArrangedSubview(digitalContainer)
        contentStackView.addArrangedSubview(dateLabel)
        
        setupGestures()
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            contentStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20),
            
            // Allow stack to grow but respect screen edges
            contentStackView.topAnchor.constraint(greaterThanOrEqualTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 20),
            contentStackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        containerView.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        containerView.addGestureRecognizer(swipeRight)
        
        // Ensure containerView can receive touches
        containerView.isUserInteractionEnabled = true
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Only consume touches inside the containerView
        let containerPoint = convert(point, to: containerView)
        return containerView.point(inside: containerPoint, with: event)
    }
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        // Toggle theme
        let currentTheme: Int
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockTheme) != nil {
            currentTheme = UserDefaults.standard.integer(forKey: AppConstants.Keys.kClockTheme)
        } else {
            currentTheme = AppConstants.Defaults.clockTheme
        }
        let newTheme = (currentTheme == 0) ? 1 : 0
        UserDefaults.standard.set(newTheme, forKey: AppConstants.Keys.kClockTheme)
        
        // Notify change
        NotificationCenter.default.post(name: .clockSettingsChanged, object: nil)
        
        // Optional: Add a simple haptic feedback or animation if needed
    }
    
    // MARK: - Logic
    
    func startUpdating() {
        stopUpdating()
        updateTime()
        // Update every second
        // Use weak self to avoid retain cycle
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTime()
        }
    }
    
    func stopUpdating() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func updateSettings() {
        // This selector can be invoked via NotificationCenter on the posting thread.
        // Any UI / AutoLayout changes must happen on the main thread.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateSettings()
            }
            return
        }
        
        let showDate: Bool
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockShowDate) != nil {
            showDate = UserDefaults.standard.bool(forKey: AppConstants.Keys.kClockShowDate)
        } else {
            showDate = AppConstants.Defaults.clockShowDate
        }
        // Digital mode uses the external date label; analog mode will render date inside the dial.
        dateLabel.isHidden = !showDate
        
        let theme: Int
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockTheme) != nil {
            theme = UserDefaults.standard.integer(forKey: AppConstants.Keys.kClockTheme)
        } else {
            theme = AppConstants.Defaults.clockTheme
        }
        
        if theme == 1 {
            // Analog Mode
            digitalContainer.isHidden = true
            setupAnalogClockIfNeeded()
            analogClock?.isHidden = false
            analogClock?.showsDateInDial = showDate
            // Hide external date label in analog mode (date is inside dial).
            dateLabel.isHidden = true
        } else {
            // Digital Mode
            digitalContainer.isHidden = false
            analogClock?.isHidden = true
            // External date label is shown/hidden based on setting.
            dateLabel.isHidden = !showDate
        }
        
        // Re-apply sizing when any clock setting changes (24h / seconds / theme / date).
        applyDynamicSizing()
        
        // Refresh immediately
        updateTime()
    }
    
    private func setupAnalogClockIfNeeded() {
        if analogClock == nil {
            let clock = AnalogClockView(frame: .zero)
            clock.translatesAutoresizingMaskIntoConstraints = false
            clock.backgroundColor = .clear
            clock.setContentHuggingPriority(.required, for: .vertical)
            clock.setContentHuggingPriority(.required, for: .horizontal)
            clock.setContentCompressionResistancePriority(.required, for: .vertical)
            clock.setContentCompressionResistancePriority(.required, for: .horizontal)
            
            // Insert at index 0 (top)
            contentStackView.insertArrangedSubview(clock, at: 0)
            self.analogClock = clock
            
            // We'll size this dynamically in `layoutSubviews` by updating constants,
            // to better adapt to iPhone/iPad and date visibility.
            // IMPORTANT: In a UIStackView, a view with no intrinsic content size can be compressed to ~0.
            // We must provide an explicit size (width/height == constant).
            let w = clock.widthAnchor.constraint(equalToConstant: 240)
            let h = clock.heightAnchor.constraint(equalToConstant: 240)
            let aspect = clock.widthAnchor.constraint(equalTo: clock.heightAnchor)
            w.priority = .required
            h.priority = .required
            aspect.priority = .required
            NSLayoutConstraint.activate([w, h, aspect])
            analogWidthConstraint = w
            analogHeightConstraint = h
            analogAspectConstraint = aspect
            
            // Adjust constraints based on what's visible
            setNeedsLayout()
        }
    }
    
    @objc private func updateTime() {
        let now = Date()
        
        // Always read settings (they can change while the view is visible).
        let is24Hour: Bool
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockFormat24H) != nil {
            is24Hour = UserDefaults.standard.bool(forKey: AppConstants.Keys.kClockFormat24H)
        } else {
            is24Hour = AppConstants.Defaults.clockFormat24H
        }
        
        let showSeconds: Bool
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockShowSeconds) != nil {
            showSeconds = UserDefaults.standard.bool(forKey: AppConstants.Keys.kClockShowSeconds)
        } else {
            showSeconds = AppConstants.Defaults.clockShowSeconds
        }
        
        // Update Analog Clock if visible
        if let analog = analogClock, !analog.isHidden {
            analog.showsSecondHand = showSeconds
            analog.updateTime()
        }
        
        // Digital segmented components
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute, .second], from: now)
        let hour24 = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let second = comps.second ?? 0
        
        let hourText: String
        if is24Hour {
            hourText = String(format: "%d", hour24)
            ampmLabel.isHidden = true
        } else {
            let h = hour24 % 12
            hourText = String(format: "%d", (h == 0 ? 12 : h))
            
            let ampmFormatter = DateFormatter()
            ampmFormatter.locale = Locale.current
            ampmFormatter.dateFormat = "a"
            ampmLabel.text = ampmFormatter.string(from: now)
            ampmLabel.isHidden = false
        }
        
        hourLabel.text = hourText
        minuteLabel.text = String(format: "%02d", minute)
        secondLabel.text = String(format: "%02d", second)
        
        secondLabel.isHidden = !showSeconds
        
        // Blink colons (subtle) — keep stable layout, only change alpha.
        // Requirement: when showing seconds, do NOT blink.
        if showSeconds {
            colon1Label.alpha = 1.0
        } else {
            let on: CGFloat = 1.0
            let off: CGFloat = 0.25
            let blinkAlpha: CGFloat = (second % 2 == 0) ? on : off
            colon1Label.alpha = blinkAlpha
        }

        handleHourlyChimeIfNeeded(now: now, hour24: hour24, minute: minute, second: second, is24Hour: is24Hour)
        
        // Date Format
        if !dateLabel.isHidden {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            dateFormatter.timeStyle = .none
            // Use current locale
            dateFormatter.locale = Locale.current
            dateLabel.text = dateFormatter.string(from: now)
        }
    }
    
    private func handleHourlyChimeIfNeeded(now: Date, hour24: Int, minute: Int, second: Int, is24Hour: Bool) {
        let mode: Int
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockChimeMode) != nil {
            mode = UserDefaults.standard.integer(forKey: AppConstants.Keys.kClockChimeMode)
        } else {
            mode = AppConstants.Defaults.clockChimeMode
        }
        // 0 = off, 1 = half-hour, 2 = hourly
        guard mode != 0 else { return }
        
        guard second == 0 else { return }
        
        let shouldChime: Bool
        let isHalfHour: Bool
        if mode == 2 {
            // Hourly: only at :00
            shouldChime = (minute == 0)
            isHalfHour = false
        } else {
            // Half-hour mode: chime at :00 and :30
            shouldChime = (minute == 0 || minute == 30)
            isHalfHour = (minute == 30)
        }
        guard shouldChime else { return }
        
        // De-dupe within the same minute mark (updateTime can be called multiple times).
        let key = "\(calendar.component(.year, from: now))-\(calendar.component(.month, from: now))-\(calendar.component(.day, from: now))-\(hour24)-\(minute)"
        guard lastChimeKey != key else { return }
        lastChimeKey = key
        
        speakChime(now: now, hour24: hour24, minute: minute, is24Hour: is24Hour, isHalfHour: isHalfHour)
    }
    
    private func speakChime(now: Date, hour24: Int, minute: Int, is24Hour: Bool, isHalfHour: Bool) {
        // If something is already speaking, don't overlap.
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
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
            // Simple English fallback
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
            // If audio session fails, still attempt to speak.
            print("ClockOverlayView: Failed to configure audio session for chime: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        // Prefer the current locale voice when possible.
        if let code = Locale.current.languageCode {
            utterance.voice = AVSpeechSynthesisVoice(language: code)
        }
        speechSynthesizer.speak(utterance)
    }
    
    // Adjust font size for iPad vs iPhone if needed, or rely on Auto Layout scaling?
    // Let's make it slightly adaptive based on trait collection or screen size
    override func layoutSubviews() {
        super.layoutSubviews()
        applyDynamicSizing()
    }
    
    private struct ClockDisplaySettings {
        let theme: Int
        let is24Hour: Bool
        let showSeconds: Bool
        let showDate: Bool
    }
    
    private func currentSettings() -> ClockDisplaySettings {
        let theme: Int
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockTheme) != nil {
            theme = UserDefaults.standard.integer(forKey: AppConstants.Keys.kClockTheme)
        } else {
            theme = AppConstants.Defaults.clockTheme
        }
        
        let is24Hour: Bool
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockFormat24H) != nil {
            is24Hour = UserDefaults.standard.bool(forKey: AppConstants.Keys.kClockFormat24H)
        } else {
            is24Hour = AppConstants.Defaults.clockFormat24H
        }
        
        let showSeconds: Bool
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockShowSeconds) != nil {
            showSeconds = UserDefaults.standard.bool(forKey: AppConstants.Keys.kClockShowSeconds)
        } else {
            showSeconds = AppConstants.Defaults.clockShowSeconds
        }
        
        let showDate: Bool
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockShowDate) != nil {
            showDate = UserDefaults.standard.bool(forKey: AppConstants.Keys.kClockShowDate)
        } else {
            showDate = AppConstants.Defaults.clockShowDate
        }
        
        return ClockDisplaySettings(theme: theme, is24Hour: is24Hour, showSeconds: showSeconds, showDate: showDate)
    }
    
    private func makeRoundedTimeFont(size: CGFloat) -> UIFont {
        // Primary time digits (hour/minute). Must support iOS 12.
        // iOS 12: monospaced digits.
        // iOS 13+: try SF Rounded for nicer look, while still using a stable digit font fallback.
        if #available(iOS 13.0, *) {
            let base = UIFont.systemFont(ofSize: size, weight: .semibold)
            if let desc = base.fontDescriptor.withDesign(.rounded) {
                // Note: SF Rounded isn't guaranteed monospaced; we also pin label widths to prevent jitter.
                return UIFont(descriptor: desc, size: size)
            }
        }
        return UIFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold)
    }
    
    private func makeDigitFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        return UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
    }
    
    private func makeSuffixFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if #available(iOS 13.0, *) {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        } else {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
    }
    
    private func makeRoundedDateFont(size: CGFloat) -> UIFont {
        if #available(iOS 13.0, *) {
            let font = UIFont.systemFont(ofSize: size, weight: .regular)
            let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        } else {
            return UIFont.systemFont(ofSize: size, weight: .regular)
        }
    }
    
    private func applyDynamicSizing() {
        // Ensure we're on main thread (layout can be called on main; guard for safety).
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.applyDynamicSizing()
            }
            return
        }
        
        let s = currentSettings()
        let isPad = traitCollection.userInterfaceIdiom == .pad
        
        // Use safe area frame to avoid notches/home indicator and maximize size safely.
        let safeFrame = containerView.safeAreaLayoutGuide.layoutFrame
        let horizontalInset: CGFloat = isPad ? 28 : 16
        let verticalInset: CGFloat = isPad ? 24 : 16
        let available = safeFrame.insetBy(dx: horizontalInset, dy: verticalInset)
        guard available.width > 0, available.height > 0 else { return }
        
        // Adjust spacing to maximize time size while keeping some breathing room.
        contentStackView.spacing = (s.showDate ? (isPad ? 16 : 12) : 0)
        
        if s.theme == 0 {
            // Digital (segmented): pick base size so the entire row fits.
            let minSize: CGFloat = isPad ? 64 : 44
            let maxSize: CGFloat = isPad ? 420 : 280
            
            // Make hour/minute more prominent while keeping seconds / AMPM lighter & smaller.
            // This keeps the layout stable on iOS 12 and looks nicer.
            let hmScale: CGFloat = 1.12
            let secScale: CGFloat = 0.52
            let ampmScale: CGFloat = 0.26
            
            func fits(baseSize: CGFloat) -> (Bool, CGFloat, CGFloat, CGFloat) {
                let hmSize = baseSize * hmScale
                let timeFont = makeRoundedTimeFont(size: hmSize)
                let secondsSize = max(16, baseSize * secScale)
                let secondsFont = makeDigitFont(size: secondsSize, weight: .regular)
                let ampmSize = max(14, baseSize * ampmScale)
                let ampmFont = makeRoundedDateFont(size: ampmSize)
                
                // Widths: even with pinned widths, some fonts can render "00"/"08" slightly wider than "88"
                // due to side bearings. Use a worst-case measurement + padding to avoid clipping.
                let hourW = maxDigitPairWidth(font: timeFont)
                let minW = maxDigitPairWidth(font: timeFont)
                let secW = ceil(("88" as NSString).size(withAttributes: [.font: secondsFont]).width)
                let colonW = ceil((":"
                    as NSString).size(withAttributes: [.font: timeFont]).width)
                
                var rowW = hourW + colonW + minW
                if s.showSeconds {
                    rowW += colonW + secW
                }
                rowW += CGFloat((s.showSeconds ? 4 : 2)) * timeRow.spacing // rough spacing contribution
                
                // Height: baseline aligned, take max label heights
                let rowH = max(
                    ceil(("88" as NSString).size(withAttributes: [.font: timeFont]).height),
                    ceil(("88" as NSString).size(withAttributes: [.font: secondsFont]).height),
                    // AM/PM is overlaid inside the same container (top-left), so it doesn't add extra height
                    // as long as it's smaller than the base size (which it is).
                    ceil(("下午" as NSString).size(withAttributes: [.font: ampmFont]).height)
                )
                
                let dateFontSize = max(16, baseSize * 0.22)
                let dateFont = makeRoundedDateFont(size: dateFontSize)
                var totalH = rowH
                if s.showDate {
                    let dateSample = "2026年1月1日 星期四"
                    let dateRect = (dateSample as NSString).boundingRect(
                        with: CGSize(width: available.width, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: [.font: dateFont],
                        context: nil
                    )
                    totalH += contentStackView.spacing + ceil(dateRect.height)
                }
                
                return (rowW <= available.width && totalH <= available.height, secondsSize, ampmSize, dateFontSize)
            }
            
            var lo = minSize
            var hi = maxSize
            var best = minSize
            var bestSeconds = max(18, minSize * 0.62)
            var bestAMPM = max(16, minSize * 0.34)
            var bestDate = max(16, minSize * 0.22)
            
            for _ in 0..<18 {
                let mid = (lo + hi) / 2
                let (ok, secSize, apSize, dateSize) = fits(baseSize: mid)
                if ok {
                    best = mid
                    bestSeconds = secSize
                    bestAMPM = apSize
                    bestDate = dateSize
                    lo = mid
                } else {
                    hi = mid
                }
            }
            
            // Apply fonts
            let hmFont = makeRoundedTimeFont(size: best * hmScale)
            hourLabel.font = hmFont
            minuteLabel.font = hmFont
            // Use attributed string to nudge ":" visually to center while keeping baseline alignment.
            colon1Label.attributedText = attributedColon(font: hmFont)
            // Keep seconds and AM/PM lighter (not bold/heavy)
            secondLabel.font = makeDigitFont(size: bestSeconds, weight: .regular)
            ampmLabel.font = makeSuffixFont(size: bestAMPM, weight: .regular)
            dateLabel.font = makeRoundedDateFont(size: bestDate)
            
            // Pin digit widths to avoid jitter (hour varies 1..12 or 0..23).
            hourWidthConstraint?.constant = maxDigitPairWidth(font: hmFont)
            minuteWidthConstraint?.constant = maxDigitPairWidth(font: hmFont)
            secondWidthConstraint?.constant = ceil(("88" as NSString).size(withAttributes: [.font: secondLabel.font as Any]).width)
            
            // No colon between minute and second; use a small visual gap when seconds are shown.
            if s.showSeconds {
                // Scale gap with the chosen base font size for better readability across screens.
                let gap = max(isPad ? 18 : 14, (best * hmScale) * 0.18)
                timeRow.setCustomSpacing(gap, after: minuteLabel)
            } else {
                timeRow.setCustomSpacing(timeRow.spacing, after: minuteLabel)
            }
            
            // Place AM/PM at the top-left of the time, but with breathing room from the digits.
            // Negative offsets move it further left/up, increasing perceived spacing.
            let left = max(isPad ? 14 : 10, best * 0.12)
            let up = max(isPad ? 12 : 8, best * 0.10)
            ampmLeadingConstraint?.constant = -left
            ampmTopConstraint?.constant = -up
            
        } else {
            // Analog: maximize clock size. If date is shown, reserve space.
            setupAnalogClockIfNeeded()

            // Date is inside the dial. Use a tighter margin than digital mode so the dial can be as large as possible.
            let safeFrame = containerView.safeAreaLayoutGuide.layoutFrame
            let analogInset: CGFloat = isPad ? 10 : 6
            let analogAvailable = safeFrame.insetBy(dx: analogInset, dy: analogInset)
            let usableMin = min(analogAvailable.width, analogAvailable.height)
            
            // Push close to full size while staying inside safe area.
            let maxSide = max(120, usableMin * 0.995)
            analogWidthConstraint?.constant = maxSide
            analogHeightConstraint?.constant = maxSide
            
            analogClock?.showsSecondHand = s.showSeconds
            analogClock?.showsDateInDial = s.showDate
            analogClock?.setNeedsLayout()
        }
    }

    private func maxDigitPairWidth(font: UIFont) -> CGFloat {
        // Measure a few likely "worst" combinations and add a small safety padding.
        let samples = ["00", "08", "59", "88"]
        let maxW = samples.map { s -> CGFloat in
            let w = (s as NSString).size(withAttributes: [.font: font]).width
            return ceil(w)
        }.max() ?? 0
        return maxW + 4 // padding to prevent edge clipping
    }
    
    private func maxTimeStringWidth(settings: ClockDisplaySettings, font: UIFont) -> CGFloat {
        // Build candidates that cover worst-case widths in current locale.
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale.current
        if settings.is24Hour {
            timeFormatter.dateFormat = settings.showSeconds ? "HH:mm:ss" : "HH:mm"
        } else {
            timeFormatter.dateFormat = settings.showSeconds ? "h:mm:ss a" : "h:mm a"
        }
        
        let cal = Calendar.current
        let base = cal.dateComponents([.year, .month, .day], from: Date())
        
        func makeDate(hour: Int, minute: Int, second: Int) -> Date {
            var c = base
            c.hour = hour
            c.minute = minute
            c.second = second
            return cal.date(from: c) ?? Date()
        }
        
        // Candidates:
        // - For 24h: 23:59(:59) is typically widest due to digits.
        // - For 12h: compare AM and PM (in some locales "上午/下午" differ in width).
        var candidates: [String] = []
        if settings.is24Hour {
            candidates.append(timeFormatter.string(from: makeDate(hour: 23, minute: 59, second: 59)))
        } else {
            candidates.append(timeFormatter.string(from: makeDate(hour: 1, minute: 59, second: 59)))   // AM-ish
            candidates.append(timeFormatter.string(from: makeDate(hour: 13, minute: 59, second: 59)))  // PM-ish
        }
        
        // Measure with the same kern we use for display.
        let kern: CGFloat = 2.0
        let maxWidth = candidates.map { str -> CGFloat in
            let rect = (str as NSString).boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .kern: kern],
                context: nil
            )
            return ceil(rect.width)
        }.max() ?? 0
        
        return maxWidth
    }
    
    // Date height reservation helper removed: analog mode renders date inside the dial.
    
    private func setupDigitalRow() {
        // Build segmented digital row once.
        timeRow.addArrangedSubview(hourLabel)
        timeRow.addArrangedSubview(colon1Label)
        timeRow.addArrangedSubview(minuteLabel)
        timeRow.addArrangedSubview(secondLabel)
        
        // Width pinning for digits (updated in applyDynamicSizing).
        let hw = hourLabel.widthAnchor.constraint(equalToConstant: 80)
        hw.priority = .required
        hw.isActive = true
        hourWidthConstraint = hw
        
        let mw = minuteLabel.widthAnchor.constraint(equalToConstant: 80)
        mw.priority = .required
        mw.isActive = true
        minuteWidthConstraint = mw
        
        let sw = secondLabel.widthAnchor.constraint(equalToConstant: 60)
        sw.priority = .required
        sw.isActive = true
        secondWidthConstraint = sw
        
        // Fixed colon width to keep baseline alignment stable.
        colon1Label.setContentHuggingPriority(.required, for: .horizontal)
        
        // Initial visibility defaults
        secondLabel.isHidden = false
        ampmLabel.isHidden = true
    }

    private func setupDigitalContainer() {
        digitalContainer.addSubview(timeRow)
        digitalContainer.addSubview(ampmLabel)

        NSLayoutConstraint.activate([
            timeRow.topAnchor.constraint(equalTo: digitalContainer.topAnchor),
            timeRow.bottomAnchor.constraint(equalTo: digitalContainer.bottomAnchor),
            timeRow.leadingAnchor.constraint(equalTo: digitalContainer.leadingAnchor),
            timeRow.trailingAnchor.constraint(equalTo: digitalContainer.trailingAnchor),

            // AM/PM should sit at the top-left corner of the time (hour) area.
            // We keep constraints as vars so we can adjust offsets based on current font size.
            // Defaults are small negative offsets to prevent it from touching the digits.
            ampmLabel.trailingAnchor.constraint(lessThanOrEqualTo: digitalContainer.trailingAnchor)
        ])
        
        let leading = ampmLabel.leadingAnchor.constraint(equalTo: hourLabel.leadingAnchor, constant: -10)
        let top = ampmLabel.topAnchor.constraint(equalTo: timeRow.topAnchor, constant: -8)
        NSLayoutConstraint.activate([leading, top])
        ampmLeadingConstraint = leading
        ampmTopConstraint = top
    }
    
    private static func makeDigitLabel(alignment: NSTextAlignment) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.textAlignment = alignment
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 2, height: 2)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 4
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }
    
    private static func makeColonLabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.textAlignment = .center
        label.text = ":" // will be replaced with attributed text in sizing pass
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 2, height: 2)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 4
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }
    
    private static func makeSuffixLabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.textAlignment = .left
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 3
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }
    
    private func attributedColon(font: UIFont) -> NSAttributedString {
        // Baseline-aligned ":" tends to look slightly low. Lift it based on font metrics.
        // Using (capHeight - xHeight) roughly approximates the "midline" adjustment across fonts.
        let lift = max(0, (font.capHeight - font.xHeight) * 0.35)
        return NSAttributedString(string: ":", attributes: [
            .font: font,
            .baselineOffset: lift
        ])
    }
}
