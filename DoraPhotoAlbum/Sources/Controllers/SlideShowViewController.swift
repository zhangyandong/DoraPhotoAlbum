import UIKit
import AVFoundation
import CoreLocation
import Photos
import MediaPlayer

class SlideShowViewController: UIViewController {
    
    // MARK: - Constants
    
    private enum Constants {
        static let transitionDuration: TimeInterval = 1.0
        static let fadeDuration: TimeInterval = 0.3
        static let videoHideDuration: TimeInterval = 0.5
        static let controlsAutoHideDelay: TimeInterval = 10.0
        static let defaultDisplayDuration: TimeInterval = 10.0
        static let kenBurnsScaleRange: ClosedRange<CGFloat> = 1.05...1.15
        static let kenBurnsSafetyFactor: CGFloat = 0.8
        static let heartAnimationDuration: TimeInterval = 0.3
        static let heartScale: CGFloat = 1.3
        static let dashboardBottomInset: CGFloat = 20
        static let controlsBottomInset: CGFloat = 30
        static let controlsTrailingInset: CGFloat = 30
        static let controlsSpacing: CGFloat = 40
        static let dashboardWidth: CGFloat = 200
        static let buttonSymbolSize: CGFloat = 30
        static let heartSize: CGFloat = 100
    }
    
    // MARK: - Public Properties
    
    var items: [UnifiedMediaItem] = []
    var currentIndex = 0
    var displayDuration: TimeInterval = Constants.defaultDisplayDuration
    var videoMaxDuration: TimeInterval = 0 // 0 means no limit
    var isVideoMuted: Bool = false // Default to false (not muted) - will be loaded from UserDefaults
    var playMusicWithVideo: Bool = false // 是否在视频播放时继续背景音乐
    var contentMode: UIView.ContentMode = .scaleAspectFill
    
    // MARK: - Private Properties
    
    // 当前会话内的背景音乐状态，只影响本次运行，不写入 UserDefaults
    private var isBackgroundMusicOn: Bool = false
    
    private var frontImageView: UIImageView!
    private var backImageView: UIImageView!
    private var videoLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var timer: Timer?
    private var currentImageRequestId: PHImageRequestID?
    private var wasMusicPlayingBeforeVideo: Bool = false
    private var dashboardView: DashboardView?
    private var controlsView: UIView?
    private var controlsTimer: Timer?
    
