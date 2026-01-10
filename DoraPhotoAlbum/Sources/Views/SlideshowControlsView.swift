import UIKit

/// Control panel view for slideshow
class SlideshowControlsView: UIView {
    
    weak var delegate: SlideshowControlsViewDelegate?
    
    private let stackView: UIStackView
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
    }
    
    override init(frame: CGRect) {
        stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set spacing based on device type
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        stackView.spacing = isPad ? Constants.controlsSpacing : Constants.controlsSpacingPhone
        
        super.init(frame: frame)
        
        translatesAutoresizingMaskIntoConstraints = false
        alpha = 0 // Initially hidden
        
        setupButtons()
        addSubview(stackView)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupButtons() {
        let playPauseBtn = createButton(systemName: "pause.fill", title: "Pause", action: #selector(playPauseTapped))
        playPauseButton = playPauseBtn
        
        let musicBtn = createButton(systemName: "music.note", title: "Music", action: #selector(musicTapped))
        let videoSoundBtn = createButton(systemName: "speaker.wave.2.fill", title: "Video", action: #selector(videoSoundTapped))
        let clockBtn = createButton(systemName: "clock.fill", title: "Clock", action: #selector(clockTapped))
        let settingsBtn = createButton(systemName: "gearshape.fill", title: "Settings", action: #selector(settingsTapped))
        let closeBtn = createButton(systemName: "xmark.circle.fill", title: "Close", action: #selector(closeTapped))
        
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
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    private func createButton(systemName: String, title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let size = isPad ? Constants.buttonSymbolSize : Constants.buttonSymbolSize * 0.8
        
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium, scale: .large)
            button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        } else {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: size, weight: .bold)
        }
        
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
        } completion: { [weak self] _ in
            if targetAlpha == 1.0 {
                self?.startAutoHideTimer()
            }
        }
    }
    
    private func startAutoHideTimer() {
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: Constants.autoHideDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.alpha == 1 {
                UIView.animate(withDuration: Constants.fadeDuration) {
                    self.alpha = 0
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

