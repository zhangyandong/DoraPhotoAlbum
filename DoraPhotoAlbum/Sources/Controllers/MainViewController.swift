import UIKit

class MainViewController: UIViewController {

    private var allItems: [UnifiedMediaItem] = []
    private var webDAVClient: WebDAVClient? // Keep reference to prevent deallocation
    
    // Loading cards
    private var localCard: LoadingCardView!
    private var webDAVCard: LoadingCardView!
    private var cardsStack: UIStackView!
    private var playButton: UIButton!
    
    // Loading state tracking
    private var localLoadingState: LoadingCardView.LoadingState = .loading
    private var webDAVLoadingState: LoadingCardView.LoadingState = .loading
    private var localItemsCount: Int = 0
    private var webDAVItemsCount: Int = 0
    private var hasAutoPlayed: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupUI()
        
        // Start Scheduler if sleep or wake is enabled
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
        
        if sleepEnabled || wakeEnabled {
            SchedulerService.shared.startMonitoring()
        }
        
        // Load Content
        checkPermissionsAndLoad()
        
        // Listen for notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleMediaSourceChanged), name: .mediaSourceChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleMediaSourceChanged() {
        reloadMedia()
    }
    
    private func setupUI() {
        let settingsBtn = UIButton(type: .infoLight)
        settingsBtn.tintColor = .white
        settingsBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsBtn)
        
        // Create loading cards
        localCard = LoadingCardView()
        localCard.titleLabel.text = "本地相册"
        localCard.onReload = { [weak self] in
            self?.reloadLocalMedia()
        }
        
        webDAVCard = LoadingCardView()
        webDAVCard.titleLabel.text = "WebDAV"
        webDAVCard.onReload = { [weak self] in
            self?.reloadWebDAVMedia()
        }
        
        cardsStack = UIStackView(arrangedSubviews: [localCard, webDAVCard])
        cardsStack.axis = .vertical
        cardsStack.spacing = 16
        cardsStack.distribution = .fillEqually
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardsStack)
        
        // Play button
        playButton = UIButton(type: .system)
        playButton.setTitle("播放幻灯片", for: .normal)
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        playButton.setTitleColor(.white, for: .normal)
        playButton.backgroundColor = UIColor.systemBlue
        playButton.layer.cornerRadius = 12
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(startSlideShow), for: .touchUpInside)
        playButton.isEnabled = false
        playButton.alpha = 0.5
        view.addSubview(playButton)
        
        NSLayoutConstraint.activate([
            settingsBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            settingsBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            cardsStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            cardsStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cardsStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            localCard.heightAnchor.constraint(equalToConstant: 100),
            webDAVCard.heightAnchor.constraint(equalToConstant: 100),
            
            playButton.topAnchor.constraint(equalTo: cardsStack.bottomAnchor, constant: 30),
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 200),
            playButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        settingsBtn.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
    }
    
    private func checkPermissionsAndLoad() {
        // Reset state
        hasAutoPlayed = false
        allItems = []
        localItemsCount = 0
        webDAVItemsCount = 0
        
        // Check local album permission and setup
        let defaults = UserDefaults.standard
        let localEnabled = defaults.object(forKey: AppConstants.Keys.kLocalAlbumEnabled) as? Bool ?? true
        
        if localEnabled {
            localCard.state = .loading
            PhotoService.shared.requestAuthorization { [weak self] authorized in
                guard let self = self else { return }
                if authorized {
                    self.loadLocalMedia()
                } else {
                    DispatchQueue.main.async {
                        self.localCard.state = .error(message: "相册权限被拒绝")
                        self.localLoadingState = .error(message: "相册权限被拒绝")
                        self.checkAndAutoPlay()
                    }
                }
            }
        } else {
            localCard.state = .disabled(message: "未开启")
            localLoadingState = .disabled(message: "未开启")
            checkAndAutoPlay()
        }
        
        // Setup WebDAV loading
        let webDAVEnabled = defaults.bool(forKey: AppConstants.Keys.kWebDAVEnabled)
        if webDAVEnabled,
           let host = defaults.string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
           let user = defaults.string(forKey: AppConstants.Keys.kWebDAVUser),
           let pass = defaults.string(forKey: AppConstants.Keys.kWebDAVPassword) {
            webDAVCard.state = .loading
            webDAVLoadingState = .loading
            loadWebDAVMedia()
        } else {
            let message = webDAVEnabled ? "配置不完整" : "未配置"
            webDAVCard.state = .disabled(message: message)
            webDAVLoadingState = .disabled(message: message)
            checkAndAutoPlay()
        }
        
        // Check if both are already disabled/completed
        checkAndAutoPlay()
    }
    
    private func loadLocalMedia() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let localItems = PhotoService.shared.fetchLocalMedia()
            self.localItemsCount = localItems.count
            
            DispatchQueue.main.async {
                self.allItems.append(contentsOf: localItems)
                self.localCard.state = .completed(count: localItems.count)
                self.localLoadingState = .completed(count: localItems.count)
                self.checkAndAutoPlay()
            }
        }
    }
    
    private func loadWebDAVMedia() {
        let defaults = UserDefaults.standard
        guard let host = defaults.string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
              let user = defaults.string(forKey: AppConstants.Keys.kWebDAVUser),
              let pass = defaults.string(forKey: AppConstants.Keys.kWebDAVPassword) else {
            DispatchQueue.main.async {
                self.webDAVCard.state = .error(message: "配置不完整")
                self.webDAVLoadingState = .error(message: "配置不完整")
                self.checkAndAutoPlay()
            }
            return
        }
        
        let config = WebDAVConfig(host: host, username: user, password: pass)
        let client = WebDAVClient(config: config)
        
        // Keep reference to prevent deallocation before callback completes
        self.webDAVClient = client
        
        // Use selected folder path, default to root if not set
        let selectedPath = defaults.string(forKey: AppConstants.Keys.kWebDAVSelectedPath) ?? "/"
        
        print("MainViewController: Loading WebDAV folder: \(selectedPath)")
        
        // Set a timeout for WebDAV loading
        let startTime = Date()
        client.listDirectory(path: selectedPath) { [weak self] remoteItems in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            print("MainViewController: Loaded \(remoteItems.count) items from WebDAV (took \(String(format: "%.2f", elapsed))s)")
            self.webDAVItemsCount = remoteItems.count
            
            DispatchQueue.main.async {
                self.allItems.append(contentsOf: remoteItems)
                // If loading took very long and got 0 items, might indicate an error
                // But we'll still show it as completed since WebDAVClient doesn't provide error details
                if remoteItems.count == 0 && elapsed > 10 {
                    // Likely an error, but we can't be sure - show as completed with 0 items
                    self.webDAVCard.state = .completed(count: 0)
                    self.webDAVLoadingState = .completed(count: 0)
                } else {
                    self.webDAVCard.state = .completed(count: remoteItems.count)
                    self.webDAVLoadingState = .completed(count: remoteItems.count)
                }
                // Clear reference after loading completes
                self.webDAVClient = nil
                self.checkAndAutoPlay()
            }
        }
    }
    
    private func reloadLocalMedia() {
        localCard.state = .loading
        localLoadingState = .loading
        
        // Remove old local items
        allItems = allItems.filter { $0.remoteURL != nil }
        localItemsCount = 0
        
        PhotoService.shared.requestAuthorization { [weak self] authorized in
            guard let self = self else { return }
            if authorized {
                self.loadLocalMedia()
            } else {
                DispatchQueue.main.async {
                    self.localCard.state = .error(message: "相册权限被拒绝")
                    self.localLoadingState = .error(message: "相册权限被拒绝")
                }
            }
        }
    }
    
    private func reloadWebDAVMedia() {
        webDAVCard.state = .loading
        webDAVLoadingState = .loading
        
        // Remove old WebDAV items
        allItems = allItems.filter { $0.localAsset != nil }
        webDAVItemsCount = 0
        
        loadWebDAVMedia()
    }
    
    private func checkAndAutoPlay() {
        // Check if both loading tasks are completed (success or error/disabled)
        let localDone: Bool
        switch localLoadingState {
        case .loading:
            localDone = false
        case .completed, .error, .disabled:
            localDone = true
        }
        
        let webDAVDone: Bool
        switch webDAVLoadingState {
        case .loading:
            webDAVDone = false
        case .completed, .error, .disabled:
            webDAVDone = true
        }
        
        // Update play button state
        let canPlay = !allItems.isEmpty
        playButton.isEnabled = canPlay
        playButton.alpha = canPlay ? 1.0 : 0.5
        
        // Auto play when both are done and we have items
        if localDone && webDAVDone && !hasAutoPlayed && !allItems.isEmpty {
            hasAutoPlayed = true
            // Small delay to show completion state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startSlideShow()
            }
        }
    }
    
    @objc private func startSlideShow() {
        guard !allItems.isEmpty else { return }
        let slideVC = SlideShowViewController()
        slideVC.items = allItems.shuffled()
        slideVC.modalPresentationStyle = .fullScreen
        present(slideVC, animated: true, completion: nil)
    }
    
    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        settingsVC.onSave = { changeType in
            switch changeType {
            case .mediaSourceChanged:
                // Handled by notification
                break
            case .playbackConfigChanged:
                // Playback config (duration, music, etc.) will be picked up
                // by SlideShowViewController next time it starts.
                // We might want to update some UI here if needed, but current UI is simple.
                print("MainViewController: Playback config changed")
            case .other:
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
    
    private func reloadMedia() {
        // Clear current items and reload
        allItems = []
        checkPermissionsAndLoad()
    }
}
