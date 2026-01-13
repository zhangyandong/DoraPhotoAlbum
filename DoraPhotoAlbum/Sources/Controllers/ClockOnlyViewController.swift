import UIKit

/// Dedicated pure-clock screen. This is intentionally separated from `SlideShowViewController`.
final class ClockOnlyViewController: UIViewController {
    
    private var clockView: ClockOverlayView?
    private var controlsView: SlideshowControlsView?
    private let backgroundView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let vignetteLayer = CAGradientLayer()
    
    override var prefersStatusBarHidden: Bool { true }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupBackground()
        setupClock()
        setupControls()
        setupGestures()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleSleepModeChanged), name: .sleepModeChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        clockView?.stopUpdating()
    }
    
    private func setupBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        backgroundView.backgroundColor = UIColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 1.0)
        
        // Base gradient (subtle, modern "display" feel)
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradientLayer.colors = [
            UIColor(red: 0.12, green: 0.14, blue: 0.30, alpha: 1.0).cgColor, // deep navy
            UIColor(red: 0.06, green: 0.06, blue: 0.16, alpha: 1.0).cgColor, // dark blue
            UIColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1.0).cgColor  // near-black
        ]
        gradientLayer.locations = [0.0, 0.6, 1.0]
        backgroundView.layer.addSublayer(gradientLayer)
        
        // Vignette (darkens edges for readability, avoids "flat black")
        vignetteLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        vignetteLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        vignetteLayer.colors = [
            UIColor(white: 0.0, alpha: 0.35).cgColor,
            UIColor(white: 0.0, alpha: 0.06).cgColor,
            UIColor(white: 0.0, alpha: 0.40).cgColor
        ]
        vignetteLayer.locations = [0.0, 0.5, 1.0]
        backgroundView.layer.addSublayer(vignetteLayer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = backgroundView.bounds
        vignetteLayer.frame = backgroundView.bounds
    }
    
    private func setupClock() {
        let clock = ClockOverlayView()
        // Let the custom gradient background show through.
        clock.setDimBackgroundEnabled(false)
        clock.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clock)
        self.clockView = clock
        
        NSLayoutConstraint.activate([
            clock.topAnchor.constraint(equalTo: view.topAnchor),
            clock.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            clock.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            clock.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupControls() {
        let controls = SlideshowControlsView()
        controls.delegate = self
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)
        self.controlsView = controls
        
        // Pure clock mode: hide media-specific controls.
        controls.setClockOnlyMode(true)
        
        NSLayoutConstraint.activate([
            controls.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            controls.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        clockView?.startUpdating()
        controlsView?.showTemporarily(delay: 6.0)
        startBackgroundBreathingIfNeeded()
    }
    
    private func startBackgroundBreathingIfNeeded() {
        // Very subtle color drift to make the screen feel less static (and reduce burn-in).
        // Safe for iOS 12 (CABasicAnimation is available).
        let anim = CABasicAnimation(keyPath: "colors")
        anim.duration = 10.0
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.toValue = [
            UIColor(red: 0.16, green: 0.12, blue: 0.30, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.06, blue: 0.18, alpha: 1.0).cgColor,
            UIColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1.0).cgColor
        ]
        // Avoid stacking animations
        if gradientLayer.animation(forKey: "breathing") == nil {
            gradientLayer.add(anim, forKey: "breathing")
        }
    }
    
    @objc private func handleTap() {
        controlsView?.toggleVisibility()
    }
    
    @objc private func handleSleepModeChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isSleeping = userInfo["isSleeping"] as? Bool else {
            return
        }
        // When sleeping, stop the clock timer to reduce work; resume when waking.
        if isSleeping {
            clockView?.stopUpdating()
        } else {
            clockView?.startUpdating()
        }
    }
}

extension ClockOnlyViewController: SlideshowControlsViewDelegate {
    func slideshowControlsViewDidTapPlayPause(_ view: SlideshowControlsView) { }
    func slideshowControlsViewDidTapMusic(_ view: SlideshowControlsView) { }
    func slideshowControlsViewDidTapVideoSound(_ view: SlideshowControlsView) { }
    
    func slideshowControlsViewDidTapClock(_ view: SlideshowControlsView) {
        // In pure clock VC, this button is hidden by setClockOnlyMode(true).
    }
    
    func slideshowControlsViewDidTapSettings(_ view: SlideshowControlsView) {
        let settingsVC = SettingsViewController()
        let nav = UINavigationController(rootViewController: settingsVC)
        if traitCollection.userInterfaceIdiom == .pad {
            nav.modalPresentationStyle = .formSheet
        } else {
            nav.modalPresentationStyle = .fullScreen
        }
        present(nav, animated: true)
    }
    
    func slideshowControlsViewDidTapClose(_ view: SlideshowControlsView) {
        dismiss(animated: true)
    }
}

