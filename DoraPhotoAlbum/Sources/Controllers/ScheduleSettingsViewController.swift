import UIKit

class ScheduleSettingsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    
    private let sleepEnabledSwitch = UISwitch()
    private let wakeEnabledSwitch = UISwitch()
    private let sleepPicker = UIDatePicker()
    private let wakePicker = UIDatePicker()
    private let sleepWeekdaySelector = WeekdaySelectorView()
    private let wakeWeekdaySelector = WeekdaySelectorView()
    
    var onSave: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "定时计划"
        setupNavigation()
        setupLayout()
        loadData()
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
        
        // Sleep time section
        let sleepSwitchRow = createSwitchRow(label: "启用休眠时间", switch: sleepEnabledSwitch)
        stack.addArrangedSubview(sleepSwitchRow)
        
        stack.addArrangedSubview(createLabel("生效日期"))
        sleepWeekdaySelector.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(sleepWeekdaySelector)
        
        stack.addArrangedSubview(createLabel("休眠时间 (黑屏)"))
        sleepPicker.datePickerMode = .time
        stack.addArrangedSubview(sleepPicker)
        
        // Add spacing
        stack.addArrangedSubview(createSpacer(height: 8))
        
        // Wake time section
        let wakeSwitchRow = createSwitchRow(label: "启用唤醒时间", switch: wakeEnabledSwitch)
        stack.addArrangedSubview(wakeSwitchRow)
        
        stack.addArrangedSubview(createLabel("生效日期"))
        wakeWeekdaySelector.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(wakeWeekdaySelector)
        
        stack.addArrangedSubview(createLabel("唤醒时间"))
        wakePicker.datePickerMode = .time
        stack.addArrangedSubview(wakePicker)
    }
    
    private func createLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.boldSystemFont(ofSize: 14)
        l.textColor = .darkGray
        return l
    }
    
    private func createSwitchRow(label: String, switch: UISwitch) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        labelView.textColor = .darkGray
        
        row.addArrangedSubview(labelView)
        row.addArrangedSubview(`switch`)
        return row
    }
    
    private func createSpacer(height: CGFloat) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }
    
    // MARK: - Actions
    @objc private func sleepSwitchChanged() {
        sleepPicker.isEnabled = sleepEnabledSwitch.isOn
    }
    
    @objc private func wakeSwitchChanged() {
        wakePicker.isEnabled = wakeEnabledSwitch.isOn
    }
    @objc private func save() {
        let defaults = UserDefaults.standard
        defaults.set(sleepEnabledSwitch.isOn, forKey: AppConstants.Keys.kSleepEnabled)
        defaults.set(wakeEnabledSwitch.isOn, forKey: AppConstants.Keys.kWakeEnabled)
        defaults.set(sleepPicker.date, forKey: AppConstants.Keys.kSleepTime)
        defaults.set(wakePicker.date, forKey: AppConstants.Keys.kWakeTime)
        
        // Save selected weekdays as array
        defaults.set(Array(sleepWeekdaySelector.selectedWeekdays), forKey: AppConstants.Keys.kSleepWeekdays)
        defaults.set(Array(wakeWeekdaySelector.selectedWeekdays), forKey: AppConstants.Keys.kWakeWeekdays)
        
        defaults.synchronize()
        
        // Restart monitoring if either sleep or wake is enabled
        if sleepEnabledSwitch.isOn || wakeEnabledSwitch.isOn {
            SchedulerService.shared.startMonitoring()
        } else {
            SchedulerService.shared.stopMonitoring()
        }
        
        onSave?()
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Data
    private func loadData() {
        let defaults = UserDefaults.standard
        
        // Load sleep enabled state
        let sleepEnabled: Bool
        if defaults.object(forKey: AppConstants.Keys.kSleepEnabled) != nil {
            sleepEnabled = defaults.bool(forKey: AppConstants.Keys.kSleepEnabled)
        } else {
            sleepEnabled = AppConstants.Defaults.sleepEnabled
        }
        sleepEnabledSwitch.isOn = sleepEnabled
        
        // Load wake enabled state
        let wakeEnabled: Bool
        if defaults.object(forKey: AppConstants.Keys.kWakeEnabled) != nil {
            wakeEnabled = defaults.bool(forKey: AppConstants.Keys.kWakeEnabled)
        } else {
            wakeEnabled = AppConstants.Defaults.wakeEnabled
        }
        wakeEnabledSwitch.isOn = wakeEnabled
        
        // Load sleep and wake times
        if let sDate = defaults.object(forKey: AppConstants.Keys.kSleepTime) as? Date {
            sleepPicker.date = sDate
        } else {
            // Use default sleep time (22:00)
            sleepPicker.date = AppConstants.Defaults.defaultSleepTime
        }
        if let wDate = defaults.object(forKey: AppConstants.Keys.kWakeTime) as? Date {
            wakePicker.date = wDate
        } else {
            // Use default wake time (07:00)
            wakePicker.date = AppConstants.Defaults.defaultWakeTime
        }
        
        // Load selected weekdays
        if let sleepWeekdays = defaults.array(forKey: AppConstants.Keys.kSleepWeekdays) as? [Int] {
            sleepWeekdaySelector.selectedWeekdays = Set(sleepWeekdays)
        } else {
            // Default: all weekdays selected
            sleepWeekdaySelector.selectedWeekdays = Set(1...7)
        }
        
        if let wakeWeekdays = defaults.array(forKey: AppConstants.Keys.kWakeWeekdays) as? [Int] {
            wakeWeekdaySelector.selectedWeekdays = Set(wakeWeekdays)
        } else {
            // Default: all weekdays selected
            wakeWeekdaySelector.selectedWeekdays = Set(1...7)
        }
    }
}

// MARK: - Weekday Selector View
class WeekdaySelectorView: UIView {
    var selectedWeekdays: Set<Int> = Set(1...7) {
        didSet {
            updateButtons()
        }
    }
    
    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]
    private var buttons: [UIButton] = []
    private let stackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 44)
        ])
        
        for (index, label) in weekdayLabels.enumerated() {
            let button = createWeekdayButton(title: label, weekday: index + 1)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        updateButtons()
    }
    
    private func createWeekdayButton(title: String, weekday: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1.5
        button.addTarget(self, action: #selector(weekdayButtonTapped(_:)), for: .touchUpInside)
        button.tag = weekday
        return button
    }
    
    @objc private func weekdayButtonTapped(_ sender: UIButton) {
        let weekday = sender.tag
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
        updateButtons()
    }
    
    private func updateButtons() {
        for button in buttons {
            let weekday = button.tag
            let isSelected = selectedWeekdays.contains(weekday)
            
            if isSelected {
                button.backgroundColor = .appAccentBlue
                button.setTitleColor(.white, for: .normal)
                button.layer.borderColor = UIColor.appAccentBlue.cgColor
            } else {
                // Use lighter background color for unselected buttons
                if #available(iOS 13.0, *) {
                    button.backgroundColor = UIColor.appSystemBackground
                } else {
                    button.backgroundColor = .white
                }
                // Use compatible text color for all iOS versions
                if #available(iOS 13.0, *) {
                    button.setTitleColor(.appLabel, for: .normal)
                } else {
                    button.setTitleColor(.darkText, for: .normal)
                }
                // Use lighter border color for unselected buttons
                if #available(iOS 13.0, *) {
                    button.layer.borderColor = UIColor.separator.cgColor
                } else {
                    button.layer.borderColor = UIColor(white: 0.88, alpha: 1.0).cgColor
                }
            }
        }
    }
}

