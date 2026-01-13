import UIKit

class MainViewController: UIViewController {

    private var allItems: [UnifiedMediaItem] = []
    private var webDAVClient: WebDAVClient? // Keep reference to prevent deallocation
    
    // Loading cards
    private var localCard: LoadingCardView!
    private var webDAVCard: LoadingCardView!
    private var cardsStack: UIStackView!
    private var buttonsStack: UIStackView!
    private var playButton: UIButton!
    private var clockButton: UIButton!
    private var titleLabel: UILabel!
    private var hintLabel: UILabel!
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var contentStack: UIStackView!
    private var localCardHeightConstraint: NSLayoutConstraint?
    private var webDAVCardHeightConstraint: NSLayoutConstraint?
    
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAdaptiveLayout()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAdaptiveLayout()
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
        // Scrollable root (works better on small screens + Dynamic Type)
        scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        
        contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -18)
        ])
        
        // Header
        titleLabel = UILabel()
        titleLabel.text = "Dora 相册"
        titleLabel.textColor = .appLabel
        if #available(iOS 11.0, *) {
            titleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        } else {
            titleLabel.font = UIFont.boldSystemFont(ofSize: 34)
        }
        titleLabel.numberOfLines = 1
        
        hintLabel = UILabel()
        hintLabel.text = "点“开始播放”就能看照片啦"
        hintLabel.textColor = .appSecondaryLabel
        hintLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        hintLabel.numberOfLines = 0
        
        let headerTextStack = UIStackView(arrangedSubviews: [titleLabel, hintLabel])
        headerTextStack.axis = .vertical
        headerTextStack.spacing = 6
        headerTextStack.alignment = .leading
        
        // Clock button (functional shortcut)
        clockButton = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            clockButton.setImage(UIImage(systemName: "clock.fill"), for: .normal)
            clockButton.tintColor = .appAccentBlue
        } else {
            clockButton.setTitle("时钟", for: .normal)
            clockButton.setTitleColor(.appAccentBlue, for: .normal)
        }
        clockButton.backgroundColor = UIColor(white: 1.0, alpha: 0.65)
        clockButton.layer.cornerRadius = 14
        clockButton.layer.masksToBounds = true
        clockButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            clockButton.widthAnchor.constraint(equalToConstant: 44),
            clockButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        clockButton.addTarget(self, action: #selector(showClockOnly), for: .touchUpInside)
        clockButton.accessibilityLabel = "显示时钟"
        
        let settingsButton = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            settingsButton.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
            settingsButton.tintColor = .appAccentBlue
        } else {
            settingsButton.setTitle("设置", for: .normal)
            settingsButton.setTitleColor(.appAccentBlue, for: .normal)
        }
        settingsButton.backgroundColor = UIColor(white: 1.0, alpha: 0.65)
        settingsButton.layer.cornerRadius = 14
        settingsButton.layer.masksToBounds = true
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        settingsButton.accessibilityLabel = "设置"
        
        let trailingActions = UIStackView(arrangedSubviews: [clockButton, settingsButton])
        trailingActions.axis = .horizontal
        trailingActions.alignment = .center
        trailingActions.spacing = 10
        
        let headerRow = UIStackView(arrangedSubviews: [headerTextStack, UIView(), trailingActions])
        headerRow.axis = .horizontal
        headerRow.alignment = .top
        headerRow.spacing = 12
        contentStack.addArrangedSubview(headerRow)
        
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
        cardsStack.spacing = 14
        cardsStack.distribution = .fillEqually
        contentStack.addArrangedSubview(cardsStack)
        
        localCardHeightConstraint = localCard.heightAnchor.constraint(equalToConstant: 132)
        webDAVCardHeightConstraint = webDAVCard.heightAnchor.constraint(equalToConstant: 132)
        localCardHeightConstraint?.isActive = true
        webDAVCardHeightConstraint?.isActive = true
        
        // Play button
        playButton = UIButton(type: .system)
        configurePrimaryButton(playButton, title: "开始播放", color: .appAccentGreen, systemImageName: "play.fill")
        playButton.addTarget(self, action: #selector(startSlideShow), for: .touchUpInside)
        playButton.isEnabled = false
        playButton.alpha = 0.5

        // Primary action area: keep only Play as the main CTA.
        buttonsStack = UIStackView(arrangedSubviews: [playButton])
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 12
        buttonsStack.distribution = .fill
        contentStack.addArrangedSubview(buttonsStack)
        
        NSLayoutConstraint.activate([
            playButton.heightAnchor.constraint(equalToConstant: 72)
        ])
        
        // Bottom breathing room
        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomSpacer.heightAnchor.constraint(equalToConstant: 8)
        ])
        contentStack.addArrangedSubview(bottomSpacer)
        
        updateAdaptiveLayout()
    }
    
    private func configurePrimaryButton(_ button: UIButton, title: String, color: UIColor, systemImageName: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color
        button.layer.cornerRadius = 18
        button.layer.masksToBounds = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 14
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        
        button.titleLabel?.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        
        if #available(iOS 13.0, *) {
            let img = UIImage(systemName: systemImageName)
            button.setImage(img, for: .normal)
            button.tintColor = .white
            // Put image before title with some spacing
            button.semanticContentAttribute = .forceLeftToRight
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        }
        
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
    }
    
    private func configureSecondaryButton(_ button: UIButton, title: String, tint: UIColor, systemImageName: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(tint, for: .normal)
        button.backgroundColor = .appSecondarySystemGroupedBackground
        button.layer.cornerRadius = 18
        button.layer.masksToBounds = true
        button.layer.borderWidth = 2
        button.layer.borderColor = tint.withAlphaComponent(0.35).cgColor
        
        // Secondary buttons should feel lighter (no heavy shadow)
        button.layer.shadowOpacity = 0
        
        button.titleLabel?.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        
        if #available(iOS 13.0, *) {
            let img = UIImage(systemName: systemImageName)
            button.setImage(img, for: .normal)
            button.tintColor = tint
            button.semanticContentAttribute = .forceLeftToRight
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        }
        
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
    }
    
    private func updateAdaptiveLayout() {
        let width = view.bounds.width
        let isWide = width >= 700 || traitCollection.horizontalSizeClass == .regular
        
        // Cards: stack horizontally on wide screens
        cardsStack.axis = isWide ? .horizontal : .vertical
        cardsStack.spacing = isWide ? 16 : 14
        
        // Buttons: side-by-side on wide screens, vertical on phones
        buttonsStack.axis = isWide ? .horizontal : .vertical
        buttonsStack.spacing = isWide ? 16 : 12
        
        localCardHeightConstraint?.constant = isWide ? 160 : 132
        webDAVCardHeightConstraint?.constant = isWide ? 160 : 132
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
           let _ = webDAVSettings.string(forKey: AppConstants.Keys.kWebDAVUser),
           let _ = webDAVSettings.string(forKey: AppConstants.Keys.kWebDAVPassword) {
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
        var anyPathFailed = false
        let lock = NSLock()
        let successLock = NSLock()
        
        for path in paths {
            group.enter()
            client.listDirectory(path: path) { items, didSucceed in
                lock.lock()
                allRemoteItems.append(contentsOf: items)
                lock.unlock()
                
                if !didSucceed {
                    successLock.lock()
                    anyPathFailed = true
                    successLock.unlock()
                }
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
            
            let allSucceeded = !anyPathFailed
            
            var finalItems = sorted
            var usedOfflineCache = false
            
            // If WebDAV fetch failed and got 0 items, fallback to enumerating the cache directory directly.
            // This avoids relying on "last successful list" state.
            if finalItems.isEmpty && !allSucceeded {
                let cached = ImageCacheService.shared.listCachedMediaItems()
                if !cached.isEmpty {
                    finalItems = cached
                    usedOfflineCache = true
                    print("MainViewController: WebDAV failed; using cache directory items: \(cached.count)")
                }
            }
            
            self.webDAVItemsCount = finalItems.count
            self.allItems.append(contentsOf: finalItems)
            
            // If loading took very long and got 0 items, might indicate an error
            if usedOfflineCache {
                let message = "WebDAV 加载失败，已从缓存目录加载 \(finalItems.count) 个项目"
                self.webDAVCard.state = .completed(count: finalItems.count, message: message)
                self.webDAVLoadingState = .completed(count: finalItems.count, message: message)
            } else if finalItems.count == 0 && !allSucceeded {
                self.webDAVCard.state = .error(message: "WebDAV 加载失败（缓存目录为空）")
                self.webDAVLoadingState = .error(message: "WebDAV 加载失败（缓存目录为空）")
            } else {
                self.webDAVCard.state = .completed(count: finalItems.count)
                self.webDAVLoadingState = .completed(count: finalItems.count)
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
        let canPlayMedia = !allItems.isEmpty
        
        playButton.isEnabled = canPlayMedia
        playButton.alpha = canPlayMedia ? 1.0 : 0.5
        
        if canPlayMedia {
            hintLabel.text = "点“开始播放”就能看照片啦"
            startPlayButtonPulseIfNeeded()
        } else {
            // If completely empty but done loading, hint user
            if localDone && webDAVDone {
                hintLabel.text = "没有找到照片，可以试试显示时钟"
            } else {
                hintLabel.text = "正在准备照片…"
            }
            stopPlayButtonPulse()
        }
        
        // Auto play when both are done and we have items
        if localDone && webDAVDone && !hasAutoPlayed && canPlayMedia {
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
        let slideVC = SlideShowViewController()
        slideVC.items = allItems.shuffled()
        slideVC.modalPresentationStyle = .fullScreen
        present(slideVC, animated: true, completion: nil)
    }
    
    @objc private func showClockOnly() {
        let vc = ClockOnlyViewController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
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
