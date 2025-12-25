import UIKit

class CacheSettingsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let cacheSizeLabel: UILabel = {
        let l = UILabel()
        l.text = "缓存大小: 计算中..."
        l.textColor = .gray
        l.font = UIFont.systemFont(ofSize: 14)
        l.numberOfLines = 0
        return l
    }()
    
    private let freeSpaceLabel: UILabel = {
        let l = UILabel()
        l.text = "剩余空间: 计算中..."
        l.textColor = .gray
        l.font = UIFont.systemFont(ofSize: 14)
        l.numberOfLines = 0
        return l
    }()
    
    private let maxCacheValueLabel: UILabel = {
        let l = UILabel()
        l.text = "最大缓存: 计算中..."
        l.textColor = .gray
        l.font = UIFont.systemFont(ofSize: 14)
        l.numberOfLines = 0
        return l
    }()
    
    private let maxCacheSlider: UISlider = {
        let s = UISlider()
        s.minimumValue = 0.5
        s.maximumValue = 20
        s.value = 2
        return s
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "缓存管理"
        setupLayout()
        loadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
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
        
        stack.addArrangedSubview(createLabel("缓存大小"))
        stack.addArrangedSubview(cacheSizeLabel)
        
        stack.addArrangedSubview(createLabel("设备剩余空间"))
        stack.addArrangedSubview(freeSpaceLabel)
        
        stack.addArrangedSubview(createLabel("最大缓存空间（超过将自动删除最旧缓存）"))
        maxCacheSlider.addTarget(self, action: #selector(maxCacheSliderChanged), for: .valueChanged)
        maxCacheSlider.addTarget(self, action: #selector(maxCacheSliderCommitted), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        stack.addArrangedSubview(maxCacheSlider)
        stack.addArrangedSubview(maxCacheValueLabel)
        
        let clearColor: UIColor = {
            if #available(iOS 13.0, *) { return .systemRed }
            return .red
        }()
        let clearBtn = makeButton(title: "清空缓存", color: clearColor, action: #selector(clearCache))
        stack.addArrangedSubview(clearBtn)
    }
    
    private func createLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.boldSystemFont(ofSize: 14)
        l.textColor = .darkGray
        return l
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
    @objc private func clearCache() {
        let alert = UIAlertController(
            title: "清空缓存",
            message: "确定要清空所有缓存吗？这将删除所有已下载的图片和视频缓存。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            ImageCacheService.shared.clearCache()
            self?.loadData()
            self?.showAlert(title: "成功", message: "缓存已清空")
        })
        
        present(alert, animated: true)
    }
    
    @objc private func maxCacheSliderChanged() {
        let gb = roundedGBValue(Double(maxCacheSlider.value))
        maxCacheValueLabel.text = "最大缓存: \(String(format: "%.1f", gb)) GB"
    }
    
    @objc private func maxCacheSliderCommitted() {
        let gb = roundedGBValue(Double(maxCacheSlider.value))
        maxCacheSlider.value = Float(gb)
        let bytes = Int64(gb * 1024 * 1024 * 1024)
        ImageCacheService.shared.maxCacheSize = bytes
        maxCacheValueLabel.text = "最大缓存: \(String(format: "%.1f", gb)) GB"

        // Do NOT evict immediately. Eviction will happen gradually on subsequent cache writes.
        // Refresh UI soon (labels only).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.loadData()
        }
    }
    
    // MARK: - Helpers
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func loadData() {
        DispatchQueue.global(qos: .userInitiated).async {
            let size = ImageCacheService.shared.getCacheSize()
            let formattedSize = ImageCacheService.shared.formatBytes(size)
            let (freeBytes, totalBytes) = self.getDiskSpace()
            let formattedFree = ImageCacheService.shared.formatBytes(freeBytes)
            let formattedTotal = ImageCacheService.shared.formatBytes(totalBytes)
            
            let maxBytes = ImageCacheService.shared.maxCacheSize
            let maxGB = Double(maxBytes) / (1024 * 1024 * 1024)
            
            // Slider max: up to 50GB or 80% of total, whichever is smaller, but at least 2GB
            let totalGB = Double(totalBytes) / (1024 * 1024 * 1024)
            let sliderMax = max(2.0, min(50.0, totalGB * 0.8))
            let clampedGB = min(max(0.5, maxGB), sliderMax)
            let roundedGB = self.roundedGBValue(clampedGB)
            DispatchQueue.main.async {
                self.cacheSizeLabel.text = "缓存大小: \(formattedSize)"
                self.freeSpaceLabel.text = "剩余空间: \(formattedFree) / 总计: \(formattedTotal)"
                
                self.maxCacheSlider.minimumValue = 0.5
                self.maxCacheSlider.maximumValue = Float(sliderMax)
                self.maxCacheSlider.value = Float(roundedGB)
                self.maxCacheValueLabel.text = "最大缓存: \(String(format: "%.1f", roundedGB)) GB"
            }
        }
    }
    
    private func roundedGBValue(_ gb: Double) -> Double {
        // Round to 0.5GB steps
        return (gb * 2.0).rounded() / 2.0
    }
    
    private func getDiskSpace() -> (free: Int64, total: Int64) {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
            return (free, total)
        } catch {
            return (0, 0)
        }
    }
}

