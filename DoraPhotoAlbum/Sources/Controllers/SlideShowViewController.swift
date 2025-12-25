import UIKit
import AVFoundation
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
    var isBackgroundMusicOn: Bool = false
    
    private var frontImageView: UIImageView!
    private var backImageView: UIImageView!
    private var timer: Timer?
    var wasMusicPlayingBeforeVideo: Bool = false
    private var dashboardView: DashboardView?
    private var controlsView: SlideshowControlsView?
    private var clockOverlayView: ClockOverlayView?
    var isClockMode: Bool = false
    private var isPaused: Bool = false
    private var wasPausedByUser: Bool = false // Track if paused manually by user
    
    // Managers
    var imageDisplayManager: ImageDisplayManager?
    var videoPlayerManager: VideoPlayerManager?
    
    // MARK: - Lifecycle
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadSettings()
        setupUI()
        setupInitialMusicState()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMediaSourceChanged), name: .mediaSourceChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSleepModeChanged), name: .sleepModeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanup()
    }
    
    @objc private func handleMediaSourceChanged() {
        // Dismiss settings and slideshow to return to main screen for reload
        self.presentingViewController?.dismiss(animated: true)
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        setupViews()
        setupManagers()
        setupDashboard()
        setupClockOverlay()
        setupGestures()
    }
    
    private func setupManagers() {
        // Setup ImageDisplayManager
        imageDisplayManager = ImageDisplayManager(frontImageView: frontImageView, backImageView: backImageView)
        imageDisplayManager?.delegate = self
        imageDisplayManager?.contentMode = contentMode
        
        // Setup VideoPlayerManager
        videoPlayerManager = VideoPlayerManager()
        videoPlayerManager?.delegate = self
        videoPlayerManager?.isMuted = isVideoMuted
        videoPlayerManager?.videoMaxDuration = videoMaxDuration
    }
    
    private func setupInitialMusicState() {
        let defaults = UserDefaults.standard
        let shouldPlayMusic: Bool
        if defaults.object(forKey: AppConstants.Keys.kPlayBackgroundMusic) != nil {
            shouldPlayMusic = defaults.bool(forKey: AppConstants.Keys.kPlayBackgroundMusic)
        } else {
            shouldPlayMusic = AppConstants.Defaults.playBackgroundMusic
        }
        
        if shouldPlayMusic {
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
    
    private func setupClockOverlay() {
        let clock = ClockOverlayView()
        clock.translatesAutoresizingMaskIntoConstraints = false
        clock.alpha = isClockMode ? 1 : 0
        view.addSubview(clock)
        self.clockOverlayView = clock
        
        // Ensure controls are always on top
        if let controls = controlsView {
            view.bringSubviewToFront(controls)
        }
        
        NSLayoutConstraint.activate([
            clock.topAnchor.constraint(equalTo: view.topAnchor),
            clock.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            clock.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            clock.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        if isClockMode {
            clock.startUpdating()
        }
    }
    
    private func setupControls() {
        let controls = SlideshowControlsView()
        controls.delegate = self
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)
        self.controlsView = controls
        
        NSLayoutConstraint.activate([
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
    
    // MARK: - Actions
    
    @objc private func toggleClockMode() {
        isClockMode.toggle()
        
        guard let clock = clockOverlayView else { return }
        
        if isClockMode {
            clock.startUpdating()
            UIView.animate(withDuration: Constants.fadeDuration) {
                clock.alpha = 1
                // Dashboard remains visible, not affected by clock mode
            }
        } else {
            UIView.animate(withDuration: Constants.fadeDuration, animations: {
                clock.alpha = 0
                // Dashboard remains visible, not affected by clock mode
            }) { _ in
                clock.stopUpdating()
            }
        }
    }
    
    @objc private func closeSlideshow() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        settingsVC.onSave = { [weak self] changeType in
            guard let self = self else { return }
            
            switch changeType {
            case .playbackConfigChanged:
                self.reloadSettings()
            case .mediaSourceChanged:
                // Handled by notification
                break
            case .other:
                // For schedule or cache changes, we might not need to do anything immediately
                break
            }
        }
        let nav = UINavigationController(rootViewController: settingsVC)
        if traitCollection.userInterfaceIdiom == .pad {
            nav.modalPresentationStyle = .formSheet
        } else {
            nav.modalPresentationStyle = .fullScreen
        }
        present(nav, animated: true, completion: nil)
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
        videoPlayerManager?.isMuted = isVideoMuted
    }
    
    /// 切换播放/暂停幻灯片
    @objc private func togglePlayPause() {
        isPaused.toggle()
        // Mark as user-initiated: if pausing, user paused it; if resuming, user resumed it
        wasPausedByUser = isPaused
        controlsView?.updatePlayPauseButton(isPaused: isPaused)
        
        if isPaused {
            // Pause: stop timer, pause video, and stop Ken Burns animation
            pausePlayback()
        } else {
            // Resume: restart timer or resume video
            // User manually resumed, so clear the flag
            wasPausedByUser = false
            resumePlayback()
        }
    }
    
    private func pausePlayback() {
        timer?.invalidate()
        timer = nil
        videoPlayerManager?.pause()
        
        // Stop Ken Burns animation on current image view
        imageDisplayManager?.stopAnimations()
    }
    
    private func resumePlayback() {
        if videoPlayerManager?.getVideoLayer() != nil {
            // If video is playing, resume it
            videoPlayerManager?.resume()
        } else {
            // If showing image, resume Ken Burns animation and schedule next item
            if let visibleView = imageDisplayManager?.getCurrentAnimatingView() ?? imageDisplayManager?.getVisibleImageView() {
                imageDisplayManager?.resumeKenBurnsAnimation(on: visibleView, duration: displayDuration, isPaused: isPaused)
            }
            scheduleNextItem()
        }
    }
    
    @objc private func handleAppDidEnterBackground() {
        // Pause playback when app enters background
        // Only pause if not already paused by user
        if !isPaused {
            isPaused = true
            pausePlayback()
            // Don't update button state, keep it showing pause icon
            // wasPausedByUser remains false, so we know it was background pause
        }
    }
    
    @objc private func handleAppWillEnterForeground() {
        // Resume playback when app returns to foreground
        // Only resume if it was paused due to background (not manually paused)
        if isPaused && !wasPausedByUser {
            isPaused = false
            wasPausedByUser = false // Clear flag when auto-resuming
            resumePlayback()
            controlsView?.updatePlayPauseButton(isPaused: isPaused)
        }
    }
    
    @objc private func handleSleepModeChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isSleeping = userInfo["isSleeping"] as? Bool else {
            return
        }
        
        if isSleeping {
            // Entering sleep mode: pause playback if not already paused
            if !isPaused {
                isPaused = true
                pausePlayback()
                // Don't update button state, keep it showing pause icon
                // wasPausedByUser remains false, so we know it was sleep mode pause
            }
        } else {
            // Exiting sleep mode: resume playback if it was paused by sleep mode
            if isPaused && !wasPausedByUser {
                isPaused = false
                wasPausedByUser = false // Clear flag when auto-resuming
                resumePlayback()
                controlsView?.updatePlayPauseButton(isPaused: isPaused)
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        // Clear images from hidden image views to free memory
        imageDisplayManager?.clearHiddenImages()
        
        // Clear memory cache in ImageCacheService
        ImageCacheService.shared.clearMemoryCache()
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
        // Only control clock overlay with vertical swipe, not dashboard
        // guard isClockMode else { return }
        
        let shouldShow = (gesture.direction == .up)
        
        // If user reveals the clock via swipe (without tapping the clock button),
        // we still need to start the timer so it ticks every second.
        if shouldShow {
            clockOverlayView?.startUpdating()
        } else {
            clockOverlayView?.stopUpdating()
        }
        
        let targetAlpha: CGFloat = shouldShow ? 1 : 0
        UIView.animate(withDuration: Constants.fadeDuration) {
            self.clockOverlayView?.alpha = targetAlpha
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
        // Stop video and clear any pending video loads immediately
        videoPlayerManager?.stopVideo()
        timer?.invalidate()
        
        // Stop any ongoing Ken Burns animation when swiping
        imageDisplayManager?.stopAnimations()
        
        // Cancel any pending image request before showing next item
        // This prevents showing wrong image when quickly swiping
        imageDisplayManager?.cancelImageRequest()
        
        if gesture.direction == .left {
            showNextItem()
        } else if gesture.direction == .right {
            currentIndex = (currentIndex - 2 + items.count) % items.count
            showNextItem()
        }
    }
    
    // MARK: - Dashboard Updates
    
    private func updateDashboard(for item: UnifiedMediaItem) {
        dashboardView?.updatePhotoMeta(item)
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update video layer frame when layout changes (e.g., rotation)
        videoPlayerManager?.updateFrame(view.bounds)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSlideShow()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Cleanup is handled in deinit or when dismissing
        if isBeingDismissed {
            cleanup()
        }
    }
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil
        videoPlayerManager?.stopVideo()
        MusicService.shared.stop()
        clockOverlayView?.stopUpdating()
        imageDisplayManager?.cancelImageRequest()
        
        // Clear images from image views to free memory
        imageDisplayManager?.clearAllImages()
        
        // Clear memory cache when leaving slideshow
        ImageCacheService.shared.clearMemoryCache()
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
        controlsView?.toggleVisibility()
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
        
        prefetchNextItem()
    }
    
    private func prefetchNextItem() {
        guard !items.isEmpty else { return }
        
        // currentIndex already points to the next item (or items.count)
        var nextIndex = currentIndex
        if nextIndex >= items.count {
            nextIndex = 0
        }
        
        let item = items[nextIndex]
        
        // Prefetch images only
        if item.type == .image {
            let scale = UIScreen.main.scale
            let targetSize = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
            let phContentMode: PHImageContentMode = (contentMode == .scaleAspectFit) ? .aspectFit : .aspectFill
            
            // Just request it to trigger caching
            PhotoService.shared.requestImage(for: item, targetSize: targetSize, contentMode: phContentMode) { _ in }
        }
    }
    
    // MARK: - Image Display
    
    private func showImage(item: UnifiedMediaItem) {
        updateDashboard(for: item)
        videoPlayerManager?.stopVideo()
        imageDisplayManager?.cancelImageRequest()
        
        let phContentMode: PHImageContentMode = (contentMode == .scaleAspectFit) ? .aspectFit : .aspectFill
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        let kenBurnsDuration = displayDuration + Constants.transitionDuration
        
        imageDisplayManager?.showImage(
            item: item,
            targetSize: targetSize,
            contentMode: phContentMode,
            kenBurnsDuration: kenBurnsDuration,
            transitionDuration: Constants.transitionDuration,
            isPaused: isPaused
        )
    }
    
    private func scheduleNextItem() {
        guard !isPaused else { return } // Don't schedule if paused
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            guard let self = self, !self.isPaused else { return } // Check again before showing next
            self.showNextItem()
        }
    }
    
    
    // MARK: - Video Playback
    
    private func playVideo(item: UnifiedMediaItem) {
        updateDashboard(for: item)
        captureMusicStateBeforeVideo()
        
        imageDisplayManager?.hideImageViews(animated: true, duration: Constants.videoHideDuration)
        bringUIElementsToFront()
        handleMusicDuringVideo()
        
        videoPlayerManager?.playVideo(item: item, in: view, itemId: item.id)
    }
    
    private func captureMusicStateBeforeVideo() {
        if !playMusicWithVideo {
            wasMusicPlayingBeforeVideo = isBackgroundMusicOn
        } else {
            wasMusicPlayingBeforeVideo = false
        }
    }
    
    private func bringUIElementsToFront() {
        if let dashboard = dashboardView {
            view.bringSubviewToFront(dashboard)
        }
        if let clock = clockOverlayView {
            view.bringSubviewToFront(clock)
        }
        // Controls must be the topmost layer
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

// MARK: - ImageDisplayManagerDelegate

extension SlideShowViewController: ImageDisplayManagerDelegate {
    func imageDisplayManager(_ manager: ImageDisplayManager, didDisplayImage image: UIImage) {
        scheduleNextItem()
    }
    
    func imageDisplayManager(_ manager: ImageDisplayManager, didFailToLoad item: UnifiedMediaItem) {
        showNextItem()
    }
}

// MARK: - VideoPlayerManagerDelegate

extension SlideShowViewController: VideoPlayerManagerDelegate {
    func videoPlayerManager(_ manager: VideoPlayerManager, didStartPlaying item: AVPlayerItem) {
        // Video started playing successfully
        // Ensure UI elements are on top of video layer after it's added
        bringUIElementsToFront()
        
        // Ensure dashboard is visible when playing video (unless in clock mode)
        if !isClockMode {
            dashboardView?.alpha = 1
        }
    }
    
    func videoPlayerManager(_ manager: VideoPlayerManager, didFailToLoad item: UnifiedMediaItem) {
        showNextItem()
    }
    
    func videoPlayerManagerDidFinish(_ manager: VideoPlayerManager) {
        resumeMusicAfterVideo(resumeMusic: true)
        // Only show next item if not paused
        if !isPaused {
            showNextItem()
        }
    }
}

// MARK: - SlideshowControlsViewDelegate

extension SlideShowViewController: SlideshowControlsViewDelegate {
    func slideshowControlsViewDidTapPlayPause(_ view: SlideshowControlsView) {
        togglePlayPause()
    }
    
    func slideshowControlsViewDidTapMusic(_ view: SlideshowControlsView) {
        toggleBackgroundMusic()
    }
    
    func slideshowControlsViewDidTapVideoSound(_ view: SlideshowControlsView) {
        toggleVideoSound()
    }
    
    func slideshowControlsViewDidTapClock(_ view: SlideshowControlsView) {
        toggleClockMode()
    }
    
    func slideshowControlsViewDidTapSettings(_ view: SlideshowControlsView) {
        openSettings()
    }
    
    func slideshowControlsViewDidTapClose(_ view: SlideshowControlsView) {
        closeSlideshow()
    }
}

