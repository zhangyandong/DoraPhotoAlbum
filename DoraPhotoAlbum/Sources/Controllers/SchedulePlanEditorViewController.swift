import UIKit

final class SchedulePlanEditorViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    
    private let titleField = UITextField()
    
    private let sleepEnabledSwitch = UISwitch()
    private let wakeEnabledSwitch = UISwitch()
    
    private let sleepPicker = UIDatePicker()
    private let wakePicker = UIDatePicker()
    
    private let sleepWeekdaySelector = WeekdaySelectorView()
    private let wakeWeekdaySelector = WeekdaySelectorView()
    
    private var plan: SchedulePlan
    var onSave: ((SchedulePlan) -> Void)?
    
    init(plan: SchedulePlan) {
        self.plan = plan
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appSystemGroupedBackground
        title = "编辑计划"
        setupNavigation()
        setupLayout()
        loadData()
        applyEnabledState()
    }
    
    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(save))
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
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32)
        ])
        
        // Title row
        let titleCard = cardView()
        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 8
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleCard.addSubview(titleStack)
        NSLayoutConstraint.activate([
            titleStack.topAnchor.constraint(equalTo: titleCard.topAnchor, constant: 14),
            titleStack.leadingAnchor.constraint(equalTo: titleCard.leadingAnchor, constant: 14),
            titleStack.trailingAnchor.constraint(equalTo: titleCard.trailingAnchor, constant: -14),
            titleStack.bottomAnchor.constraint(equalTo: titleCard.bottomAnchor, constant: -14)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "计划名称"
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .appSecondaryLabel
        
        titleField.borderStyle = .roundedRect
        titleField.placeholder = "例如：工作日"
        titleField.text = plan.title
        
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(titleField)
        stack.addArrangedSubview(titleCard)
        
        // Sleep section
        stack.addArrangedSubview(sectionHeader("休眠（黑屏）"))
        stack.addArrangedSubview(switchCard(label: "启用休眠", toggle: sleepEnabledSwitch, action: #selector(enabledChanged)))
        stack.addArrangedSubview(labelCard("生效日期", content: sleepWeekdaySelector))
        sleepPicker.datePickerMode = .time
        stack.addArrangedSubview(labelCard("休眠时间", content: sleepPicker))
        
        // Wake section
        stack.addArrangedSubview(sectionHeader("唤醒"))
        stack.addArrangedSubview(switchCard(label: "启用唤醒", toggle: wakeEnabledSwitch, action: #selector(enabledChanged)))
        stack.addArrangedSubview(labelCard("生效日期", content: wakeWeekdaySelector))
        wakePicker.datePickerMode = .time
        stack.addArrangedSubview(labelCard("唤醒时间", content: wakePicker))
    }
    
    private func loadData() {
        sleepEnabledSwitch.isOn = plan.sleepEnabled
        wakeEnabledSwitch.isOn = plan.wakeEnabled
        
        sleepPicker.date = SchedulePlanStore.dateForToday(fromMinutes: plan.sleepMinutes)
        wakePicker.date = SchedulePlanStore.dateForToday(fromMinutes: plan.wakeMinutes)
        
        sleepWeekdaySelector.selectedWeekdays = Set(plan.sleepWeekdays.isEmpty ? Array(1...7) : plan.sleepWeekdays)
        wakeWeekdaySelector.selectedWeekdays = Set(plan.wakeWeekdays.isEmpty ? Array(1...7) : plan.wakeWeekdays)
    }
    
    private func applyEnabledState() {
        let sleepOn = sleepEnabledSwitch.isOn
        sleepPicker.isEnabled = sleepOn
        sleepWeekdaySelector.isUserInteractionEnabled = sleepOn
        sleepWeekdaySelector.alpha = sleepOn ? 1.0 : 0.45
        
        let wakeOn = wakeEnabledSwitch.isOn
        wakePicker.isEnabled = wakeOn
        wakeWeekdaySelector.isUserInteractionEnabled = wakeOn
        wakeWeekdaySelector.alpha = wakeOn ? 1.0 : 0.45
    }
    
    @objc private func enabledChanged() {
        applyEnabledState()
    }
    
    @objc private func save() {
        var updated = plan
        updated.title = (titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? (titleField.text ?? plan.title) : plan.title
        
        updated.sleepEnabled = sleepEnabledSwitch.isOn
        updated.wakeEnabled = wakeEnabledSwitch.isOn
        
        updated.sleepMinutes = SchedulePlanStore.minutesSinceMidnight(from: sleepPicker.date)
        updated.wakeMinutes = SchedulePlanStore.minutesSinceMidnight(from: wakePicker.date)
        
        updated.sleepWeekdays = Array(sleepWeekdaySelector.selectedWeekdays).sorted()
        updated.wakeWeekdays = Array(wakeWeekdaySelector.selectedWeekdays).sorted()
        
        onSave?(updated)
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - UI Helpers
    
    private func sectionHeader(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        l.textColor = .appLabel
        return l
    }
    
    private func cardView() -> UIView {
        let v = UIView()
        v.backgroundColor = .appSecondarySystemGroupedBackground
        v.layer.cornerRadius = 14
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(white: 0.86, alpha: 1.0).cgColor
        return v
    }
    
    private func switchCard(label: String, toggle: UISwitch, action: Selector) -> UIView {
        let card = cardView()
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        
        let l = UILabel()
        l.text = label
        l.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .appLabel
        
        toggle.addTarget(self, action: action, for: .valueChanged)
        
        row.addArrangedSubview(l)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(toggle)
        return card
    }
    
    private func labelCard(_ label: String, content: UIView) -> UIView {
        let card = cardView()
        let col = UIStackView()
        col.axis = .vertical
        col.alignment = .fill
        col.spacing = 10
        col.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(col)
        
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            col.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            col.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            col.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        
        let l = UILabel()
        l.text = label
        l.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        l.textColor = .appSecondaryLabel
        
        col.addArrangedSubview(l)
        col.addArrangedSubview(content)
        return card
    }
}

