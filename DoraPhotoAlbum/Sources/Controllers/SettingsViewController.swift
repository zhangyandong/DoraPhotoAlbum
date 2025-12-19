import UIKit

// MARK: - Settings Change Type
enum SettingsChangeType {
    case mediaSourceChanged
    case playbackConfigChanged
    case other
}

// MARK: - 入口页：仅做分类入口
class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private enum Item: Int, CaseIterable {
        case localAlbum
        case webdav
        case playback
        case music
        case clock
        case schedule
        case cache
        
        var title: String {
            switch self {
            case .localAlbum: return "本机相册"
            case .webdav: return "WebDAV"
            case .playback: return "播放与显示"
            case .music: return "背景音乐"
            case .clock: return "时钟模式"
            case .schedule: return "定时计划"
            case .cache: return "缓存管理"
            }
        }
        
        var detail: String {
            switch self {
            case .localAlbum: return "开关、权限"
            case .webdav: return "开关、服务器、账号、文件夹"
            case .playback: return "轮播间隔、视频、显示模式"
            case .music: return "开关、播放列表、模式"
            case .clock: return "默认开启、24小时制、日期"
            case .schedule: return "休眠与唤醒时间"
            case .cache: return "查看与清理缓存"
            }
        }
    }
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    var onSave: ((SettingsChangeType) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "设置"
        setupNavigation()
        setupTableView()
    }
    
    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "关闭", style: .plain, target: self, action: #selector(close))
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 60
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func close() {
        dismiss(animated: true)
    }
    
    // MARK: - Table
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Item.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = Item(rawValue: indexPath.row) else { return UITableViewCell() }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = item.title
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        cell.detailTextLabel?.text = item.detail
        cell.detailTextLabel?.textColor = .gray
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = Item(rawValue: indexPath.row) else { return }
        switch item {
        case .localAlbum:
            let vc = LocalAlbumSettingsViewController()
            vc.onSave = { [weak self] in
                self?.onSave?(.mediaSourceChanged)
                NotificationCenter.default.post(name: .mediaSourceChanged, object: nil)
            }
            navigationController?.pushViewController(vc, animated: true)
        case .webdav:
            let vc = WebDAVSettingsViewController()
            vc.onSave = { [weak self] in
                self?.onSave?(.mediaSourceChanged)
                NotificationCenter.default.post(name: .mediaSourceChanged, object: nil)
            }
            navigationController?.pushViewController(vc, animated: true)
        case .playback:
            let vc = PlaybackSettingsViewController()
            vc.onSave = { [weak self] in self?.onSave?(.playbackConfigChanged) }
            navigationController?.pushViewController(vc, animated: true)
        case .music:
            let vc = MusicSettingsViewController()
            vc.onSave = { [weak self] in self?.onSave?(.playbackConfigChanged) }
            navigationController?.pushViewController(vc, animated: true)
        case .clock:
            let vc = ClockSettingsViewController()
            vc.onSave = { [weak self] in self?.onSave?(.other) }
            navigationController?.pushViewController(vc, animated: true)
        case .schedule:
            let vc = ScheduleSettingsViewController()
            vc.onSave = { [weak self] in self?.onSave?(.other) }
            navigationController?.pushViewController(vc, animated: true)
        case .cache:
            let vc = CacheSettingsViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
