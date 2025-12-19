import UIKit

class MusicSettingsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    
    private let musicSwitch = UISwitch()
    private let musicWithVideoSwitch = UISwitch()
    
    var onSave: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "背景音乐"
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
        
        stack.addArrangedSubview(switchRow(title: "播放背景音乐", toggle: musicSwitch))
        stack.addArrangedSubview(switchRow(title: "视频播放时继续背景音乐", toggle: musicWithVideoSwitch))
        
        let musicBtn = makeButton(title: "配置播放列表 / 模式 >", color: nil, action: #selector(openMusicSettings))
        musicBtn.contentHorizontalAlignment = .left
        stack.addArrangedSubview(musicBtn)
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
        defaults.set(musicSwitch.isOn, forKey: AppConstants.Keys.kPlayBackgroundMusic)
        defaults.set(musicWithVideoSwitch.isOn, forKey: AppConstants.Keys.kPlayMusicWithVideo)
        defaults.synchronize()
        
        onSave?()
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func openMusicSettings() {
        let vc = BackgroundMusicSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    // MARK: - Data
    private func loadData() {
        let defaults = UserDefaults.standard
        musicSwitch.isOn = defaults.bool(forKey: AppConstants.Keys.kPlayBackgroundMusic)
        musicWithVideoSwitch.isOn = defaults.bool(forKey: AppConstants.Keys.kPlayMusicWithVideo)
    }
}

