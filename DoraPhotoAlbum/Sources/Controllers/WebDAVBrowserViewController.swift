import UIKit

class WebDAVBrowserViewController: UIViewController {
    
    private let tableView: UITableView = {
        let style: UITableView.Style
        if #available(iOS 13.0, *) {
            style = .insetGrouped
        } else {
            style = .grouped
        }
        return UITableView(frame: .zero, style: style)
    }()
    private var currentPath: String = "/"
    private var folders: [WebDAVClient.WebDAVResource] = []
    private var isLoading = false
    private var client: WebDAVClient?
    
    var onFolderSelected: ((String) -> Void)?
    
    private var pathComponents: [String] {
        return currentPath.split(separator: "/").map { String($0) }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemGroupedBackground
        } else {
            view.backgroundColor = .groupTableViewBackground
        }
        title = "选择文件夹"
        
        setupUI()
        updateNavigationBar()
        loadWebDAVConfig()
    }
    
    private func setupUI() {
        // Navigation bar will be configured in updateNavigationBar()
        
        // TableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func loadWebDAVConfig() {
        let settings = WebDAVSettingsManager.shared
        guard let host = settings.string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
              let user = settings.string(forKey: AppConstants.Keys.kWebDAVUser),
              let pass = settings.string(forKey: AppConstants.Keys.kWebDAVPassword) else {
            showError("请先在设置中配置WebDAV")
            return
        }
        
        let config = WebDAVConfig(host: host, username: user, password: pass)
        client = WebDAVClient(config: config)
        
        loadFolderContents()
    }
    
    private func loadFolderContents() {
        guard let client = client, !isLoading else { return }
        
        isLoading = true
        updateNavigationTitle()
        
        // Show loading indicator
        let activityIndicator: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            activityIndicator = UIActivityIndicatorView(style: .medium)
        } else {
            activityIndicator = UIActivityIndicatorView(style: .gray)
        }
        activityIndicator.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
        
        client.listDirectoryContents(path: currentPath) { [weak self] resources in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                print("WebDAV Browser: Received \(resources.count) resources")
                
                // Filter only directories
                self.folders = resources.filter { $0.isDirectory }
                
                print("WebDAV Browser: Found \(self.folders.count) folders")
                
                if self.folders.isEmpty && resources.isEmpty {
                    // No response might indicate an error
                    self.showError("无法加载文件夹，请检查路径或权限。\n\n提示：请确认WebDAV服务器支持PROPFIND方法。")
                } else if self.folders.isEmpty && !resources.isEmpty {
                    // Has resources but no folders
                    print("WebDAV Browser: Found \(resources.count) items but no folders")
                    self.tableView.reloadData()
                } else {
                    self.tableView.reloadData()
                }
                self.updateNavigationBar()
            }
        }
    }
    
    private func updateNavigationTitle() {
        if currentPath == "/" {
            title = "根目录"
        } else {
            let components = pathComponents
            title = components.last ?? "文件夹"
        }
    }
    
    private func updateNavigationBar() {
        // Restore select button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "选择当前",
            style: .done,
            target: self,
            action: #selector(selectCurrentFolder)
        )
        
        // Add back button if not at root
        if currentPath != "/" {
            navigationItem.leftBarButtonItems = [
                UIBarButtonItem(
                    title: "返回",
                    style: .plain,
                    target: self,
                    action: #selector(goBack)
                ),
                UIBarButtonItem(
                    barButtonSystemItem: .cancel,
                    target: self,
                    action: #selector(cancel)
                )
            ]
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancel)
            )
        }
    }
    
    @objc private func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func selectCurrentFolder() {
        onFolderSelected?(currentPath)
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func goBack() {
        guard currentPath != "/" else { return }
        
        // Go up one level
        let components = pathComponents
        if components.count <= 1 {
            currentPath = "/"
        } else {
            currentPath = "/" + components.dropLast().joined(separator: "/")
        }
        
        loadFolderContents()
    }
    
    private func navigateToFolder(_ folderPath: String) {
        currentPath = folderPath
        loadFolderContents()
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        })
        present(alert, animated: true)
    }
}

extension WebDAVBrowserViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return folders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let folder = folders[indexPath.row]
        
        // Extract folder name from href
        var folderName = folder.href
        // Remove current path prefix
        let cleanCurrentPath = currentPath.hasSuffix("/") ? String(currentPath.dropLast()) : currentPath
        if folderName.hasPrefix(cleanCurrentPath) {
            folderName = String(folderName.dropFirst(cleanCurrentPath.count))
        }
        // Remove leading/trailing slashes
        folderName = folderName.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        cell.textLabel?.text = folderName.isEmpty ? "根目录" : folderName
        cell.accessoryType = .disclosureIndicator
        
        // Set folder icon - compatible with iOS 12.5+
        if #available(iOS 13.0, *) {
            cell.imageView?.image = UIImage(systemName: "folder.fill")
            cell.imageView?.tintColor = .appAccentBlue
        } else {
            // Fallback for iOS 12: use a simple folder icon or default style
            cell.imageView?.image = nil
            // In iOS 12, we can rely on the accessory indicator or set a custom image
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let folder = folders[indexPath.row]
        navigateToFolder(folder.href)
    }
}
