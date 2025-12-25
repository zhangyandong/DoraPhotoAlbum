import UIKit

class LoadingCardView: UIView {
    
    enum LoadingState {
        case loading
        case completed(count: Int)
        case error(message: String)
        case disabled(message: String)
    }
    
    let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let reloadButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    
    var onReload: (() -> Void)?
    var onSettings: (() -> Void)?
    
    var state: LoadingState = .loading {
        didSet {
            updateUI()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        if #available(iOS 13.0, *) {
            backgroundColor = .secondarySystemGroupedBackground
        } else {
            backgroundColor = .white
        }
        layer.cornerRadius = 14
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 0.85, alpha: 1.0).cgColor
        
        // Title
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        // Settings button (entry)
        if #available(iOS 13.0, *) {
            settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
            settingsButton.tintColor = .systemBlue
        } else {
            settingsButton.setTitle("设置", for: .normal)
            settingsButton.setTitleColor(.systemBlue, for: .normal)
            settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        }
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        addSubview(settingsButton)
        
        // Status
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .darkGray
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)
        
        // Reload button
        reloadButton.setTitle("刷新", for: .normal)
        reloadButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        reloadButton.setTitleColor(.systemBlue, for: .normal)
        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        reloadButton.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        addSubview(reloadButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: settingsButton.leadingAnchor, constant: -8),
            
            settingsButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            settingsButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 30),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: reloadButton.leadingAnchor, constant: -8),
            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            
            reloadButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            reloadButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            reloadButton.widthAnchor.constraint(equalToConstant: 72)
        ])
        
        updateUI()
    }
    
    private func updateUI() {
        switch state {
        case .loading:
            statusLabel.text = "加载中..."
            statusLabel.textColor = .darkGray
            reloadButton.isHidden = true
            
        case .completed(let count):
            statusLabel.text = "已加载 \(count) 个项目"
            statusLabel.textColor = .systemGreen
            reloadButton.isHidden = false
            
        case .error(let message):
            statusLabel.text = message
            statusLabel.textColor = .systemRed
            reloadButton.isHidden = false
            
        case .disabled(let message):
            statusLabel.text = message
            statusLabel.textColor = .gray
            reloadButton.isHidden = false
        }
    }
    
    @objc private func reloadTapped() {
        onReload?()
    }
    
    @objc private func settingsTapped() {
        onSettings?()
    }
}

