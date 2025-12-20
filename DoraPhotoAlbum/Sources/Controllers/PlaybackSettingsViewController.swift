import UIKit

class PlaybackSettingsViewController: UIViewController, UITextFieldDelegate {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    
    private let durationField = UITextField()
    private let videoDurationField = UITextField()
    private let videoMutedSwitch = UISwitch()
    private let contentModeSegment = UISegmentedControl(items: ["填充 (裁剪)", "适应 (完整)"])
    
    var onSave: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "播放与显示"
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
        
        stack.addArrangedSubview(createLabel("幻灯片播放间隔(秒)"))
        configureField(durationField, placeholder: "\(Int(AppConstants.Defaults.displayDuration))", keyboard: .numberPad)
        stack.addArrangedSubview(durationField)
        
        stack.addArrangedSubview(createLabel("视频最大播放时长(秒, 0不限制)"))
        configureField(videoDurationField, placeholder: "\(Int(AppConstants.Defaults.videoMaxDuration))", keyboard: .numberPad)
        stack.addArrangedSubview(videoDurationField)
        
        stack.addArrangedSubview(switchRow(title: "视频静音", toggle: videoMutedSwitch))
        
        stack.addArrangedSubview(createLabel("图片显示模式"))
        stack.addArrangedSubview(contentModeSegment)
        contentModeSegment.heightAnchor.constraint(equalToConstant: 32).isActive = true
    }
    
    private func createLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.boldSystemFont(ofSize: 14)
        l.textColor = .darkGray
        return l
    }
    
    private func configureField(_ field: UITextField, placeholder: String, keyboard: UIKeyboardType) {
        field.borderStyle = .roundedRect
        field.placeholder = placeholder
        field.keyboardType = keyboard
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.delegate = self
        field.heightAnchor.constraint(equalToConstant: 36).isActive = true
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
    
    private func makeButton(title: String, color: UIColor?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        if let c = color {
            button.backgroundColor = c
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 8
        } else {
            button.setTitleColor(view.tintColor, for: .normal)
        }
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    // MARK: - Actions
    @objc private func save() {
        let defaults = UserDefaults.standard
        
        // Display duration: use default if empty or invalid
        if let durationText = durationField.text, !durationText.isEmpty, let duration = Double(durationText), duration > 0 {
            defaults.set(duration, forKey: AppConstants.Keys.kDisplayDuration)
        } else {
            defaults.set(AppConstants.Defaults.displayDuration, forKey: AppConstants.Keys.kDisplayDuration)
        }
        
        // Video max duration: use default if empty or invalid
        if let videoDurationText = videoDurationField.text, !videoDurationText.isEmpty, let videoDuration = Double(videoDurationText), videoDuration >= 0 {
            defaults.set(videoDuration, forKey: AppConstants.Keys.kVideoMaxDuration)
        } else {
            defaults.set(AppConstants.Defaults.videoMaxDuration, forKey: AppConstants.Keys.kVideoMaxDuration)
        }
        
        defaults.set(videoMutedSwitch.isOn, forKey: AppConstants.Keys.kVideoMuted)
        defaults.set(contentModeSegment.selectedSegmentIndex, forKey: AppConstants.Keys.kContentMode)
        defaults.synchronize()
        
        onSave?()
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Data
    private func loadData() {
        let defaults = UserDefaults.standard
        
        let duration = defaults.double(forKey: AppConstants.Keys.kDisplayDuration)
        durationField.text = duration > 0 ? "\(Int(duration))" : "\(Int(AppConstants.Defaults.displayDuration))"
        
        let videoDuration: Double
        if defaults.object(forKey: AppConstants.Keys.kVideoMaxDuration) != nil {
            videoDuration = defaults.double(forKey: AppConstants.Keys.kVideoMaxDuration)
        } else {
            videoDuration = AppConstants.Defaults.videoMaxDuration
        }
        videoDurationField.text = "\(Int(videoDuration))"
        
        // Use default if not set
        if defaults.object(forKey: AppConstants.Keys.kVideoMuted) == nil {
            videoMutedSwitch.isOn = AppConstants.Defaults.videoMuted
        } else {
            videoMutedSwitch.isOn = defaults.bool(forKey: AppConstants.Keys.kVideoMuted)
        }
        
        // Use default if not set
        let contentModeIndex: Int
        if defaults.object(forKey: AppConstants.Keys.kContentMode) == nil {
            contentModeIndex = AppConstants.Defaults.contentMode
        } else {
            contentModeIndex = defaults.integer(forKey: AppConstants.Keys.kContentMode)
        }
        contentModeSegment.selectedSegmentIndex = contentModeIndex
    }
}

