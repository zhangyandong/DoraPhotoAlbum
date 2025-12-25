import UIKit
import Photos

class LocalAlbumSettingsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let enableSwitch = UISwitch()
    private let statusLabel = UILabel()
    
    var onSave: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "本机相册"
        setupNavigation()
        setupLayout()
        loadData()
        updatePermissionStatus()
        
        // Listen for foreground notification to update permission status
        NotificationCenter.default.addObserver(self, selector: #selector(updatePermissionStatus), name: UIApplication.willEnterForegroundNotification, object: nil)
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
        
        stack.addArrangedSubview(switchRow(title: "启用本机相册", toggle: enableSwitch))
        
        statusLabel.textColor = .gray
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.numberOfLines = 0
        stack.addArrangedSubview(statusLabel)
        
        let settingsBtn = makeButton(title: "去设置开启权限", color: .systemBlue, action: #selector(openSystemSettings))
        stack.addArrangedSubview(settingsBtn)
        
        enableSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
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
    
    @objc private func switchChanged() {
        if enableSwitch.isOn {
            checkPermissionAndEnable()
        }
    }
    
    private func checkPermissionAndEnable() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.updatePermissionStatus()
                    if status != .authorized {
                        self?.enableSwitch.isOn = false
                    }
                }
            }
        case .denied, .restricted:
            showAlert(title: "需要权限", message: "请在设置中允许访问相册，否则无法加载本机照片。")
            // Don't turn off switch yet, user might go to settings
        case .authorized:
            break
        @unknown default:
            break
        }
    }
    
    @objc private func updatePermissionStatus() {
        let status = PHPhotoLibrary.authorizationStatus()
        var statusText = "权限状态: "
        switch status {
        case .authorized:
            statusText += "已授权"
        case .denied:
            statusText += "已拒绝"
        case .restricted:
            statusText += "受限制"
        case .notDetermined:
            statusText += "未请求"
        @unknown default:
            statusText += "未知"
        }
        statusLabel.text = statusText
    }
    
    @objc private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func save() {
        let defaults = UserDefaults.standard
        defaults.set(enableSwitch.isOn, forKey: AppConstants.Keys.kLocalAlbumEnabled)
        defaults.synchronize()
        
        onSave?()
        if let nav = navigationController, nav.viewControllers.first === self {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func loadData() {
        let defaults = UserDefaults.standard
        // Default to true if not set, or check logic
        // Assuming default false until enabled explicitly? Or default true?
        // Let's assume default true for local album if not set, for backward compatibility if it was always on.
        // But user asked to "add config", so maybe default is true.
        let isEnabled = defaults.object(forKey: AppConstants.Keys.kLocalAlbumEnabled) as? Bool ?? true
        enableSwitch.isOn = isEnabled
    }
}

