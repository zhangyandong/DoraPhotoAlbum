import UIKit

class MainViewController: UIViewController {

    private var allItems: [UnifiedMediaItem] = []
    private var webDAVClient: WebDAVClient? // Keep reference to prevent deallocation
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupUI()
        
        // Start Scheduler
        SchedulerService.shared.startMonitoring()
        
        // Load Content
        checkPermissionsAndLoad()
    }
    
    private func setupUI() {
        let settingsBtn = UIButton(type: .infoLight)
        settingsBtn.tintColor = .white
        settingsBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsBtn)
        
        let playBtn = UIButton(type: .system)
        playBtn.setTitle("播放幻灯片", for: .normal)
        playBtn.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        playBtn.setTitleColor(.white, for: .normal)
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.addTarget(self, action: #selector(startSlideShow), for: .touchUpInside)
        view.addSubview(playBtn)
        
        let countLabel = UILabel()
        countLabel.tag = 100 // Tag to find it later
        countLabel.text = "加载中..."
        countLabel.textColor = .lightGray
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countLabel)
        
        NSLayoutConstraint.activate([
            settingsBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            settingsBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            playBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playBtn.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            countLabel.topAnchor.constraint(equalTo: playBtn.bottomAnchor, constant: 10),
            countLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        settingsBtn.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
    }
    
    private func checkPermissionsAndLoad() {
        PhotoService.shared.requestAuthorization { [weak self] authorized in
            if authorized {
                self?.loadMedia()
            } else {
                DispatchQueue.main.async {
                    if let label = self?.view.viewWithTag(100) as? UILabel {
                        label.text = "相册权限被拒绝"
                    }
                }
            }
        }
    }
    
    private func loadMedia() {
        // Local
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let localItems = PhotoService.shared.fetchLocalMedia()
            
            DispatchQueue.main.async {
                self.allItems = localItems
                self.updateCountLabel()
            }
            
            // WebDAV
            let defaults = UserDefaults.standard
            if let host = defaults.string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
               let user = defaults.string(forKey: AppConstants.Keys.kWebDAVUser),
               let pass = defaults.string(forKey: AppConstants.Keys.kWebDAVPassword) {
                
                let config = WebDAVConfig(host: host, username: user, password: pass)
                let client = WebDAVClient(config: config)
                
                // Keep reference to prevent deallocation before callback completes
                self.webDAVClient = client
                
                // Use selected folder path, default to root if not set
                let selectedPath = defaults.string(forKey: AppConstants.Keys.kWebDAVSelectedPath) ?? "/"
                
                print("MainViewController: Loading WebDAV folder: \(selectedPath)")
                
                client.listDirectory(path: selectedPath) { [weak self] remoteItems in
                    guard let self = self else { return }
                    print("MainViewController: Loaded \(remoteItems.count) items from WebDAV")
                    self.allItems.append(contentsOf: remoteItems)
                    DispatchQueue.main.async {
                        self.updateCountLabel()
                        // Clear reference after loading completes
                        self.webDAVClient = nil
                    }
                }
            }
        }
    }
    
    private func updateCountLabel() {
        if let label = view.viewWithTag(100) as? UILabel {
            label.text = "发现 \(allItems.count) 个项目"
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
        settingsVC.onSave = { [weak self] in
            // Reload media when settings are saved
            self?.reloadMedia()
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
        updateCountLabel()
        loadMedia()
    }
}
