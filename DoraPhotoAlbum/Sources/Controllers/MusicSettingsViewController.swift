import UIKit
import MediaPlayer

class MusicSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    // Settings
    private var playBackgroundMusic: Bool = false
    private var playMusicWithVideo: Bool = false
    private var selectedPlaylistName: String?
    private var selectedMode: Int = 0
    
    private var playlists: [MPMediaItemCollection] = []
    private let modes = ["顺序播放 (Sequential)", "随机播放 (Shuffle)", "单曲循环 (Single Loop)"]
    private var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    
    var onSave: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "背景音乐"
        setupNavigation()
        setupTableView()
        loadData()
        checkAuthorizationAndFetchPlaylists()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh authorization status when view appears
        checkAuthorizationAndFetchPlaylists()
    }
    
    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(save))
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
        // Register different cell types for different sections to avoid reuse issues
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SwitchCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ModeCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PlaylistCell")
    }
    
    private func loadData() {
        let defaults = UserDefaults.standard
        
        // Use defaults if not set
        if defaults.object(forKey: AppConstants.Keys.kPlayBackgroundMusic) != nil {
            playBackgroundMusic = defaults.bool(forKey: AppConstants.Keys.kPlayBackgroundMusic)
        } else {
            playBackgroundMusic = AppConstants.Defaults.playBackgroundMusic
        }
        
        if defaults.object(forKey: AppConstants.Keys.kPlayMusicWithVideo) != nil {
            playMusicWithVideo = defaults.bool(forKey: AppConstants.Keys.kPlayMusicWithVideo)
        } else {
            playMusicWithVideo = AppConstants.Defaults.playMusicWithVideo
        }
        
        if defaults.object(forKey: AppConstants.Keys.kSelectedPlaylist) != nil {
            selectedPlaylistName = defaults.string(forKey: AppConstants.Keys.kSelectedPlaylist)
        } else {
            selectedPlaylistName = AppConstants.Defaults.selectedPlaylist
        }
        
        if defaults.object(forKey: AppConstants.Keys.kMusicPlaybackMode) != nil {
            selectedMode = defaults.integer(forKey: AppConstants.Keys.kMusicPlaybackMode)
        } else {
            selectedMode = AppConstants.Defaults.musicPlaybackMode
        }
    }
    
    private func checkAuthorizationAndFetchPlaylists() {
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        
        switch authorizationStatus {
        case .authorized:
            fetchPlaylists()
        case .notDetermined:
            // Request authorization
            MPMediaLibrary.requestAuthorization { [weak self] status in
                guard let self = self else { return }
                self.authorizationStatus = status
                DispatchQueue.main.async {
                    if status == .authorized {
                        self.fetchPlaylists()
                    } else {
                        self.tableView.reloadData()
                    }
                }
            }
        case .denied, .restricted:
            // Show permission prompt in UI
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        @unknown default:
            break
        }
    }
    
    private func fetchPlaylists() {
        guard authorizationStatus == .authorized else { return }
        
        let query = MPMediaQuery.playlists()
        if let collections = query.collections {
            playlists = collections
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    private func showAuthorizationAlert() {
        let alert = UIAlertController(
            title: "需要音乐权限",
            message: "请在设置中允许访问媒体库，以便选择播放列表和播放背景音乐。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "前往设置", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        present(alert, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveSettings()
    }
    
    @objc private func save() {
        saveSettings()
        onSave?()
        navigationController?.popViewController(animated: true)
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(playBackgroundMusic, forKey: AppConstants.Keys.kPlayBackgroundMusic)
        defaults.set(playMusicWithVideo, forKey: AppConstants.Keys.kPlayMusicWithVideo)
        defaults.set(selectedPlaylistName, forKey: AppConstants.Keys.kSelectedPlaylist)
        defaults.set(selectedMode, forKey: AppConstants.Keys.kMusicPlaybackMode)
        defaults.synchronize()
        
        // Update Music Service configuration only (don't auto-play)
        // Music will be played in SlideShowViewController based on settings
        MusicService.shared.updateConfigurationOnly()
        
        // If music is currently playing but settings say it should be off, stop it
        if !playBackgroundMusic && MusicService.shared.isPlaying {
            MusicService.shared.pause()
        }
    }
    
    // MARK: - TableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4 // 0: Play Background Music, 1: Play Music With Video, 2: Mode, 3: Playlists
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0, 1:
            return 1 // Switch rows
        case 2:
            return modes.count
        case 3:
            if authorizationStatus == .authorized {
                return playlists.count + 1 // +1 for "All Songs"
            } else {
                return 1 // Show permission prompt row
            }
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return nil
        case 1:
            return nil
        case 2:
            return "播放模式"
        case 3:
            return "选择音乐来源"
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        switch indexPath.section {
        case 0, 1:
            // Switch cells
            cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
        case 2:
            // Mode cells
            cell = tableView.dequeueReusableCell(withIdentifier: "ModeCell", for: indexPath)
        case 3:
            // Playlist cells
            cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCell", for: indexPath)
        default:
            cell = tableView.dequeueReusableCell(withIdentifier: "ModeCell", for: indexPath)
        }
        
        // Completely reset cell state to avoid reuse issues
        resetCell(cell)
        
        switch indexPath.section {
        case 0: // Play Background Music switch
            cell.textLabel?.text = "播放背景音乐"
            cell.selectionStyle = .none
            
            let switchView = UISwitch()
            switchView.isOn = playBackgroundMusic
            switchView.addTarget(self, action: #selector(playBackgroundMusicChanged(_:)), for: .valueChanged)
            cell.accessoryView = switchView
            cell.accessoryType = .none
            
        case 1: // Play Music With Video switch
            cell.textLabel?.text = "视频播放时继续背景音乐"
            cell.selectionStyle = .none
            
            let switchView = UISwitch()
            switchView.isOn = playMusicWithVideo
            switchView.addTarget(self, action: #selector(playMusicWithVideoChanged(_:)), for: .valueChanged)
            cell.accessoryView = switchView
            cell.accessoryType = .none
            
        case 2: // Playback Mode
            cell.textLabel?.text = modes[indexPath.row]
            cell.accessoryType = (indexPath.row == selectedMode) ? .checkmark : .none
            cell.selectionStyle = .default
            
        case 3: // Playlists
            if authorizationStatus != .authorized {
                // Show permission prompt
                cell.textLabel?.text = "需要音乐权限 - 点击前往设置"
                cell.textLabel?.textColor = .systemBlue
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            } else if indexPath.row == 0 {
                cell.textLabel?.text = "所有歌曲 (All Songs)"
                if #available(iOS 13.0, *) {
                    cell.textLabel?.textColor = .label
                } else {
                    cell.textLabel?.textColor = .black
                }
                let isSelected = (selectedPlaylistName == nil || selectedPlaylistName == "")
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.selectionStyle = .default
            } else {
                let playlist = playlists[indexPath.row - 1]
                let name = playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String ?? "Unknown"
                cell.textLabel?.text = name
                if #available(iOS 13.0, *) {
                    cell.textLabel?.textColor = .label
                } else {
                    cell.textLabel?.textColor = .black
                }
                cell.accessoryType = (name == selectedPlaylistName) ? .checkmark : .none
                cell.selectionStyle = .default
            }
            
        default:
            break
        }
        
        return cell
    }
    
    private func resetCell(_ cell: UITableViewCell) {
        // Reset all cell properties to avoid reuse issues
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.textLabel?.text = nil
        cell.detailTextLabel?.text = nil
        cell.imageView?.image = nil
        cell.selectionStyle = .default
        if #available(iOS 13.0, *) {
            cell.textLabel?.textColor = .label
        } else {
            cell.textLabel?.textColor = .black
        }
        cell.detailTextLabel?.textColor = .gray
    }
    
    // MARK: - TableView Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0, 1:
            // Switches handle their own actions
            break
            
        case 2: // Playback Mode
            selectedMode = indexPath.row
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
            
        case 3: // Playlists
            if authorizationStatus != .authorized {
                // Show authorization alert
                showAuthorizationAlert()
            } else if indexPath.row == 0 {
                selectedPlaylistName = ""
                tableView.reloadSections(IndexSet(integer: 3), with: .none)
            } else {
                let playlist = playlists[indexPath.row - 1]
                selectedPlaylistName = playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String
                tableView.reloadSections(IndexSet(integer: 3), with: .none)
            }
            
        default:
            break
        }
    }
    
    // MARK: - Actions
    
    @objc private func playBackgroundMusicChanged(_ sender: UISwitch) {
        playBackgroundMusic = sender.isOn
    }
    
    @objc private func playMusicWithVideoChanged(_ sender: UISwitch) {
        playMusicWithVideo = sender.isOn
    }
}