    // MARK: - Lifecycle
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadSettings()
        setupUI()
        setupInitialMusicState()
    }
    
    private func loadSettings() {
        let savedDuration = UserDefaults.standard.double(forKey: AppConstants.Keys.kDisplayDuration)
        if savedDuration > 0 {
            displayDuration = savedDuration
        }
        
        videoMaxDuration = UserDefaults.standard.double(forKey: AppConstants.Keys.kVideoMaxDuration)
        isVideoMuted = UserDefaults.standard.object(forKey: AppConstants.Keys.kVideoMuted) as? Bool ?? false
        playMusicWithVideo = UserDefaults.standard.bool(forKey: AppConstants.Keys.kPlayMusicWithVideo)
        
        let contentModeIndex = UserDefaults.standard.integer(forKey: AppConstants.Keys.kContentMode)
        contentMode = (contentModeIndex == 1) ? .scaleAspectFit : .scaleAspectFill
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        setupViews()
        setupDashboard()
        setupGestures()
    }
    
    private func setupInitialMusicState() {
        if UserDefaults.standard.bool(forKey: AppConstants.Keys.kPlayBackgroundMusic) {
            MusicService.shared.setupMusic()
        }
        isBackgroundMusicOn = MusicService.shared.isPlaying
    }
    
    // MARK: - UI Setup
    
    private func setupDashboard() {
        let dashboard = DashboardView(frame: .zero)
        dashboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dashboard)
        self.dashboardView = dashboard
        
        NSLayoutConstraint.activate([
            dashboard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Constants.dashboardBottomInset),
            dashboard.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.dashboardBottomInset),
            dashboard.widthAnchor.constraint(equalToConstant: adaptiveDashboardWidth())
        ])
        
        setupControls()
    }
    
    private func setupControls() {
        let controls = UIView()
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.alpha = 0 // Initially hidden
        view.addSubview(controls)
        self.controlsView = controls
        
        let musicBtn = createControlButton(systemName: "music.note", title: "Music", action: #selector(toggleBackgroundMusic))
        let videoSoundBtn = createControlButton(systemName: "speaker.wave.2.fill", title: "Video", action: #selector(toggleVideoSound))
        let settingsBtn = createControlButton(systemName: "gearshape.fill", title: "Settings", action: #selector(openSettings))
        let closeBtn = createControlButton(systemName: "xmark.circle.fill", title: "Close", action: #selector(closeSlideshow))
        
        let stack = UIStackView(arrangedSubviews: [musicBtn, videoSoundBtn, settingsBtn, closeBtn])
        stack.axis = .horizontal
        let isPad = traitCollection.userInterfaceIdiom == .pad
        stack.spacing = isPad ? Constants.controlsSpacing : Constants.controlsSpacing * 0.6
        stack.translatesAutoresizingMaskIntoConstraints = false
        controls.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: controls.topAnchor),
            stack.bottomAnchor.constraint(equalTo: controls.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: controls.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: controls.trailingAnchor),
            
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Constants.controlsBottomInset),
            controls.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.controlsTrailingInset)
        ])
    }

    private func adaptiveDashboardWidth() -> CGFloat {
        let isPad = traitCollection.userInterfaceIdiom == .pad
        if isPad { return Constants.dashboardWidth }
        // For phones, limit to 55% of screen width, but not exceeding default width
        return min(Constants.dashboardWidth, view.bounds.width * 0.55)
    }
    
    private func createControlButton(systemName: String, title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let size = isPad ? Constants.buttonSymbolSize : Constants.buttonSymbolSize * 0.8
        
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium, scale: .large)
            button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        } else {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: size, weight: .bold)
        }
        
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    // MARK: - Actions
    
    @objc private func closeSlideshow() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        settingsVC.onSave = { [weak self] in
            self?.reloadSettings()
        }
        let nav = UINavigationController(rootViewController: settingsVC)
        if traitCollection.userInterfaceIdiom == .pad {
            nav.modalPresentationStyle = .formSheet
        } else {
            nav.modalPresentationStyle = .fullScreen
        }
        present(nav, animated: true, completion: nil)
    }
    
    private func reloadSettings() {
        loadSettings()
        
        // Update current player if playing
        player?.isMuted = isVideoMuted
        
        // 同步当前会话内背景音乐状态（不改 UserDefaults，只读当前播放状态）
        isBackgroundMusicOn = MusicService.shared.isPlaying
        
        // Update music playback based on settings
        let shouldPlayMusic = UserDefaults.standard.bool(forKey: AppConstants.Keys.kPlayBackgroundMusic)
        if shouldPlayMusic {
            MusicService.shared.setupMusic()
        } else {
            MusicService.shared.stop()
        }
        
        // Apply content mode to visible view immediately
        updateVisibleImageViewContentMode()
    }
    
    private func updateVisibleImageViewContentMode() {
        if frontImageView.alpha > 0 {
            frontImageView.contentMode = contentMode
        } else {
            backImageView.contentMode = contentMode
        }
    }
    
    /// 切换背景音乐开关（只影响当前会话，不修改 UserDefaults）
    @objc private func toggleBackgroundMusic() {
        isBackgroundMusicOn.toggle()
        if isBackgroundMusicOn {
            MusicService.shared.play()
        } else {
            MusicService.shared.pause()
        }
    }
    
    /// 切换当前会话内的视频声音（只改内存状态，不改缓存）
    @objc private func toggleVideoSound() {
        isVideoMuted.toggle()
        player?.isMuted = isVideoMuted
    }
    
    // MARK: - Gestures
    
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
        
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleVerticalSwipe(_:)))
        swipeUp.direction = .up
        view.addGestureRecognizer(swipeUp)
        
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleVerticalSwipe(_:)))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
    }
    
    @objc private func handleVerticalSwipe(_ gesture: UISwipeGestureRecognizer) {
        let targetAlpha: CGFloat = (gesture.direction == .down) ? 0 : 1
        UIView.animate(withDuration: Constants.fadeDuration) {
            self.dashboardView?.alpha = targetAlpha
        }
    }
    
    @objc private func handleDoubleTap() {
        showHeartAnimation()
    }
    
    private func showHeartAnimation() {
        let heart = UIImageView()
        if #available(iOS 13.0, *) {
            heart.image = UIImage(systemName: "heart.fill")
            heart.tintColor = .red
        }
        
        heart.frame = CGRect(x: 0, y: 0, width: Constants.heartSize, height: Constants.heartSize)
        heart.center = view.center
        heart.alpha = 0
        view.addSubview(heart)
        
        UIView.animate(withDuration: Constants.heartAnimationDuration, animations: {
            heart.alpha = 1
            heart.transform = CGAffineTransform(scaleX: Constants.heartScale, y: Constants.heartScale)
        }) { _ in
            UIView.animate(withDuration: Constants.heartAnimationDuration, delay: 0.2, options: [], animations: {
                heart.alpha = 0
                heart.transform = .identity
            }) { _ in
                heart.removeFromSuperview()
            }
        }
        // TODO: Save 'favorite' state to UserDefaults
    }
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        stopVideo()
        timer?.invalidate()
        
        if gesture.direction == .left {
            showNextItem()
        } else if gesture.direction == .right {
            currentIndex = (currentIndex - 2 + items.count) % items.count
            showNextItem()
        }
    }
    
    // MARK: - Dashboard Updates
    
    private func updateDashboard(for item: UnifiedMediaItem) {
        dashboardView?.updateFileType(item.type)
        
        var locName: String? = item.locationName
        
        if let asset = item.localAsset, let loc = asset.location, locName == nil {
            CLGeocoder().reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
                locName = placemarks?.first?.locality
                DispatchQueue.main.async {
                    self?.dashboardView?.updatePhotoMeta(date: item.creationDate, location: locName)
                }
            }
        } else {
            dashboardView?.updatePhotoMeta(date: item.creationDate, location: locName)
        }
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSlideShow()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanup()
    }
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil
        controlsTimer?.invalidate()
        controlsTimer = nil
        stopVideo(resumeMusic: false)
        MusicService.shared.stop()
        cancelImageRequest()
    }
    
    private func cancelImageRequest() {
        if let requestId = currentImageRequestId {
            PHImageManager.default().cancelImageRequest(requestId)
            currentImageRequestId = nil
        }
    }
    
    private func setupViews() {
        backImageView = UIImageView(frame: view.bounds)
        backImageView.contentMode = contentMode
        backImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backImageView)
        
        frontImageView = UIImageView(frame: view.bounds)
        frontImageView.contentMode = contentMode
        frontImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        frontImageView.alpha = 0
        view.addSubview(frontImageView)
    }
    
    // MARK: - Slide Show Control
    
    func startSlideShow() {
        guard !items.isEmpty else {
            print("No items to show")
            return
        }
        showNextItem()
    }
    
    @objc private func handleTap() {
        guard let controls = controlsView else { return }
        
        controlsTimer?.invalidate()
        
        let targetAlpha: CGFloat = (controls.alpha == 0) ? 1.0 : 0.0
        
        UIView.animate(withDuration: Constants.fadeDuration) {
            controls.alpha = targetAlpha
        } completion: { [weak self] _ in
            if targetAlpha == 1.0 {
                self?.startControlsTimer()
            }
        }
    }
    
    private func startControlsTimer() {
        controlsTimer = Timer.scheduledTimer(withTimeInterval: Constants.controlsAutoHideDelay, repeats: false) { [weak self] _ in
            guard let self = self, let controls = self.controlsView else { return }
            if controls.alpha == 1 {
                UIView.animate(withDuration: Constants.fadeDuration) {
                    controls.alpha = 0
                }
            }
        }
    }
    
    private func showNextItem() {
        guard !items.isEmpty else { return }
        
        if currentIndex >= items.count {
            currentIndex = 0
        }
        
        let item = items[currentIndex]
        currentIndex += 1
        
        if item.type == .video {
            playVideo(item: item)
        } else {
            showImage(item: item)
        }
    }
    
    // MARK: - Image Display
    
    private func showImage(item: UnifiedMediaItem) {
        updateDashboard(for: item)
        stopVideo()
        cancelImageRequest()
        
        prepareImageViewsForTransition()
        
        let phContentMode: PHImageContentMode = (contentMode == .scaleAspectFit) ? .aspectFit : .aspectFill
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        
        currentImageRequestId = PhotoService.shared.requestImage(for: item, targetSize: targetSize, contentMode: phContentMode) { [weak self] image in
            guard let self = self else { return }
            self.currentImageRequestId = nil
            
            guard let image = image else {
                DispatchQueue.main.async {
                    self.showNextItem()
                }
                return
            }
            
            DispatchQueue.main.async {
                self.displayImage(image)
            }
        }
    }
    
    private func prepareImageViewsForTransition() {
        // If both imageViews are hidden (coming from video), clear old images and reset state
        if frontImageView.alpha == 0 && backImageView.alpha == 0 {
            frontImageView.image = nil
            backImageView.image = nil
            frontImageView.transform = .identity
            backImageView.transform = .identity
            backImageView.alpha = 0
        }
    }
    
    private func displayImage(_ image: UIImage) {
        guard let frontImageView = frontImageView, let backImageView = backImageView else { return }
        
        let incomingView = (frontImageView.alpha == 0) ? frontImageView : backImageView
        let outgoingView = (incomingView == frontImageView) ? backImageView : frontImageView
        
        incomingView.image = image
        incomingView.contentMode = contentMode
        incomingView.transform = .identity
        incomingView.alpha = 0
        outgoingView.alpha = 1
        
        performTransition(incoming: incomingView, outgoing: outgoingView)
        scheduleNextItem()
    }
    
    private func scheduleNextItem() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.showNextItem()
        }
    }
    
    private func performTransition(incoming: UIView, outgoing: UIView) {
        // Ensure initial state
        incoming.alpha = 0
        outgoing.alpha = 1
        incoming.transform = .identity
        
        // Start Ken Burns animation on incoming view
        let animationDuration = displayDuration + Constants.transitionDuration
        startKenBurns(view: incoming, duration: animationDuration, startRandomly: true)
        
        // Fade transition
        UIView.animate(withDuration: Constants.transitionDuration, animations: {
            incoming.alpha = 1
            outgoing.alpha = 0
        }) { _ in
            // Reset outgoing transform only after it's fully hidden
            outgoing.transform = .identity
        }
    }
    
    // MARK: - Ken Burns Animation
    
    private func startKenBurns(view: UIView, duration: TimeInterval, startRandomly: Bool) {
        let endScale = CGFloat.random(in: Constants.kenBurnsScaleRange)
        
        if startRandomly {
            let startScale = CGFloat.random(in: Constants.kenBurnsScaleRange)
            let startTranslation = randomTranslation(for: startScale, in: view.bounds.size)
            // Apply scale then translate. Since translatedBy applies to the existing transform (scale),
            // we need to divide dx by s to get desired screen translation.
            let startTransform = CGAffineTransform(scaleX: startScale, y: startScale)
                .translatedBy(x: startTranslation.x / startScale, y: startTranslation.y / startScale)
            view.transform = startTransform
        }
        
        let endTranslation = randomTranslation(for: endScale, in: view.bounds.size)
        let endTransform = CGAffineTransform(scaleX: endScale, y: endScale)
            .translatedBy(x: endTranslation.x / endScale, y: endTranslation.y / endScale)

        UIView.animate(withDuration: duration, delay: 0, options: .curveLinear, animations: {
            view.transform = endTransform
        }, completion: nil)
    }
    
    private func randomTranslation(for scale: CGFloat, in size: CGSize) -> CGPoint {
        guard scale > 1.0 else { return .zero }
        
        let maxOffX = ((size.width * scale - size.width) / 2) * Constants.kenBurnsSafetyFactor
        let maxOffY = ((size.height * scale - size.height) / 2) * Constants.kenBurnsSafetyFactor
        
        return CGPoint(
            x: CGFloat.random(in: -maxOffX...maxOffX),
            y: CGFloat.random(in: -maxOffY...maxOffY)
        )
    }
    
    // MARK: - Video Playback
    
    private func playVideo(item: UnifiedMediaItem) {
        updateDashboard(for: item)
        captureMusicStateBeforeVideo()
        stopVideo(resumeMusic: false)
        
        PhotoService.shared.requestPlayerItem(for: item) { [weak self] playerItem in
            guard let self = self, let playerItem = playerItem else {
                print("SlideShowViewController: Failed to load video, skipping to next")
                DispatchQueue.main.async {
                    self?.showNextItem()
                }
                return
            }
            DispatchQueue.main.async {
                self.setupAndPlayVideo(item: playerItem)
            }
        }
    }
    
    private func captureMusicStateBeforeVideo() {
        guard player == nil else { return }
        
        if !playMusicWithVideo {
            wasMusicPlayingBeforeVideo = isBackgroundMusicOn
        } else {
            wasMusicPlayingBeforeVideo = false
        }
    }
    
    private func setupAndPlayVideo(item: AVPlayerItem) {
        player = AVPlayer(playerItem: item)
        player?.isMuted = isVideoMuted
        
        videoLayer = AVPlayerLayer(player: player)
        videoLayer?.frame = view.bounds
        videoLayer?.videoGravity = .resizeAspect
        videoLayer?.backgroundColor = UIColor.black.cgColor
        
        hideImageViewsForVideo()
        
        if let layer = videoLayer {
            view.layer.addSublayer(layer)
        }
        
        bringUIElementsToFront()
        handleMusicDuringVideo()
        
        player?.play()
        observeVideoCompletion(item: item)
        scheduleVideoMaxDuration()
    }
    
    private func hideImageViewsForVideo() {
        UIView.animate(withDuration: Constants.videoHideDuration) {
            self.frontImageView.alpha = 0
            self.backImageView.alpha = 0
        }
    }
    
    private func bringUIElementsToFront() {
        if let dashboard = dashboardView {
            view.bringSubviewToFront(dashboard)
        }
        if let controls = controlsView {
            view.bringSubviewToFront(controls)
        }
    }
    
    private func handleMusicDuringVideo() {
        // 仅在用户设置为"视频时不继续背景音乐"时，暂时暂停背景音乐
        if !playMusicWithVideo && isBackgroundMusicOn {
            MusicService.shared.pause()
            isBackgroundMusicOn = false
        }
    }
    
    private func observeVideoCompletion(item: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }
    
    private func scheduleVideoMaxDuration() {
        timer?.invalidate()
        if videoMaxDuration > 0 {
            timer = Timer.scheduledTimer(withTimeInterval: videoMaxDuration, repeats: false) { [weak self] _ in
                self?.videoDidFinish()
            }
        }
    }
    
    @objc private func videoDidFinish() {
        stopVideo()
        showNextItem()
    }
    
    private func stopVideo(resumeMusic: Bool = true) {
        player?.pause()
        player = nil
        videoLayer?.removeFromSuperlayer()
        videoLayer = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        resumeMusicAfterVideo(resumeMusic: resumeMusic)
    }
    
    private func resumeMusicAfterVideo(resumeMusic: Bool) {
        if playMusicWithVideo {
            // 如果允许"视频期间继续背景音乐"：根据当前会话内开关状态决定是否确保音乐在播放
            if isBackgroundMusicOn {
                MusicService.shared.play()
            }
            return
        }
        
        // 如果不允许一起播放：仅当进入视频前本来在播放时才恢复
        if resumeMusic && wasMusicPlayingBeforeVideo {
            MusicService.shared.play()
            isBackgroundMusicOn = true
        }
    }
}

