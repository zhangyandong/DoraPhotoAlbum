import UIKit

/// Manage WebDAV selected folders (multiple paths): add / delete single / clear all.
final class WebDAVPathsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private let tableView: UITableView = {
        let style: UITableView.Style
        if #available(iOS 13.0, *) {
            style = .insetGrouped
        } else {
            style = .grouped
        }
        return UITableView(frame: .zero, style: style)
    }()
    
    private var originalPaths: [String] = []
    private var paths: [String] = []
    var onSave: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WebDAV 文件夹"
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        
        setupNavigation()
        setupTableView()
        loadData()
    }
    
    private func setupNavigation() {
        // Keep default back button (do NOT override leftBarButtonItem)
        let addItem = UIBarButtonItem(title: "添加", style: .plain, target: self, action: #selector(addFolder))
        let clearItem = UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(clearAll))
        let saveItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(save))
        navigationItem.rightBarButtonItems = [saveItem, addItem, clearItem]
        updateSaveButtonState()
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PathCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadData() {
        originalPaths = WebDAVSettingsManager.shared.stringArray(forKey: AppConstants.Keys.kWebDAVSelectedPaths) ?? []
        paths = originalPaths
        tableView.reloadData()
        updateSaveButtonState()
    }
    
    private func persist() {
        WebDAVSettingsManager.shared.set(paths, forKey: AppConstants.Keys.kWebDAVSelectedPaths)
        onSave?()
    }
    
    private func isDirty() -> Bool {
        return paths != originalPaths
    }
    
    private func updateSaveButtonState() {
        guard let items = navigationItem.rightBarButtonItems else { return }
        // First item is "保存" per setupNavigation
        if let saveItem = items.first(where: { $0.title == "保存" }) {
            saveItem.isEnabled = isDirty()
        }
    }
    
    @objc private func save() {
        persist()
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func addFolder() {
        // Require WebDAV credentials first (same behavior as settings page)
        let settings = WebDAVSettingsManager.shared
        guard let host = settings.string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
              let _ = settings.string(forKey: AppConstants.Keys.kWebDAVUser),
              let _ = settings.string(forKey: AppConstants.Keys.kWebDAVPassword) else {
            showAlert(title: "提示", message: "请先在 WebDAV 设置中填写并保存服务器与账号信息")
            return
        }
        
        let browserVC = WebDAVBrowserViewController()
        browserVC.onFolderSelected = { [weak self] selectedPath in
            guard let self = self else { return }
            if !self.paths.contains(selectedPath) {
                self.paths.append(selectedPath)
                self.tableView.reloadData()
                self.updateSaveButtonState()
            }
            self.showAlert(title: "成功", message: "已添加文件夹: \(selectedPath)")
        }
        
        let nav = UINavigationController(rootViewController: browserVC)
        present(nav, animated: true)
    }
    
    @objc private func clearAll() {
        let alert = UIAlertController(title: "清空确认", message: "将清空所有已选择的 WebDAV 文件夹。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.paths = []
            self.tableView.reloadData()
            self.updateSaveButtonState()
        })
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(paths.count, 1)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PathCell", for: indexPath)
        cell.selectionStyle = .none
        
        if paths.isEmpty {
            cell.textLabel?.text = "未选择文件夹"
            cell.textLabel?.textColor = .gray
            cell.accessoryType = .none
        } else {
            cell.textLabel?.text = paths[indexPath.row]
            cell.textLabel?.textColor = .darkText
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
            cell.textLabel?.numberOfLines = 2
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate (single delete)
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !paths.isEmpty
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, !paths.isEmpty else { return }
        paths.remove(at: indexPath.row)
        tableView.reloadData()
        updateSaveButtonState()
    }
}


