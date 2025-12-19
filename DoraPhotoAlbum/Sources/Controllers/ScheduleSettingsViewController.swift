import UIKit

class ScheduleSettingsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    
    private let sleepPicker = UIDatePicker()
    private let wakePicker = UIDatePicker()
    
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
        
        stack.addArrangedSubview(createLabel("休眠时间 (黑屏)"))
        sleepPicker.datePickerMode = .time
        stack.addArrangedSubview(sleepPicker)
        
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
    
    // MARK: - Actions
    @objc private func save() {
        let defaults = UserDefaults.standard
        defaults.set(sleepPicker.date, forKey: AppConstants.Keys.kSleepTime)
        defaults.set(wakePicker.date, forKey: AppConstants.Keys.kWakeTime)
        defaults.synchronize()
        
        onSave?()
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Data
    private func loadData() {
        let defaults = UserDefaults.standard
        if let sDate = defaults.object(forKey: AppConstants.Keys.kSleepTime) as? Date {
            sleepPicker.date = sDate
        }
        if let wDate = defaults.object(forKey: AppConstants.Keys.kWakeTime) as? Date {
            wakePicker.date = wDate
        }
    }
}

