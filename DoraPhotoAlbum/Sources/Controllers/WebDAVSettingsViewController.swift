import UIKit

class WebDAVSettingsViewController: UIViewController, UITextFieldDelegate {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let enableSwitch = UISwitch()
    
    private let hostField = UITextField()
    private let userField = UITextField()
    private let passField = UITextField()
    
    private let selectedFolderLabel: UILabel = {
        let l = UILabel()
        l.text = "未选择文件夹"
        l.textColor = .gray
        l.font = UIFont.systemFont(ofSize: 14)
        l.numberOfLines = 0
        return l
    }()
    
    private var initialPaths: [String] = []
    
    var onSave: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "WebDAV"
        setupNavigation()
        setupLayout()
        loadData()
    }
    
    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(save))
    }
    
    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40)
        ])
        
        stack.addArrangedSubview(switchRow(title: "启用WebDAV", toggle: enableSwitch))
        
        stack.addArrangedSubview(createLabel("主机地址"))
        configureField(hostField, placeholder: "http://192.168.1.100:5005/photos")
        stack.addArrangedSubview(hostField)
        
        stack.addArrangedSubview(createLabel("用户名"))
        configureField(userField, placeholder: "admin")
        stack.addArrangedSubview(userField)
        
        stack.addArrangedSubview(createLabel("密码"))
        configureField(passField, placeholder: "password", isSecure: true)
        stack.addArrangedSubview(passField)
        
        let testBtn = makeButton(title: "测试连接", color: .appAccentBlue, action: #selector(testConnection))
        stack.addArrangedSubview(testBtn)
        
        let iCloudColor: UIColor = {
            if #available(iOS 13.0, *) {
                return .systemIndigo
            } else {
                return .appAccentBlue
            }
        }()
        let iCloudBtn = makeButton(title: "手动同步 iCloud 配置", color: iCloudColor, action: #selector(manualSyncICloud))
        stack.addArrangedSubview(iCloudBtn)
        
        let manageBtn = makeButton(title: "管理文件夹", color: .appAccentGreen, action: #selector(openPathsManager))
        stack.addArrangedSubview(manageBtn)
        
        let labelTitle = createLabel("已选择文件夹（可多个）")
        stack.addArrangedSubview(labelTitle)
        stack.addArrangedSubview(selectedFolderLabel)
    }
    
    private func createLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.boldSystemFont(ofSize: 14)
        l.textColor = .darkGray
        return l
    }
    
    private func switchRow(title: String, toggle: UISwitch) -> UIStackView {
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 12
        
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .darkGray
        
        hStack.addArrangedSubview(label)
        hStack.addArrangedSubview(toggle)
        return hStack
    }
    
    private func configureField(_ field: UITextField, placeholder: String, isSecure: Bool = false) {
        field.borderStyle = .roundedRect
        field.placeholder = placeholder
        field.isSecureTextEntry = isSecure
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.delegate = self
        field.heightAnchor.constraint(equalToConstant: 36).isActive = true
    }
    
    private func makeButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - Actions
    @objc private func save() {
        let settings = WebDAVSettingsManager.shared
        let oldPaths = initialPaths
        let wasEnabled = settings.bool(forKey: AppConstants.Keys.kWebDAVEnabled)
        
        settings.set(enableSwitch.isOn, forKey: AppConstants.Keys.kWebDAVEnabled)
        settings.set(hostField.text, forKey: AppConstants.Keys.kWebDAVHost)
        settings.set(userField.text, forKey: AppConstants.Keys.kWebDAVUser)
        settings.set(passField.text, forKey: AppConstants.Keys.kWebDAVPassword)
        
        let newPaths = settings.stringArray(forKey: AppConstants.Keys.kWebDAVSelectedPaths) ?? []
        if oldPaths != newPaths || wasEnabled != enableSwitch.isOn {
            print("Settings: WebDAV path or status changed, will reload media")
        }
        
        onSave?()
        if let nav = navigationController, nav.viewControllers.first === self {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
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
    
    @objc private func openPathsManager() {
        // Persist fields first so paths manager can use saved credentials.
        persistUIToSettings()
        
        let vc = WebDAVPathsViewController()
        vc.onSave = { [weak self] in
            self?.loadData()
            self?.onSave?()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func manualSyncICloud(_ sender: UIButton) {
        let sheet = UIAlertController(title: "iCloud 配置同步", message: "选择同步方式。注意：拉取/上传都会覆盖一端的配置。", preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "从 iCloud 拉取（覆盖本机）", style: .default) { [weak self] _ in
            self?.confirmPullFromiCloud()
        })
        
        sheet.addAction(UIAlertAction(title: "上传到 iCloud（覆盖云端）", style: .default) { [weak self] _ in
            self?.confirmPushToiCloud()
        })
        
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad compatibility
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(sheet, animated: true)
    }
    
    private func confirmPullFromiCloud() {
        let alert = UIAlertController(title: "确认拉取", message: "将从 iCloud 拉取 WebDAV 配置并覆盖本机设置。\n\n未保存的修改将丢失。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "拉取", style: .destructive) { [weak self] _ in
            self?.performPullFromiCloud()
        })
        present(alert, animated: true)
    }
    
    private func confirmPushToiCloud() {
        let alert = UIAlertController(title: "确认上传", message: "将把当前页面内容保存并上传到 iCloud，可能覆盖其它设备上的 WebDAV 配置。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "上传", style: .destructive) { [weak self] _ in
            self?.performPushToiCloud()
        })
        present(alert, animated: true)
    }
    
    private func persistUIToSettings() {
        let settings = WebDAVSettingsManager.shared
        settings.set(enableSwitch.isOn, forKey: AppConstants.Keys.kWebDAVEnabled)
        settings.set(hostField.text, forKey: AppConstants.Keys.kWebDAVHost)
        settings.set(userField.text, forKey: AppConstants.Keys.kWebDAVUser)
        settings.set(passField.text, forKey: AppConstants.Keys.kWebDAVPassword)
    }
    
    private func performPullFromiCloud() {
        let progress = UIAlertController(title: "同步中", message: "正在从 iCloud 拉取配置...", preferredStyle: .alert)
        present(progress, animated: true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            WebDAVSettingsManager.shared.syncFromiCloud(notify: false)
            DispatchQueue.main.async {
                progress.dismiss(animated: true) { [weak self] in
                    self?.loadData()
                    self?.onSave?()
                    self?.showAlert(title: "完成", message: "已从 iCloud 拉取并更新本机配置。")
                }
            }
        }
    }
    
    private func performPushToiCloud() {
        persistUIToSettings()
        
        let progress = UIAlertController(title: "同步中", message: "正在上传到 iCloud...", preferredStyle: .alert)
        present(progress, animated: true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            WebDAVSettingsManager.shared.syncToiCloud()
            DispatchQueue.main.async {
                progress.dismiss(animated: true) { [weak self] in
                    self?.onSave?()
                    self?.showAlert(title: "完成", message: "已上传当前 WebDAV 配置到 iCloud。")
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    private func loadData() {
        let settings = WebDAVSettingsManager.shared
        enableSwitch.isOn = settings.bool(forKey: AppConstants.Keys.kWebDAVEnabled)
        hostField.text = settings.string(forKey: AppConstants.Keys.kWebDAVHost)
        userField.text = settings.string(forKey: AppConstants.Keys.kWebDAVUser)
        passField.text = settings.string(forKey: AppConstants.Keys.kWebDAVPassword)
        
        let paths = settings.stringArray(forKey: AppConstants.Keys.kWebDAVSelectedPaths) ?? []
        initialPaths = paths
        updateSelectedFoldersSummary(paths)
    }

    private func updateSelectedFoldersSummary(_ paths: [String]) {
        if paths.isEmpty {
            selectedFolderLabel.text = "未选择文件夹"
            selectedFolderLabel.textColor = .gray
            return
        }
        selectedFolderLabel.textColor = .darkGray
        if paths.count <= 3 {
            let display = paths.map { "• \($0)" }.joined(separator: "\n")
            selectedFolderLabel.text = "已选择 \(paths.count) 个：\n\(display)"
        } else {
            let first = paths.prefix(3).map { "• \($0)" }.joined(separator: "\n")
            selectedFolderLabel.text = "已选择 \(paths.count) 个（仅显示前 3 个）：\n\(first)\n…"
        }
    }
}

