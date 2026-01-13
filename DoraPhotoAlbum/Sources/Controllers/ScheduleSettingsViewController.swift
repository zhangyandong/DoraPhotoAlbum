import UIKit

class ScheduleSettingsViewController: UIViewController {
    
    private var tableView: UITableView!
    private var plans: [SchedulePlan] = []
    
    var onSave: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appSystemGroupedBackground
        title = "定时计划"
        setupNavigation()
        setupTableView()
        loadPlans()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
    }
    
    private func setupNavigation() {
        navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPlan)), editButtonItem]
    }
    
    private func setupTableView() {
        // iOS 12 compatibility: `.insetGrouped` is only available on iOS 13+.
        if #available(iOS 13.0, *) {
            tableView = UITableView(frame: .zero, style: .insetGrouped)
        } else {
            tableView = UITableView(frame: .zero, style: .grouped)
        }
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 72
        tableView.allowsSelectionDuringEditing = true
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func addPlan() {
        let new = SchedulePlan.default(title: "计划 \(plans.count + 1)")
        openEditor(for: new, isNew: true)
    }
    
    // MARK: - Data
    private func loadPlans() {
        plans = SchedulePlanStore.load()
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func persistPlans() {
        SchedulePlanStore.save(plans)
        
        if plans.contains(where: { $0.sleepEnabled || $0.wakeEnabled }) {
            SchedulerService.shared.startMonitoring()
        } else {
            SchedulerService.shared.stopMonitoring()
        }
        
        onSave?()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        if plans.isEmpty {
            let label = UILabel()
            label.textAlignment = .center
            label.numberOfLines = 0
            label.textColor = .appSecondaryLabel
            label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            label.text = "还没有计划\n点右上角“＋”添加一条休眠/唤醒计划"
            label.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 120)
            tableView.tableHeaderView = label
        } else {
            tableView.tableHeaderView = nil
        }
    }
    
    private func openEditor(for plan: SchedulePlan, isNew: Bool) {
        let editor = SchedulePlanEditorViewController(plan: plan)
        editor.onSave = { [weak self] updated in
            guard let self = self else { return }
            if let idx = self.plans.firstIndex(where: { $0.id == updated.id }) {
                self.plans[idx] = updated
            } else {
                self.plans.append(updated)
            }
            self.tableView.reloadData()
            self.persistPlans()
        }
        navigationController?.pushViewController(editor, animated: true)
    }
}

// MARK: - UITableView

extension ScheduleSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        plans.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let plan = plans[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.accessoryType = .disclosureIndicator
        
        cell.textLabel?.text = plan.title
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        
        let sleepPart: String = {
            guard plan.sleepEnabled else { return "休眠：关闭" }
            return "休眠：\(SchedulePlanStore.timeString(fromMinutes: plan.sleepMinutes))（\(SchedulePlanStore.weekdaysShortString(plan.sleepWeekdays))）"
        }()
        let wakePart: String = {
            guard plan.wakeEnabled else { return "唤醒：关闭" }
            return "唤醒：\(SchedulePlanStore.timeString(fromMinutes: plan.wakeMinutes))（\(SchedulePlanStore.weekdaysShortString(plan.wakeWeekdays))）"
        }()
        
        cell.detailTextLabel?.numberOfLines = 2
        cell.detailTextLabel?.textColor = .appSecondaryLabel
        cell.detailTextLabel?.text = "\(sleepPart)\n\(wakePart)"
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let plan = plans[indexPath.row]
        openEditor(for: plan, isNew: false)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            plans.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            persistPlans()
        }
    }
}


