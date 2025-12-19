import UIKit

class SettingsViewController: UIViewController {
    
    // UI Elements
    private let hostField = UITextField()
    private let userField = UITextField()
    private let passField = UITextField()
    private let durationField = UITextField()
    private let videoDurationField = UITextField()
    private let musicSwitch = UISwitch()
    private let musicWithVideoSwitch = UISwitch()
    private let videoMutedSwitch = UISwitch()
    private let contentModeSegment = UISegmentedControl(items: ["填充 (裁剪)", "适应 (完整)"])
    
    private let sleepPicker = UIDatePicker()
    private let wakePicker = UIDatePicker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "设置"
        
        // ScrollView to handle landscape height issues
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40)
        ])
        
        // WebDAV Section
        stack.addArrangedSubview(createLabel("WebDAV 主机地址"))
        configureField(hostField, placeholder: "http://192.168.1.100:5005/photos")
        stack.addArrangedSubview(hostField)
        
        stack.addArrangedSubview(createLabel("用户名"))
        configureField(userField, placeholder: "admin")
        stack.addArrangedSubview(userField)
        
        stack.addArrangedSubview(createLabel("密码"))
        configureField(passField, placeholder: "password", isSecure: true)
        stack.addArrangedSubview(passField)
        
        // WebDAV Actions
        let testConnectionBtn = UIButton(type: .system)
        testConnectionBtn.setTitle("测试连接", for: .normal)
        testConnectionBtn.backgroundColor = .systemBlue
        testConnectionBtn.setTitleColor(.white, for: .normal)
        testConnectionBtn.layer.cornerRadius = 8
        testConnectionBtn.addTarget(self, action: #selector(testConnection), for: .touchUpInside)
        testConnectionBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(testConnectionBtn)
        
        let selectFolderBtn = UIButton(type: .system)
        selectFolderBtn.setTitle("选择文件夹", for: .normal)
        selectFolderBtn.backgroundColor = .systemGreen
        selectFolderBtn.setTitleColor(.white, for: .normal)
        selectFolderBtn.layer.cornerRadius = 8
        selectFolderBtn.addTarget(self, action: #selector(selectFolder), for: .touchUpInside)
        selectFolderBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(selectFolderBtn)
        
        // Selected folder label
        let selectedFolderLabel = UILabel()
        selectedFolderLabel.tag = 999
        selectedFolderLabel.text = "未选择文件夹"
        selectedFolderLabel.textColor = .gray
        selectedFolderLabel.font = UIFont.systemFont(ofSize: 14)
        selectedFolderLabel.numberOfLines = 0
        stack.addArrangedSubview(selectedFolderLabel)
        
        stack.addArrangedSubview(createLabel("幻灯片播放间隔 (秒)"))
        configureField(durationField, placeholder: "10")
        durationField.keyboardType = .numberPad
        stack.addArrangedSubview(durationField)
        
        stack.addArrangedSubview(createLabel("视频最大播放时长 (秒, 0为不限制)"))
        configureField(videoDurationField, placeholder: "0")
        videoDurationField.keyboardType = .numberPad
        stack.addArrangedSubview(videoDurationField)
        
        stack.addArrangedSubview(createLabel("播放背景音乐"))
        stack.addArrangedSubview(musicSwitch)
        
        stack.addArrangedSubview(createLabel("视频播放时继续背景音乐"))
        stack.addArrangedSubview(musicWithVideoSwitch)
        
        let musicSettingsBtn = UIButton(type: .system)
        musicSettingsBtn.setTitle("配置背景音乐 (播放列表/模式) >", for: .normal)
        musicSettingsBtn.contentHorizontalAlignment = .left
        musicSettingsBtn.addTarget(self, action: #selector(openMusicSettings), for: .touchUpInside)
        stack.addArrangedSubview(musicSettingsBtn)
        stack.addArrangedSubview(createLabel("视频静音"))
        stack.addArrangedSubview(videoMutedSwitch)
        
        stack.addArrangedSubview(createLabel("图片显示模式"))
        stack.addArrangedSubview(contentModeSegment)
        
        // Schedule Section
        stack.addArrangedSubview(createLabel("休眠时间 (黑屏)"))
        sleepPicker.datePickerMode = .time
        stack.addArrangedSubview(sleepPicker)
        
        stack.addArrangedSubview(createLabel("唤醒时间"))
        wakePicker.datePickerMode = .time
        stack.addArrangedSubview(wakePicker)
        
        // Cache Section
        let cacheSectionLabel = createLabel("缓存管理")
        stack.addArrangedSubview(cacheSectionLabel)
        
        // Cache size label
        let cacheSizeLabel = UILabel()
        cacheSizeLabel.tag = 998
        cacheSizeLabel.text = "缓存大小: 计算中..."
        cacheSizeLabel.textColor = .gray
        cacheSizeLabel.font = UIFont.systemFont(ofSize: 14)
        updateCacheSizeLabel(cacheSizeLabel)
        stack.addArrangedSubview(cacheSizeLabel)
        
        // Clear cache button
        let clearCacheBtn = UIButton(type: .system)
        clearCacheBtn.setTitle("清空缓存", for: .normal)
        clearCacheBtn.backgroundColor = .systemRed
        clearCacheBtn.setTitleColor(.white, for: .normal)
        clearCacheBtn.layer.cornerRadius = 8
        clearCacheBtn.addTarget(self, action: #selector(clearCache), for: .touchUpInside)
        clearCacheBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(clearCacheBtn)
        
        // Navigation Items
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(save))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(cancel))
        
        loadData()
    }
    
    @objc private func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func openMusicSettings() {
        let vc = BackgroundMusicSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func createLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.boldSystemFont(ofSize: 14)
        l.textColor = .darkGray
        return l
    }
    
    private func configureField(_ field: UITextField, placeholder: String, isSecure: Bool = false) {
        field.borderStyle = .roundedRect
        field.placeholder = placeholder
        field.isSecureTextEntry = isSecure
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
    }
    
    var onSave: (() -> Void)?

    @objc private func save() {
        let defaults = UserDefaults.standard
        let oldPath = defaults.string(forKey: AppConstants.Keys.kWebDAVSelectedPath)
        
        defaults.set(hostField.text, forKey: AppConstants.Keys.kWebDAVHost)
        defaults.set(userField.text, forKey: AppConstants.Keys.kWebDAVUser)
        defaults.set(passField.text, forKey: AppConstants.Keys.kWebDAVPassword)
        
        if let durationText = durationField.text, let duration = Double(durationText) {
            defaults.set(duration, forKey: AppConstants.Keys.kDisplayDuration)
        }
        
        if let videoDurationText = videoDurationField.text, let videoDuration = Double(videoDurationText) {
            defaults.set(videoDuration, forKey: AppConstants.Keys.kVideoMaxDuration)
        }
        
        defaults.set(musicSwitch.isOn, forKey: AppConstants.Keys.kPlayBackgroundMusic)
        defaults.set(musicWithVideoSwitch.isOn, forKey: AppConstants.Keys.kPlayMusicWithVideo)
        defaults.set(videoMutedSwitch.isOn, forKey: AppConstants.Keys.kVideoMuted)
        defaults.set(contentModeSegment.selectedSegmentIndex, forKey: AppConstants.Keys.kContentMode)
        
        // Save dates (only time components matter)
        defaults.set(sleepPicker.date, forKey: AppConstants.Keys.kSleepTime)
        defaults.set(wakePicker.date, forKey: AppConstants.Keys.kWakeTime)
        defaults.synchronize()
        
        // Check if WebDAV path changed - if so, notify to reload media
        let newPath = defaults.string(forKey: AppConstants.Keys.kWebDAVSelectedPath)
        if oldPath != newPath {
            // Path changed, should reload media
            print("Settings: WebDAV path changed, will reload media")
        }
        
        // Notify changes
        onSave?()
        
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func testConnection() {
        guard let host = hostField.text, !host.isEmpty,
              let user = userField.text,
              let pass = passField.text else {
            showAlert(title: "提示", message: "请先填写WebDAV配置信息")
            return
        }
        
        let config = WebDAVConfig(host: host, username: user, password: pass)
        let client = WebDAVClient(config: config)
        
        // Show loading
        let alert = UIAlertController(title: "测试连接", message: "正在连接...", preferredStyle: .alert)
        present(alert, animated: true)
        
        client.testConnection { [weak self] success, error in
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
                    if success {
                        self?.showAlert(title: "成功", message: "WebDAV连接成功！")
                    } else {
                        self?.showAlert(title: "失败", message: error ?? "无法连接到WebDAV服务器")
                    }
                }
            }
        }
    }
    
    @objc private func selectFolder() {
        guard let host = hostField.text, !host.isEmpty,
              let _ = userField.text,
              let _ = passField.text else {
            showAlert(title: "提示", message: "请先填写并保存WebDAV配置信息")
            return
        }
        
        // Save current values first
        let defaults = UserDefaults.standard
        defaults.set(hostField.text, forKey: AppConstants.Keys.kWebDAVHost)
        defaults.set(userField.text, forKey: AppConstants.Keys.kWebDAVUser)
        defaults.set(passField.text, forKey: AppConstants.Keys.kWebDAVPassword)
        
        let browserVC = WebDAVBrowserViewController()
        browserVC.onFolderSelected = { [weak self] selectedPath in
            let defaults = UserDefaults.standard
            defaults.set(selectedPath, forKey: AppConstants.Keys.kWebDAVSelectedPath)
            defaults.synchronize()
            
            // Update UI
            if let label = self?.view.viewWithTag(999) as? UILabel {
                label.text = "已选择: \(selectedPath)"
            }
            
            // Update cache size after folder selection
            if let cacheLabel = self?.view.viewWithTag(998) as? UILabel {
                self?.updateCacheSizeLabel(cacheLabel)
            }
            
            // Notify that folder was selected (will trigger media reload)
            self?.showAlert(title: "成功", message: "已选择文件夹: \(selectedPath)\n\n返回主页将自动加载该文件夹中的照片和视频。") {
                // Optionally trigger save callback to reload media
                self?.onSave?()
            }
        }
        
        let nav = UINavigationController(rootViewController: browserVC)
        present(nav, animated: true)
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    private func loadData() {
        let defaults = UserDefaults.standard
        hostField.text = defaults.string(forKey: AppConstants.Keys.kWebDAVHost)
        userField.text = defaults.string(forKey: AppConstants.Keys.kWebDAVUser)
        passField.text = defaults.string(forKey: AppConstants.Keys.kWebDAVPassword)
        
        // Load selected folder
        if let selectedPath = defaults.string(forKey: AppConstants.Keys.kWebDAVSelectedPath), !selectedPath.isEmpty {
            if let label = view.viewWithTag(999) as? UILabel {
                label.text = "已选择: \(selectedPath)"
            }
        }
        
        let duration = defaults.double(forKey: AppConstants.Keys.kDisplayDuration)
        durationField.text = duration > 0 ? "\(Int(duration))" : "10"
        
        let videoDuration = defaults.double(forKey: AppConstants.Keys.kVideoMaxDuration)
        videoDurationField.text = "\(Int(videoDuration))"
        
        musicSwitch.isOn = defaults.bool(forKey: AppConstants.Keys.kPlayBackgroundMusic)
        musicWithVideoSwitch.isOn = defaults.bool(forKey: AppConstants.Keys.kPlayMusicWithVideo)
        
        videoMutedSwitch.isOn = defaults.bool(forKey: AppConstants.Keys.kVideoMuted)
        
        let contentModeIndex = defaults.integer(forKey: AppConstants.Keys.kContentMode)
        contentModeSegment.selectedSegmentIndex = contentModeIndex // 0: AspectFill (Default), 1: AspectFit
        
        if let sDate = defaults.object(forKey: AppConstants.Keys.kSleepTime) as? Date {
            sleepPicker.date = sDate
        }
        if let wDate = defaults.object(forKey: AppConstants.Keys.kWakeTime) as? Date {
            wakePicker.date = wDate
        }
        
        // Update cache size
        if let cacheLabel = view.viewWithTag(998) as? UILabel {
            updateCacheSizeLabel(cacheLabel)
        }
    }
    
    private func updateCacheSizeLabel(_ label: UILabel) {
        DispatchQueue.global(qos: .userInitiated).async {
            let size = ImageCacheService.shared.getCacheSize()
            let formattedSize = ImageCacheService.shared.formatBytes(size)
            DispatchQueue.main.async {
                label.text = "缓存大小: \(formattedSize)"
            }
        }
    }
    
    @objc private func clearCache() {
        let alert = UIAlertController(
            title: "清空缓存",
            message: "确定要清空所有缓存吗？这将删除所有已下载的图片和视频缓存。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            ImageCacheService.shared.clearCache()
            // Update cache size label
            if let label = self?.view.viewWithTag(998) as? UILabel {
                self?.updateCacheSizeLabel(label)
            }
            self?.showAlert(title: "成功", message: "缓存已清空")
        })
        
        present(alert, animated: true)
    }
}

