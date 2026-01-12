import UIKit

/// Control panel view for slideshow
class SlideshowControlsView: UIView {
    
    weak var delegate: SlideshowControlsViewDelegate?
    
    private let stackView: UIStackView
    private let containerView = UIView()
    private var blurView: UIVisualEffectView?
    private let backgroundView = UIView()
    private var playPauseButton: UIButton?
    private var musicButton: UIButton?
    private var videoSoundButton: UIButton?
    private var clockButton: UIButton?
    private var settingsButton: UIButton?
    private var closeButton: UIButton?
    private var autoHideTimer: Timer?
    
    private enum Constants {
        static let autoHideDelay: TimeInterval = 10.0
        static let fadeDuration: TimeInterval = 0.3
        static let controlsBottomInset: CGFloat = 30
        static let controlsTrailingInset: CGFloat = 30
        static let controlsSpacing: CGFloat = 50 // Increased spacing for iPad
        static let controlsSpacingPhone: CGFloat = 30 // Increased spacing for phones
        static let buttonSymbolSize: CGFloat = 30
        static let containerCornerRadius: CGFloat = 26
        static let containerPaddingX: CGFloat = 14
        static let containerPaddingY: CGFloat = 10
    }
    
    override init(frame: CGRect) {
        stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set spacing based on device type
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        stackView.spacing = isPad ? Constants.controlsSpacingPhone : Constants.controlsSpacingPhone
        stackView.alignment = .center
        
        super.init(frame: frame)
        
        translatesAutoresizingMaskIntoConstraints = false
        alpha = 0 // Initially hidden
        isUserInteractionEnabled = true
        
        setupButtons()
        setupContainer()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupButtons() {
        let playPauseBtn = createButton(systemName: "pause.fill", title: "Pause", accessibilityLabel: "播放/暂停", action: #selector(playPauseTapped))
        playPauseButton = playPauseBtn
        
        let musicBtn = createButton(systemName: "music.note", title: "Music", accessibilityLabel: "背景音乐", action: #selector(musicTapped))
        let videoSoundBtn = createButton(systemName: "speaker.wave.2.fill", title: "Video", accessibilityLabel: "视频声音", action: #selector(videoSoundTapped))
        let clockBtn = createButton(systemName: "clock.fill", title: "Clock", accessibilityLabel: "时钟", action: #selector(clockTapped))
        let settingsBtn = createButton(systemName: "gearshape.fill", title: "Settings", accessibilityLabel: "设置", action: #selector(settingsTapped))
        let closeBtn = createButton(systemName: "xmark", title: "Close", accessibilityLabel: "关闭", action: #selector(closeTapped))
        
        musicButton = musicBtn
        videoSoundButton = videoSoundBtn
        clockButton = clockBtn
        settingsButton = settingsBtn
        closeButton = closeBtn
        
        stackView.addArrangedSubview(playPauseBtn)
        stackView.addArrangedSubview(musicBtn)
        stackView.addArrangedSubview(videoSoundBtn)
        stackView.addArrangedSubview(clockBtn)
        stackView.addArrangedSubview(settingsBtn)
        stackView.addArrangedSubview(closeBtn)
    }
    
    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = Constants.containerCornerRadius
        containerView.layer.masksToBounds = true
        
        // Background: blur if available, otherwise translucent dark
        if #available(iOS 13.0, *) {
            let blur = UIBlurEffect(style: .systemThinMaterialDark)
            let bv = UIVisualEffectView(effect: blur)
            bv.translatesAutoresizingMaskIntoConstraints = false
            blurView = bv
            containerView.addSubview(bv)
            NSLayoutConstraint.activate([
                bv.topAnchor.constraint(equalTo: containerView.topAnchor),
                bv.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                bv.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                bv.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
        } else {
            backgroundView.backgroundColor = UIColor(white: 0.0, alpha: 0.55)
            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(backgroundView)
            NSLayoutConstraint.activate([
                backgroundView.topAnchor.constraint(equalTo: containerView.topAnchor),
                backgroundView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                backgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                backgroundView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
        }
        
        containerView.addSubview(stackView)
        addSubview(containerView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Constants.containerPaddingY),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Constants.containerPaddingY),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Constants.containerPaddingX),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Constants.containerPaddingX)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    private func createButton(systemName: String, title: String, accessibilityLabel: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityTraits = .button
        
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let size = isPad ? Constants.buttonSymbolSize : Constants.buttonSymbolSize * 0.85
        let hitSize: CGFloat = isPad ? 56 : 50
        let iconBgSize: CGFloat = isPad ? 44 : 42
        
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium, scale: .large)
            button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        } else {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: size, weight: .bold)
        }
        
        // Make a circular-ish icon background inside the pill for better affordance.
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.16)
        button.layer.cornerRadius = iconBgSize / 2
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: iconBgSize),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: iconBgSize),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: hitSize).prioritized(.defaultLow),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: hitSize).prioritized(.defaultLow)
        ])
        
        return button
    }
    
    // MARK: - Public Methods
    
    /// When `true`, hide controls that don't make sense without media items (pure clock mode).
    /// Hidden arranged subviews are automatically removed from UIStackView layout.
    func setClockOnlyMode(_ enabled: Bool) {
        playPauseButton?.isHidden = enabled
        videoSoundButton?.isHidden = enabled
        clockButton?.isHidden = enabled
        
        // Keep music/settings/close available.
        musicButton?.isHidden = false
        settingsButton?.isHidden = false
        closeButton?.isHidden = false
    }
    
    func updatePlayPauseButton(isPaused: Bool) {
        guard let button = playPauseButton else { return }
        
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let size = isPad ? Constants.buttonSymbolSize : Constants.buttonSymbolSize * 0.8
        
        if isPaused {
            if #available(iOS 13.0, *) {
                let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium, scale: .large)
                button.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
            } else {
                button.setTitle("Play", for: .normal)
            }
        } else {
            if #available(iOS 13.0, *) {
                let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium, scale: .large)
                button.setImage(UIImage(systemName: "pause.fill", withConfiguration: config), for: .normal)
            } else {
                button.setTitle("Pause", for: .normal)
            }
        }
    }
    
    func toggleVisibility() {
        autoHideTimer?.invalidate()
        
        let targetAlpha: CGFloat = (alpha == 0) ? 1.0 : 0.0
        
        UIView.animate(withDuration: Constants.fadeDuration) {
            self.alpha = targetAlpha
            self.transform = (targetAlpha == 1.0) ? .identity : CGAffineTransform(translationX: 0, y: 8)
        } completion: { [weak self] _ in
            if targetAlpha == 1.0 {
                self?.startAutoHideTimer()
            }
        }
    }
    
    func showTemporarily(delay: TimeInterval? = nil) {
        autoHideTimer?.invalidate()
        let d = delay ?? Constants.autoHideDelay
        if alpha == 0 {
            transform = CGAffineTransform(translationX: 0, y: 8)
        }
        UIView.animate(withDuration: Constants.fadeDuration) {
            self.alpha = 1.0
            self.transform = .identity
        } completion: { [weak self] _ in
            self?.autoHideTimer = Timer.scheduledTimer(withTimeInterval: d, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.alpha == 1 {
                    UIView.animate(withDuration: Constants.fadeDuration) {
                        self.alpha = 0
                        self.transform = CGAffineTransform(translationX: 0, y: 8)
                    }
                }
            }
        }
    }
    
    private func startAutoHideTimer() {
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: Constants.autoHideDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.alpha == 1 {
                UIView.animate(withDuration: Constants.fadeDuration) {
                    self.alpha = 0
                    self.transform = CGAffineTransform(translationX: 0, y: 8)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func playPauseTapped() {
        delegate?.slideshowControlsViewDidTapPlayPause(self)
    }
    
    @objc private func musicTapped() {
        delegate?.slideshowControlsViewDidTapMusic(self)
    }
    
    @objc private func videoSoundTapped() {
        delegate?.slideshowControlsViewDidTapVideoSound(self)
    }
    
    @objc private func clockTapped() {
        delegate?.slideshowControlsViewDidTapClock(self)
    }
    
    @objc private func settingsTapped() {
        delegate?.slideshowControlsViewDidTapSettings(self)
    }
    
    @objc private func closeTapped() {
        delegate?.slideshowControlsViewDidTapClose(self)
    }
    
    deinit {
        autoHideTimer?.invalidate()
    }
}

// MARK: - SlideshowControlsViewDelegate

protocol SlideshowControlsViewDelegate: AnyObject {
    func slideshowControlsViewDidTapPlayPause(_ view: SlideshowControlsView)
    func slideshowControlsViewDidTapMusic(_ view: SlideshowControlsView)
    func slideshowControlsViewDidTapVideoSound(_ view: SlideshowControlsView)
    func slideshowControlsViewDidTapClock(_ view: SlideshowControlsView)
    func slideshowControlsViewDidTapSettings(_ view: SlideshowControlsView)
    func slideshowControlsViewDidTapClose(_ view: SlideshowControlsView)
}

