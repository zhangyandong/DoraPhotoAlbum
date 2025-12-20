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
    
    var onReload: (() -> Void)?
    
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
        backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        // Title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        // Status
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textColor = .lightGray
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)
        
        // Reload button
        reloadButton.setTitle("重新加载", for: .normal)
        reloadButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        reloadButton.setTitleColor(.systemBlue, for: .normal)
        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        reloadButton.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        addSubview(reloadButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: reloadButton.leadingAnchor, constant: -8),
            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            
            reloadButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            reloadButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            reloadButton.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        updateUI()
    }
    
    private func updateUI() {
        switch state {
        case .loading:
            statusLabel.text = "加载中..."
            statusLabel.textColor = .lightGray
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
            statusLabel.textColor = .darkGray
            reloadButton.isHidden = false
        }
    }
    
    @objc private func reloadTapped() {
        onReload?()
    }
}

