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
        
        let testBtn = makeButton(title: "测试连接", color: .systemBlue, action: #selector(testConnection))
        stack.addArrangedSubview(testBtn)
        
        let selectBtn = makeButton(title: "选择文件夹", color: .systemGreen, action: #selector(selectFolder))
        stack.addArrangedSubview(selectBtn)
        
        let labelTitle = createLabel("已选择文件夹")
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
        let defaults = UserDefaults.standard
        let oldPath = defaults.string(forKey: AppConstants.Keys.kWebDAVSelectedPath)
        let wasEnabled = defaults.bool(forKey: AppConstants.Keys.kWebDAVEnabled)
        
        defaults.set(enableSwitch.isOn, forKey: AppConstants.Keys.kWebDAVEnabled)
        defaults.set(hostField.text, forKey: AppConstants.Keys.kWebDAVHost)
        defaults.set(userField.text, forKey: AppConstants.Keys.kWebDAVUser)
        defaults.set(passField.text, forKey: AppConstants.Keys.kWebDAVPassword)
        defaults.synchronize()
        
        let newPath = defaults.string(forKey: AppConstants.Keys.kWebDAVSelectedPath)
        if oldPath != newPath || wasEnabled != enableSwitch.isOn {
            print("Settings: WebDAV path or status changed, will reload media")
        }
        
        onSave?()
        navigationController?.popViewController(animated: true)
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
    
    @objc private func selectFolder() {
        guard let host = hostField.text, !host.isEmpty,
              let _ = userField.text,
              let _ = passField.text else {
            showAlert(title: "提示", message: "请先填写并保存WebDAV配置信息")
            return
        }
        
        let defaults = UserDefaults.standard
        defaults.set(hostField.text, forKey: AppConstants.Keys.kWebDAVHost)
        defaults.set(userField.text, forKey: AppConstants.Keys.kWebDAVUser)
        defaults.set(passField.text, forKey: AppConstants.Keys.kWebDAVPassword)
        
        let browserVC = WebDAVBrowserViewController()
        browserVC.onFolderSelected = { [weak self] selectedPath in
            let defaults = UserDefaults.standard
            defaults.set(selectedPath, forKey: AppConstants.Keys.kWebDAVSelectedPath)
            defaults.synchronize()
            
            self?.selectedFolderLabel.text = "已选择: \(selectedPath)"
            self?.showAlert(title: "成功", message: "已选择文件夹: \(selectedPath)\n\n返回主页将自动加载该文件夹中的照片和视频。") {
                self?.onSave?()
            }
        }
        
        let nav = UINavigationController(rootViewController: browserVC)
        present(nav, animated: true)
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
        let defaults = UserDefaults.standard
        enableSwitch.isOn = defaults.bool(forKey: AppConstants.Keys.kWebDAVEnabled)
        hostField.text = defaults.string(forKey: AppConstants.Keys.kWebDAVHost)
        userField.text = defaults.string(forKey: AppConstants.Keys.kWebDAVUser)
        passField.text = defaults.string(forKey: AppConstants.Keys.kWebDAVPassword)
        
        if let selectedPath = defaults.string(forKey: AppConstants.Keys.kWebDAVSelectedPath), !selectedPath.isEmpty {
            selectedFolderLabel.text = "已选择: \(selectedPath)"
        }
    }
}

