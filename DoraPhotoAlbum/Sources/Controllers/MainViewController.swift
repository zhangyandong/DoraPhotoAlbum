import UIKit

class MainViewController: UIViewController {

    private var allItems: [UnifiedMediaItem] = []
    private var webDAVClient: WebDAVClient? // Keep reference to prevent deallocation
    
    // Loading cards
    private var localCard: LoadingCardView!
    private var webDAVCard: LoadingCardView!
    private var cardsStack: UIStackView!
    private var playButton: UIButton!
    private var titleLabel: UILabel!
    private var hintLabel: UILabel!
    
    // Loading state tracking
    private var localLoadingState: LoadingCardView.LoadingState = .loading
    private var webDAVLoadingState: LoadingCardView.LoadingState = .loading
    private var localItemsCount: Int = 0
    private var webDAVItemsCount: Int = 0
    private var hasAutoPlayed: Bool = false
    private var presentedSettingsNav: UINavigationController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appSystemGroupedBackground
        
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
        // Notifications may be posted from background threads (e.g. iCloud KVS callbacks).
        // Any UI / layout work must be on main.
        if Thread.isMainThread {
            reloadMedia()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.reloadMedia()
            }
        }
    }
    
    private func setupUI() {
        // Header (kid-friendly)
        titleLabel = UILabel()
        titleLabel.text = "Dora 相册"
        titleLabel.textColor = .appLabel
        titleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        hintLabel = UILabel()
        hintLabel.text = "点“开始播放”就能看照片啦"
        hintLabel.textColor = .appSecondaryLabel
        hintLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)
        
        // Create loading cards
        localCard = LoadingCardView()
        localCard.titleLabel.text = "本地相册"
        localCard.onReload = { [weak self] in
            self?.reloadLocalMedia()
        }
        localCard.onSettings = { [weak self] in
            self?.openLocalAlbumSettings()
        }
        
        webDAVCard = LoadingCardView()
        webDAVCard.titleLabel.text = "WebDAV"
        webDAVCard.onReload = { [weak self] in
            self?.reloadWebDAVMedia()
        }
        webDAVCard.onSettings = { [weak self] in
            self?.openWebDAVSettings()
        }
        
        cardsStack = UIStackView(arrangedSubviews: [localCard, webDAVCard])
        cardsStack.axis = .vertical
        cardsStack.spacing = 18
        cardsStack.distribution = .fillEqually
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardsStack)
        
        // Play button
        playButton = UIButton(type: .system)
        playButton.setTitle("开始播放", for: .normal)
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        playButton.setTitleColor(.white, for: .normal)
        playButton.backgroundColor = UIColor.appAccentGreen
        playButton.layer.cornerRadius = 18
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(startSlideShow), for: .touchUpInside)
        playButton.isEnabled = false
        playButton.alpha = 0.5
        view.addSubview(playButton)
        
        // Settings entry (simple tap)
        let settingsButton = UIButton(type: .system)
        settingsButton.setTitle("设置", for: .normal)
        settingsButton.setTitleColor(.appAccentBlue, for: .normal)
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        view.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            cardsStack.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 22),
            cardsStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cardsStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            localCard.heightAnchor.constraint(equalToConstant: 120),
            webDAVCard.heightAnchor.constraint(equalToConstant: 120),
            
            playButton.topAnchor.constraint(equalTo: cardsStack.bottomAnchor, constant: 26),
            playButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            playButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            playButton.heightAnchor.constraint(equalToConstant: 72),
            
            settingsButton.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 14),
            settingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            settingsButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }

    @objc private func dismissPresentedSettings() {
        dismiss(animated: true)
        presentedSettingsNav = nil
    }

    private func presentSettingsRoot(_ vc: UIViewController) {
        vc.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "关闭", style: .plain, target: self, action: #selector(dismissPresentedSettings))
        let nav = UINavigationController(rootViewController: vc)
        presentedSettingsNav = nav
        if traitCollection.userInterfaceIdiom == .pad {
            nav.modalPresentationStyle = .formSheet
        } else {
            nav.modalPresentationStyle = .fullScreen
        }
        present(nav, animated: true)
    }

    private func openLocalAlbumSettings() {
        let vc = LocalAlbumSettingsViewController()
        vc.onSave = {
            NotificationCenter.default.post(name: .mediaSourceChanged, object: nil)
        }
        presentSettingsRoot(vc)
    }

    private func openWebDAVSettings() {
        let vc = WebDAVSettingsViewController()
        vc.onSave = {
            NotificationCenter.default.post(name: .mediaSourceChanged, object: nil)
        }
        presentSettingsRoot(vc)
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
        
        // Setup WebDAV loading (iCloud synced)
        let webDAVSettings = WebDAVSettingsManager.shared
        let webDAVEnabled = webDAVSettings.bool(forKey: AppConstants.Keys.kWebDAVEnabled)
        if webDAVEnabled,
           let host = webDAVSettings.string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
           let user = webDAVSettings.string(forKey: AppConstants.Keys.kWebDAVUser),
           let pass = webDAVSettings.string(forKey: AppConstants.Keys.kWebDAVPassword) {
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
        let settings = WebDAVSettingsManager.shared
        guard let host = settings.string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
              let user = settings.string(forKey: AppConstants.Keys.kWebDAVUser),
              let pass = settings.string(forKey: AppConstants.Keys.kWebDAVPassword) else {
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
        
        // Use selected folder paths. If none selected, treat as incomplete config (do NOT default to root).
        let selectedPaths = settings.stringArray(forKey: AppConstants.Keys.kWebDAVSelectedPaths)
        let rawPaths = (selectedPaths?.isEmpty == false) ? (selectedPaths ?? []) : []
        
        func normalizeWebDAVPath(_ path: String) -> String {
            var p = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if p.isEmpty { return "/" }
            if !p.hasPrefix("/") { p = "/" + p }
            // Remove trailing slash except for root.
            if p.count > 1, p.hasSuffix("/") {
                p = String(p.dropLast())
            }
            return p
        }
        
        // De-dupe and remove redundant subpaths:
        // If `/a` is selected, then `/a/b` is unnecessary because listDirectory is recursive.
        let normalizedUnique = Array(Set(rawPaths.map(normalizeWebDAVPath))).sorted { $0.count < $1.count }
        var pruned: [String] = []
        for candidate in normalizedUnique {
            // Root covers everything.
            if pruned.contains("/") { break }
            let isRedundant = pruned.contains { parent in
                if parent == "/" { return true }
                return candidate == parent || candidate.hasPrefix(parent + "/")
            }
            if !isRedundant {
                pruned.append(candidate)
            }
        }
        
        let paths = pruned
        guard !paths.isEmpty else {
            DispatchQueue.main.async {
                self.webDAVCard.state = .disabled(message: "未选择文件夹")
                self.webDAVLoadingState = .disabled(message: "未选择文件夹")
                self.webDAVClient = nil
                self.checkAndAutoPlay()
            }
            return
        }
        print("MainViewController: Loading WebDAV folders: \(paths)")
        
        let startTime = Date()
        let group = DispatchGroup()
        var allRemoteItems: [UnifiedMediaItem] = []
        let lock = NSLock()
        
        for path in paths {
            group.enter()
            client.listDirectory(path: path) { items in
                lock.lock()
                allRemoteItems.append(contentsOf: items)
                lock.unlock()
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            
            // De-duplicate by remote URL
            var seen = Set<String>()
            let deduped: [UnifiedMediaItem] = allRemoteItems.filter { item in
                guard let url = item.remoteURL else { return true }
                let key = url.absoluteString
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
            
            // Sort by creationDate desc if available (fallback keeps relative order)
            let sorted = deduped.sorted { a, b in
                switch (a.creationDate, b.creationDate) {
                case let (da?, db?):
                    return da > db
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return false
                }
            }
            
            print("MainViewController: Loaded \(sorted.count) items from WebDAV \(paths.count) folder(s) (took \(String(format: "%.2f", elapsed))s)")
            self.webDAVItemsCount = sorted.count
            self.allItems.append(contentsOf: sorted)
            
            // If loading took very long and got 0 items, might indicate an error
            if sorted.count == 0 && elapsed > 10 {
                self.webDAVCard.state = .completed(count: 0)
                self.webDAVLoadingState = .completed(count: 0)
            } else {
                self.webDAVCard.state = .completed(count: sorted.count)
                self.webDAVLoadingState = .completed(count: sorted.count)
            }
            
            self.webDAVClient = nil
            self.checkAndAutoPlay()
        }
    }
    
    private func reloadLocalMedia() {
        // Respect local album enable switch
        let defaults = UserDefaults.standard
        let localEnabled = defaults.object(forKey: AppConstants.Keys.kLocalAlbumEnabled) as? Bool ?? true
        guard localEnabled else {
            // Remove old local items and show disabled state
            allItems = allItems.filter { $0.remoteURL != nil }
            localItemsCount = 0
            localCard.state = .disabled(message: "未开启")
            localLoadingState = .disabled(message: "未开启")
            checkAndAutoPlay()
            return
        }
        
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
        // Respect WebDAV enable switch and config completeness
        let settings = WebDAVSettingsManager.shared
        let webDAVEnabled = settings.bool(forKey: AppConstants.Keys.kWebDAVEnabled)
        guard webDAVEnabled else {
            // Remove old WebDAV items and show disabled state
            allItems = allItems.filter { $0.localAsset != nil }
            webDAVItemsCount = 0
            webDAVCard.state = .disabled(message: "未开启")
            webDAVLoadingState = .disabled(message: "未开启")
            checkAndAutoPlay()
            return
        }
        
        guard let host = settings.string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
              let _ = settings.string(forKey: AppConstants.Keys.kWebDAVUser),
              let _ = settings.string(forKey: AppConstants.Keys.kWebDAVPassword) else {
            // Remove old WebDAV items and show config error
            allItems = allItems.filter { $0.localAsset != nil }
            webDAVItemsCount = 0
            webDAVCard.state = .disabled(message: "配置不完整")
            webDAVLoadingState = .disabled(message: "配置不完整")
            checkAndAutoPlay()
            return
        }
        
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
        if canPlay {
            hintLabel.text = "点“开始播放”就能看照片啦"
            startPlayButtonPulseIfNeeded()
        } else {
            hintLabel.text = "正在准备照片…"
            stopPlayButtonPulse()
        }
        
        // Auto play when both are done and we have items
        if localDone && webDAVDone && !hasAutoPlayed && !allItems.isEmpty {
            hasAutoPlayed = true
            // Small delay to show completion state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startSlideShow()
            }
        }
    }

    private func startPlayButtonPulseIfNeeded() {
        // Avoid stacking animations
        if playButton.layer.animation(forKey: "pulse") != nil { return }
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = 1.0
        anim.toValue = 1.04
        anim.duration = 0.9
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        playButton.layer.add(anim, forKey: "pulse")
    }
    
    private func stopPlayButtonPulse() {
        playButton.layer.removeAnimation(forKey: "pulse")
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
