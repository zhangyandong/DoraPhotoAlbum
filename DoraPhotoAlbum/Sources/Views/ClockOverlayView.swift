import UIKit

class ClockOverlayView: UIView {
    
    // MARK: - UI Components
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.textAlignment = .center
        
        // Use a more elegant font - SF Rounded on iOS 13+, monospaced on iOS 12
        if #available(iOS 13.0, *) {
            // SF Rounded for a softer, more modern look
            let font = UIFont.systemFont(ofSize: 160, weight: .medium)
            let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
            label.font = UIFont(descriptor: descriptor, size: 160)
        } else {
            // Fallback to monospaced digit font for iOS 12
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 160, weight: .medium)
        }
        
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 2, height: 2)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 4
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.3
        
        // Add letter spacing for better readability
        if #available(iOS 13.0, *) {
            // Letter spacing is handled via attributed string if needed
        }
        
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.textAlignment = .center
        
        // Use SF Rounded on iOS 13+, system font on iOS 12
        if #available(iOS 13.0, *) {
            let font = UIFont.systemFont(ofSize: 40, weight: .medium)
            let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
            label.font = UIFont(descriptor: descriptor, size: 40)
        } else {
            label.font = UIFont.systemFont(ofSize: 40, weight: .medium)
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
    
    // MARK: - Properties
    
    private var timer: Timer?
    private var calendar = Calendar.current
    
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
        
        contentStackView.addArrangedSubview(timeLabel)
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
        let showDate: Bool
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockShowDate) != nil {
            showDate = UserDefaults.standard.bool(forKey: AppConstants.Keys.kClockShowDate)
        } else {
            showDate = AppConstants.Defaults.clockShowDate
        }
        dateLabel.isHidden = !showDate
        
        let theme: Int
        if UserDefaults.standard.object(forKey: AppConstants.Keys.kClockTheme) != nil {
            theme = UserDefaults.standard.integer(forKey: AppConstants.Keys.kClockTheme)
        } else {
            theme = AppConstants.Defaults.clockTheme
        }
        
        if theme == 1 {
            // Analog Mode
            timeLabel.isHidden = true
            setupAnalogClockIfNeeded()
            analogClock?.isHidden = false
        } else {
            // Digital Mode
            timeLabel.isHidden = false
            analogClock?.isHidden = true
        }
        
        // Refresh immediately
        updateTime()
    }
    
    private func setupAnalogClockIfNeeded() {
        if analogClock == nil {
            let clock = AnalogClockView(frame: .zero)
            clock.translatesAutoresizingMaskIntoConstraints = false
            clock.backgroundColor = .clear
            
            // Insert at index 0 (top)
            contentStackView.insertArrangedSubview(clock, at: 0)
            self.analogClock = clock
            
            NSLayoutConstraint.activate([
                // Constrain clock width to be within reasonable bounds relative to the screen size to prevent overflow
                clock.widthAnchor.constraint(lessThanOrEqualTo: containerView.widthAnchor, multiplier: 0.6),
                clock.heightAnchor.constraint(lessThanOrEqualTo: containerView.heightAnchor, multiplier: 0.6),
                clock.widthAnchor.constraint(equalTo: clock.heightAnchor),
                
                // Priority constraints to make it as large as allowed
                clock.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.6).prioritized(.defaultHigh)
            ])
            
            // Adjust constraints based on what's visible
            setNeedsLayout()
        }
    }
    
    @objc private func updateTime() {
        let now = Date()
        
        // Update Analog Clock if visible
        if let analog = analogClock, !analog.isHidden {
            analog.updateTime()
        }
        
        // Always update digital components as they might be toggled visible
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
        
        // Time Format
        let timeFormatter = DateFormatter()
        if is24Hour {
            timeFormatter.dateFormat = showSeconds ? "HH:mm:ss" : "HH:mm"
        } else {
            timeFormatter.dateFormat = showSeconds ? "h:mm:ss a" : "h:mm a"
        }
        let timeString = timeFormatter.string(from: now)
        
        // Apply letter spacing for better readability (kern is available in iOS 12+)
        let attributedString = NSMutableAttributedString(string: timeString)
        attributedString.addAttribute(.kern, value: 2.0, range: NSRange(location: 0, length: timeString.count))
        timeLabel.attributedText = attributedString
        
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
    
    // Adjust font size for iPad vs iPhone if needed, or rely on Auto Layout scaling?
    // Let's make it slightly adaptive based on trait collection or screen size
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Calculate font size dynamically based on the smaller dimension to fit in landscape
        let minDimension = min(bounds.width, bounds.height)
        let isPad = traitCollection.userInterfaceIdiom == .pad
        
        // Dynamic font size: roughly 20% of screen min dimension for time, but clamped
        let targetTimeSize = minDimension * (isPad ? 0.3 : 0.4)
        let clampedTimeSize = max(50, min(targetTimeSize, isPad ? 250 : 160))
        
        let targetDateSize = clampedTimeSize * 0.25
        let clampedDateSize = max(16, min(targetDateSize, isPad ? 50 : 30))
        
        if timeLabel.font.pointSize != clampedTimeSize {
            // Update font with better styling
            if #available(iOS 13.0, *) {
                // Use SF Rounded with medium weight
                let font = UIFont.systemFont(ofSize: clampedTimeSize, weight: .medium)
                let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
                timeLabel.font = UIFont(descriptor: descriptor, size: clampedTimeSize)
                
                // Update date label with SF Rounded
                let dateFont = UIFont.systemFont(ofSize: clampedDateSize, weight: .medium)
                let dateDescriptor = dateFont.fontDescriptor.withDesign(.rounded) ?? dateFont.fontDescriptor
                dateLabel.font = UIFont(descriptor: dateDescriptor, size: clampedDateSize)
            } else {
                // Fallback to monospaced digit font for iOS 12
                timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: clampedTimeSize, weight: .medium)
                dateLabel.font = UIFont.systemFont(ofSize: clampedDateSize, weight: .medium)
            }
        }
    }
}
