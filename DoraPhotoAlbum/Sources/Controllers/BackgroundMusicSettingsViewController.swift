import UIKit
import MediaPlayer

class BackgroundMusicSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var playlists: [MPMediaItemCollection] = []
    
    // Settings
    private var selectedPlaylistName: String?
    private var selectedMode: Int = 0
    
    private let modes = ["顺序播放 (Sequential)", "随机播放 (Shuffle)", "单曲循环 (Single Loop)"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "背景音乐设置"
        view.backgroundColor = .white
        
        setupTableView()
        loadData()
        fetchPlaylists()
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    private func loadData() {
        let defaults = UserDefaults.standard
        selectedPlaylistName = defaults.string(forKey: AppConstants.Keys.kSelectedPlaylist)
        selectedMode = defaults.integer(forKey: AppConstants.Keys.kMusicPlaybackMode)
    }
    
    private func fetchPlaylists() {
        MPMediaLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            
            let query = MPMediaQuery.playlists()
            if let collections = query.collections {
                self?.playlists = collections
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveSettings()
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(selectedPlaylistName, forKey: AppConstants.Keys.kSelectedPlaylist)
        defaults.set(selectedMode, forKey: AppConstants.Keys.kMusicPlaybackMode)
        defaults.synchronize()
        
        // Update Music Service immediately
        MusicService.shared.updatePlaybackConfiguration()
    }
    
    // MARK: - TableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2 // 0: Mode, 1: Playlists
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return modes.count
        } else {
            return playlists.count + 1 // +1 for "All Songs"
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "播放模式"
        } else {
            return "选择音乐来源"
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        if indexPath.section == 0 {
            cell.textLabel?.text = modes[indexPath.row]
            cell.accessoryType = (indexPath.row == selectedMode) ? .checkmark : .none
        } else {
            if indexPath.row == 0 {
                cell.textLabel?.text = "所有歌曲 (All Songs)"
                let isSelected = (selectedPlaylistName == nil || selectedPlaylistName == "")
                cell.accessoryType = isSelected ? .checkmark : .none
            } else {
                let playlist = playlists[indexPath.row - 1]
                let name = playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String ?? "Unknown"
                cell.textLabel?.text = name
                cell.accessoryType = (name == selectedPlaylistName) ? .checkmark : .none
            }
        }
        
        return cell
    }
    
    // MARK: - TableView Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            selectedMode = indexPath.row
        } else {
            if indexPath.row == 0 {
                selectedPlaylistName = ""
            } else {
                let playlist = playlists[indexPath.row - 1]
                selectedPlaylistName = playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String
            }
        }
        
        tableView.reloadData()
    }
}

