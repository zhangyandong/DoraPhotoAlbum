import UIKit
import Photos
import AVFoundation
import AVKit
import ImageIO

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

        let browseColor: UIColor = {
            if #available(iOS 13.0, *) { return .systemBlue }
            return .blue
        }()
        let browseBtn = makeButton(title: "查看缓存图片/视频", color: browseColor, action: #selector(openCacheBrowser))
        stack.addArrangedSubview(browseBtn)
        
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
    @objc private func openCacheBrowser() {
        let vc = CacheBrowserViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

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

// MARK: - Cache Browser (View / Delete / Save)

private final class CacheBrowserViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private var items: [UnifiedMediaItem] = []
    private var collectionView: UICollectionView!
    private let statusLabel = UILabel()
    private let activity = UIActivityIndicatorView(style: .gray)

    private var isSelecting: Bool = false {
        didSet { updateSelectionUI(animated: true) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "缓存浏览"
        setupUI()
        reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Leave selection mode cleanly
        if isSelecting {
            isSelecting = false
        }
    }

    private func setupUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "选择", style: .plain, target: self, action: #selector(toggleSelectMode))

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .white
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CacheMediaCell.self, forCellWithReuseIdentifier: CacheMediaCell.reuseId)
        view.addSubview(collectionView)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont.systemFont(ofSize: 13)
        statusLabel.textColor = .gray
        statusLabel.numberOfLines = 2
        view.addSubview(statusLabel)

        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.hidesWhenStopped = true
        view.addSubview(activity)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            collectionView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activity.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        navigationController?.setToolbarHidden(true, animated: false)
    }

    private func reloadData() {
        activity.startAnimating()
        DispatchQueue.global(qos: .userInitiated).async {
            let list = ImageCacheService.shared.listCachedMediaItems(limit: 5000)
            DispatchQueue.main.async {
                self.items = list
                self.collectionView.reloadData()
                self.activity.stopAnimating()
                self.updateStatusText()
            }
        }
    }

    private func updateStatusText() {
        if items.isEmpty {
            statusLabel.text = "暂无缓存文件"
        } else if isSelecting {
            let count = collectionView.indexPathsForSelectedItems?.count ?? 0
            statusLabel.text = "共 \(items.count) 项，已选择 \(count) 项"
        } else {
            statusLabel.text = "共 \(items.count) 项，点击可预览"
        }
    }

    @objc private func toggleSelectMode() {
        isSelecting.toggle()
    }

    private func updateSelectionUI(animated: Bool) {
        navigationItem.rightBarButtonItem?.title = isSelecting ? "完成" : "选择"
        if !isSelecting {
            // Clear selections
            collectionView.indexPathsForSelectedItems?.forEach { collectionView.deselectItem(at: $0, animated: false) }
        }
        updateToolbarItems()
        updateStatusText()

        let hideToolbar = !isSelecting
        navigationController?.setToolbarHidden(hideToolbar, animated: animated)
    }

    private func updateToolbarItems() {
        guard isSelecting else {
            toolbarItems = nil
            return
        }

        let save = UIBarButtonItem(title: "保存到相册", style: .plain, target: self, action: #selector(saveSelected))
        let delete = UIBarButtonItem(title: "删除", style: .plain, target: self, action: #selector(deleteSelected))
        if #available(iOS 13.0, *) {
            delete.tintColor = .systemRed
        } else {
            delete.tintColor = .red
        }

        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbarItems = [delete, flex, save]
    }

    // MARK: - UICollectionView

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CacheMediaCell.reuseId, for: indexPath) as! CacheMediaCell
        let item = items[indexPath.item]
        cell.configure(with: item)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isSelecting {
            updateStatusText()
            return
        }
        collectionView.deselectItem(at: indexPath, animated: true)
        openPreview(for: items[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isSelecting { updateStatusText() }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let columns: CGFloat = isPad ? 5 : 3
        let spacing: CGFloat = (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing ?? 8
        let totalSpacing = spacing * (columns - 1)
        let itemW = floor((width - totalSpacing) / columns)
        return CGSize(width: itemW, height: itemW)
    }

    private func openPreview(for item: UnifiedMediaItem) {
        switch item.type {
        case .image, .livePhoto:
            let vc = CacheImagePreviewViewController(item: item)
            vc.onDidDelete = { [weak self] in self?.reloadData() }
            navigationController?.pushViewController(vc, animated: true)
        case .video:
            let vc = CacheVideoPreviewViewController(item: item)
            vc.onDidDelete = { [weak self] in self?.reloadData() }
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - Actions (Batch)

    @objc private func deleteSelected() {
        let selected = collectionView.indexPathsForSelectedItems ?? []
        guard !selected.isEmpty else {
            showAlert(title: "提示", message: "请先选择要删除的缓存文件")
            return
        }
        let toDelete = selected.map { items[$0.item] }.compactMap { $0.cachedFileURL }

        let alert = UIAlertController(title: "删除缓存", message: "确定要删除选中的 \(toDelete.count) 项缓存吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            let deleted = ImageCacheService.shared.deleteCachedFiles(at: toDelete)
            self.showAlert(title: "完成", message: "已删除 \(deleted) 项")
            self.reloadData()
            self.isSelecting = false
        })
        present(alert, animated: true)
    }

    @objc private func saveSelected() {
        let selected = collectionView.indexPathsForSelectedItems ?? []
        guard !selected.isEmpty else {
            showAlert(title: "提示", message: "请先选择要保存的缓存文件")
            return
        }
        let toSave = selected.map { items[$0.item] }.compactMap { $0.cachedFileURL }
        saveFileURLsToPhotoLibrary(toSave)
    }

    private func saveFileURLsToPhotoLibrary(_ fileURLs: [URL]) {
        activity.startAnimating()
        CachePhotoLibraryHelper.requestAddOnlyAuthorization { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.activity.stopAnimating()
                self.showAlert(title: "需要权限", message: "请在系统设置中允许访问相册，才能保存到本机相册。")
                return
            }

            PHPhotoLibrary.shared().performChanges({
                for url in fileURLs {
                    let ext = url.pathExtension.lowercased()
                    if CachePhotoLibraryHelper.isVideoExtension(ext) {
                        _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    } else {
                        _ = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                    }
                }
            }) { success, error in
                DispatchQueue.main.async {
                    self.activity.stopAnimating()
                    if success {
                        self.showAlert(title: "成功", message: "已保存 \(fileURLs.count) 项到本机相册")
                        self.isSelecting = false
                    } else {
                        self.showAlert(title: "失败", message: error?.localizedDescription ?? "保存失败")
                    }
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Cell

private final class CacheMediaCell: UICollectionViewCell {
    static let reuseId = "CacheMediaCell"

    private let imageView = UIImageView()
    private let badgeLabel = UILabel()
    private let checkView = UIView()
    private let checkLabel = UILabel()

    private var currentItemId: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        badgeLabel.layer.cornerRadius = 6
        badgeLabel.layer.masksToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.text = "视频"
        badgeLabel.isHidden = true
        contentView.addSubview(badgeLabel)

        checkView.translatesAutoresizingMaskIntoConstraints = false
        checkView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        checkView.layer.cornerRadius = 10
        checkView.isHidden = true
        contentView.addSubview(checkView)

        checkLabel.translatesAutoresizingMaskIntoConstraints = false
        checkLabel.textColor = .white
        checkLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        checkLabel.textAlignment = .center
        checkLabel.text = "✓"
        checkView.addSubview(checkLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            badgeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            badgeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 34),
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),

            checkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            checkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkView.widthAnchor.constraint(equalToConstant: 20),
            checkView.heightAnchor.constraint(equalToConstant: 20),

            checkLabel.centerXAnchor.constraint(equalTo: checkView.centerXAnchor),
            checkLabel.centerYAnchor.constraint(equalTo: checkView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isSelected: Bool {
        didSet { updateSelectionUI() }
    }

    private func updateSelectionUI() {
        if isSelected {
            contentView.layer.borderWidth = 2
            if #available(iOS 13.0, *) {
                contentView.layer.borderColor = UIColor.systemBlue.cgColor
            } else {
                contentView.layer.borderColor = UIColor.blue.cgColor
            }
            checkView.isHidden = false
        } else {
            contentView.layer.borderWidth = 0
            contentView.layer.borderColor = nil
            checkView.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        badgeLabel.isHidden = true
        currentItemId = nil
    }

    func configure(with item: UnifiedMediaItem) {
        currentItemId = item.id
        badgeLabel.isHidden = (item.type != .video)

        guard let url = item.cachedFileURL else {
            imageView.image = nil
            return
        }

        let itemId = item.id
        CacheThumbnailer.shared.thumbnail(for: url, type: item.type, targetPixel: 280) { [weak self] img in
            guard let self = self else { return }
            guard self.currentItemId == itemId else { return }
            self.imageView.image = img
        }
    }
}

// MARK: - Preview (Image)

private final class CacheImagePreviewViewController: UIViewController, UIScrollViewDelegate {
    private let item: UnifiedMediaItem
    var onDidDelete: (() -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let activity = UIActivityIndicatorView(style: .gray)

    init(item: UnifiedMediaItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "预览"

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "操作", style: .plain, target: self, action: #selector(showActions))

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        view.addSubview(scrollView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)

        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.hidesWhenStopped = true
        view.addSubview(activity)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

            activity.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        loadImage()
    }

    private func loadImage() {
        guard let url = item.cachedFileURL else { return }
        activity.startAnimating()
        DispatchQueue.global(qos: .userInitiated).async {
            let img = UIImage(contentsOfFile: url.path)
            DispatchQueue.main.async {
                self.activity.stopAnimating()
                self.imageView.image = img
            }
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    @objc private func showActions() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "保存到相册", style: .default) { [weak self] _ in
            self?.saveToPhotos()
        })
        sheet.addAction(UIAlertAction(title: "删除缓存", style: .destructive) { [weak self] _ in
            self?.deleteCache()
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    private func saveToPhotos() {
        guard let url = item.cachedFileURL else { return }
        activity.startAnimating()
        CachePhotoLibraryHelper.requestAddOnlyAuthorization { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.activity.stopAnimating()
                self.showAlert(title: "需要权限", message: "请在系统设置中允许访问相册，才能保存到本机相册。")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                _ = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            }) { success, error in
                DispatchQueue.main.async {
                    self.activity.stopAnimating()
                    if success {
                        self.showAlert(title: "成功", message: "已保存到本机相册")
                    } else {
                        self.showAlert(title: "失败", message: error?.localizedDescription ?? "保存失败")
                    }
                }
            }
        }
    }

    private func deleteCache() {
        guard let url = item.cachedFileURL else { return }
        let alert = UIAlertController(title: "删除缓存", message: "确定要删除该缓存文件吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            _ = ImageCacheService.shared.deleteCachedFiles(at: [url])
            self.onDidDelete?()
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Preview (Video)

private final class CacheVideoPreviewViewController: UIViewController {
    private let item: UnifiedMediaItem
    var onDidDelete: (() -> Void)?

    private var player: AVPlayer?
    private let playerVC = AVPlayerViewController()

    init(item: UnifiedMediaItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "预览"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "操作", style: .plain, target: self, action: #selector(showActions))

        guard let url = item.cachedFileURL else { return }
        player = AVPlayer(url: url)
        playerVC.player = player

        addChild(playerVC)
        playerVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
            playerVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            playerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player?.play()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }

    @objc private func showActions() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "保存到相册", style: .default) { [weak self] _ in
            self?.saveToPhotos()
        })
        sheet.addAction(UIAlertAction(title: "删除缓存", style: .destructive) { [weak self] _ in
            self?.deleteCache()
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    private func saveToPhotos() {
        guard let url = item.cachedFileURL else { return }
        CachePhotoLibraryHelper.requestAddOnlyAuthorization { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.showAlert(title: "需要权限", message: "请在系统设置中允许访问相册，才能保存到本机相册。")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.showAlert(title: "成功", message: "已保存到本机相册")
                    } else {
                        self.showAlert(title: "失败", message: error?.localizedDescription ?? "保存失败")
                    }
                }
            }
        }
    }

    private func deleteCache() {
        guard let url = item.cachedFileURL else { return }
        let alert = UIAlertController(title: "删除缓存", message: "确定要删除该缓存文件吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            _ = ImageCacheService.shared.deleteCachedFiles(at: [url])
            self.onDidDelete?()
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Thumbnail + Photos Helper

private final class CacheThumbnailer {
    static let shared = CacheThumbnailer()
    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "com.doraphotoalbum.cachethumb", qos: .userInitiated)

    private init() {
        cache.countLimit = 400
        cache.totalCostLimit = 60 * 1024 * 1024
    }

    func thumbnail(for fileURL: URL, type: MediaType, targetPixel: Int, completion: @escaping (UIImage?) -> Void) {
        let key = "\(fileURL.path)|\(targetPixel)" as NSString
        if let img = cache.object(forKey: key) {
            completion(img)
            return
        }

        queue.async {
            let img: UIImage?
            switch type {
            case .video:
                img = self.makeVideoThumbnail(url: fileURL, targetPixel: targetPixel)
            case .image, .livePhoto:
                img = self.makeImageThumbnail(url: fileURL, targetPixel: targetPixel)
            }
            if let img = img {
                let cost = Int(img.size.width * img.size.height * img.scale * img.scale)
                self.cache.setObject(img, forKey: key, cost: cost)
            }
            DispatchQueue.main.async { completion(img) }
        }
    }

    private func makeImageThumbnail(url: URL, targetPixel: Int) -> UIImage? {
        // Fast downsample using ImageIO
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return UIImage(contentsOfFile: url.path)
        }
        let options: [NSString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            return UIImage(contentsOfFile: url.path)
        }
        return UIImage(cgImage: cg)
    }

    private func makeVideoThumbnail(url: URL, targetPixel: Int) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: targetPixel, height: targetPixel)
        do {
            let cg = try generator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 600), actualTime: nil)
            return UIImage(cgImage: cg)
        } catch {
            return nil
        }
    }
}

private enum CachePhotoLibraryHelper {
    static func requestAddOnlyAuthorization(completion: @escaping (Bool) -> Void) {
        if #available(iOS 14.0, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    completion(status == .authorized || status == .limited)
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized)
                }
            }
        }
    }

    static func isVideoExtension(_ ext: String) -> Bool {
        let e = ext.lowercased()
        return e == "mp4" || e == "mov" || e == "m4v" || e == "avi" || e == "mkv"
    }
}
