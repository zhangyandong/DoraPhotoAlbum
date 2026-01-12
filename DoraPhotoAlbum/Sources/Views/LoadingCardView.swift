import UIKit

class LoadingCardView: UIView {
    
    enum LoadingState {
        case loading
        case completed(count: Int, message: String? = nil)
        case error(message: String)
        case disabled(message: String)
    }
    
    let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let stateIconView = UIImageView()
    private let activityIndicator: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            return UIActivityIndicatorView(style: .medium)
        } else {
            return UIActivityIndicatorView(style: .gray)
        }
    }()
    private let reloadButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    
    private let topRow = UIStackView()
    private let trailingButtonsStack = UIStackView()
    private let stateRow = UIStackView()
    
    var onReload: (() -> Void)?
    var onSettings: (() -> Void)?
    
    var state: LoadingState = .loading {
        didSet {
            // `state` may be updated from async callbacks. Ensure UI work happens on main.
            if Thread.isMainThread {
                updateUI()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.updateUI()
                }
            }
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
        backgroundColor = .appSecondarySystemGroupedBackground
        layer.cornerRadius = 16
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 0.86, alpha: 1.0).cgColor
        
        // Title
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .appLabel
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Trailing buttons
        configureIconButton(settingsButton, systemName: "gearshape", fallbackTitle: "设置")
        configureIconButton(reloadButton, systemName: "arrow.clockwise", fallbackTitle: "刷新")
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        reloadButton.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        
        // State icon + spinner
        stateIconView.translatesAutoresizingMaskIntoConstraints = false
        stateIconView.contentMode = .scaleAspectFit
        stateIconView.tintColor = .appSecondaryLabel
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Status label
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .appSecondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Layout stacks
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10
        topRow.translatesAutoresizingMaskIntoConstraints = false
        
        trailingButtonsStack.axis = .horizontal
        trailingButtonsStack.alignment = .center
        trailingButtonsStack.spacing = 10
        trailingButtonsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.required, for: .horizontal)
        
        trailingButtonsStack.addArrangedSubview(reloadButton)
        trailingButtonsStack.addArrangedSubview(settingsButton)
        
        topRow.addArrangedSubview(titleLabel)
        topRow.addArrangedSubview(spacer)
        topRow.addArrangedSubview(trailingButtonsStack)
        
        stateRow.axis = .horizontal
        stateRow.alignment = .center
        stateRow.spacing = 10
        stateRow.translatesAutoresizingMaskIntoConstraints = false
        stateRow.addArrangedSubview(activityIndicator)
        stateRow.addArrangedSubview(stateIconView)
        stateRow.addArrangedSubview(statusLabel)
        
        addSubview(topRow)
        addSubview(stateRow)
        
        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            topRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            topRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            stateIconView.widthAnchor.constraint(equalToConstant: 18),
            stateIconView.heightAnchor.constraint(equalToConstant: 18),
            
            reloadButton.widthAnchor.constraint(equalToConstant: 36),
            reloadButton.heightAnchor.constraint(equalToConstant: 36),
            settingsButton.widthAnchor.constraint(equalToConstant: 36),
            settingsButton.heightAnchor.constraint(equalToConstant: 36),
            
            stateRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 10),
            stateRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stateRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stateRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
        
        updateUI()
    }
    
    private func configureIconButton(_ button: UIButton, systemName: String, fallbackTitle: String) {
        if #available(iOS 13.0, *) {
            let image = UIImage(systemName: systemName)
            button.setImage(image, for: .normal)
            button.tintColor = .appAccentBlue
        } else {
            button.setTitle(fallbackTitle, for: .normal)
            button.setTitleColor(.appAccentBlue, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        }
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.7)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.accessibilityTraits = .button
    }
    
    private func updateUI() {
        switch state {
        case .loading:
            statusLabel.text = "加载中…"
            statusLabel.textColor = .appSecondaryLabel
            stateIconView.isHidden = true
            activityIndicator.startAnimating()
            reloadButton.isHidden = true
            
        case .completed(let count, let message):
            statusLabel.text = message ?? "已加载 \(count) 个项目"
            statusLabel.textColor = .appAccentGreen
            activityIndicator.stopAnimating()
            stateIconView.isHidden = false
            if #available(iOS 13.0, *) {
                stateIconView.image = UIImage(systemName: "checkmark.circle.fill")
            } else {
                stateIconView.image = nil
            }
            stateIconView.tintColor = .appAccentGreen
            reloadButton.isHidden = false
            
        case .error(let message):
            statusLabel.text = message
            statusLabel.textColor = .appAccentRed
            activityIndicator.stopAnimating()
            stateIconView.isHidden = false
            if #available(iOS 13.0, *) {
                stateIconView.image = UIImage(systemName: "exclamationmark.triangle.fill")
            } else {
                stateIconView.image = nil
            }
            stateIconView.tintColor = .appAccentRed
            reloadButton.isHidden = false
            
        case .disabled(let message):
            statusLabel.text = message
            statusLabel.textColor = .appSecondaryLabel
            activityIndicator.stopAnimating()
            stateIconView.isHidden = false
            if #available(iOS 13.0, *) {
                stateIconView.image = UIImage(systemName: "minus.circle.fill")
            } else {
                stateIconView.image = nil
            }
            stateIconView.tintColor = .appSecondaryLabel
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

