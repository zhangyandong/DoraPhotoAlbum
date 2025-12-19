import UIKit

class ClockSettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Properties
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    var onSave: (() -> Void)?
    
    private enum Section: Int, CaseIterable {
        case general
        case display
        
        var title: String? {
            switch self {
            case .general: return "General"
            case .display: return "Display"
            }
        }
    }
    
    private enum Row {
        case startInClockMode
        case theme
        case format24Hour
        case showSeconds
        case showDate
        
        var title: String {
            switch self {
            case .startInClockMode: return "默认开启时钟模式"
            case .theme: return "时钟样式"
            case .format24Hour: return "24小时制"
            case .showSeconds: return "显示秒"
            case .showDate: return "显示日期"
            }
        }
        
        var key: String {
            switch self {
            case .startInClockMode: return AppConstants.Keys.kStartInClockMode
            case .theme: return AppConstants.Keys.kClockTheme
            case .format24Hour: return AppConstants.Keys.kClockFormat24H
            case .showSeconds: return AppConstants.Keys.kClockShowSeconds
            case .showDate: return AppConstants.Keys.kClockShowDate
            }
        }
    }
    
    private let rows: [[Row]] = [
        [.startInClockMode, .theme],
        [.format24Hour, .showSeconds, .showDate]
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "时钟设置"
        view.backgroundColor = .white
        setupTableView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onSave?()
    }
    
    // MARK: - Setup
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows[section].count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "通用"
        case 1: return "显示"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        let row = rows[indexPath.section][indexPath.row]
        
        cell.textLabel?.text = row.title
        
        if row == .theme {
            // Theme Selector
            let currentTheme = UserDefaults.standard.integer(forKey: row.key)
            cell.detailTextLabel?.text = (currentTheme == 0) ? "数字时钟" : "圆盘时钟"
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView = nil
        } else {
            // Switch
            let switchControl = UISwitch()
            switchControl.isOn = UserDefaults.standard.bool(forKey: row.key)
            switchControl.tag = (indexPath.section * 10) + indexPath.row // Simple tagging
            switchControl.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
            
            cell.accessoryView = switchControl
            cell.detailTextLabel?.text = nil
            cell.selectionStyle = .none
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = rows[indexPath.section][indexPath.row]
        if row == .theme {
            showThemeSelection()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private func showThemeSelection() {
        let alert = UIAlertController(title: "选择时钟样式", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "数字时钟", style: .default, handler: { _ in
            UserDefaults.standard.set(0, forKey: AppConstants.Keys.kClockTheme)
            NotificationCenter.default.post(name: .clockSettingsChanged, object: nil)
            self.tableView.reloadData()
        }))
        
        alert.addAction(UIAlertAction(title: "圆盘时钟", style: .default, handler: { _ in
            UserDefaults.standard.set(1, forKey: AppConstants.Keys.kClockTheme)
            NotificationCenter.default.post(name: .clockSettingsChanged, object: nil)
            self.tableView.reloadData()
        }))
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Actions
    
    @objc private func switchChanged(_ sender: UISwitch) {
        let section = sender.tag / 10
        let rowIdx = sender.tag % 10
        guard section < rows.count, rowIdx < rows[section].count else { return }
        
        let row = rows[section][rowIdx]
        UserDefaults.standard.set(sender.isOn, forKey: row.key)
        
        // Notify changes immediately if needed
        NotificationCenter.default.post(name: .clockSettingsChanged, object: nil)
    }
}
