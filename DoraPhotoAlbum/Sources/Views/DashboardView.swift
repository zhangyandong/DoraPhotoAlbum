import UIKit
import CoreLocation

class DashboardView: UIView {
    
    private let timeLabel = UILabel()
    private let dateLabel = UILabel()
    private let fileTypeLabel = UILabel()
    private let metaLabel = UILabel()
    
    private var timer: Timer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        startClock()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Blur background for readability
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        addSubview(blurView)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15)
        ])
        
        // Time: 12:45
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        timeLabel.textColor = .white
        stack.addArrangedSubview(timeLabel)
        
        // Date: Mon, 12 Dec
        dateLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        dateLabel.textColor = UIColor(white: 0.9, alpha: 1)
        stack.addArrangedSubview(dateLabel)
        
        // File Type
        fileTypeLabel.font = UIFont.systemFont(ofSize: 14)
        fileTypeLabel.textColor = UIColor(white: 0.9, alpha: 1)
        fileTypeLabel.isHidden = true
        stack.addArrangedSubview(fileTypeLabel)
        
        // Photo Meta (Hidden by default)
        metaLabel.font = UIFont.systemFont(ofSize: 12)
        metaLabel.textColor = UIColor(white: 0.7, alpha: 1)
        metaLabel.numberOfLines = 2
        metaLabel.isHidden = true
        stack.addArrangedSubview(metaLabel)
    }
    
    private func startClock() {
        updateTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTime()
        }
        
        // Prevent Burn-in: Randomly shift position slightly every min
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.shiftPosition()
        }
    }
    
    private func updateTime() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        timeLabel.text = formatter.string(from: now)
        
        formatter.dateFormat = "MMM d日 EEEE"
        dateLabel.text = formatter.string(from: now)
    }
    
    func updateFileType(_ type: MediaType) {
        switch type {
        case .image:
            fileTypeLabel.text = "图片"
        case .livePhoto:
            fileTypeLabel.text = "Live Photo"
        case .video:
            fileTypeLabel.text = "视频"
        }
        fileTypeLabel.isHidden = false
    }
    
    func updatePhotoMeta(date: Date?, location: String?) {
        guard let date = date else {
            metaLabel.isHidden = true
            return
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        var text = formatter.string(from: date)
        
        // "3 Years Ago" logic
        let components = Calendar.current.dateComponents([.year], from: date, to: Date())
        if let years = components.year, years > 0 {
            text += " (\(years)年前)"
        }
        
        if let loc = location {
            text += "\n📍 \(loc)"
        }
        
        metaLabel.text = text
        metaLabel.isHidden = false
    }
    
    private func shiftPosition() {
        // Slight random offset to prevent pixel burn-in
        let randomX = CGFloat.random(in: -2...2)
        let randomY = CGFloat.random(in: -2...2)
        transform = CGAffineTransform(translationX: randomX, y: randomY)
    }
    
    deinit {
        timer?.invalidate()
    }
}

