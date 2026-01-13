import UIKit

/// 1=Monday ... 7=Sunday
final class WeekdaySelectorView: UIView {
    var selectedWeekdays: Set<Int> = Set(1...7) {
        didSet { updateButtons() }
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
                button.backgroundColor = .appSystemBackground
                button.setTitleColor(.appLabel, for: .normal)
                if #available(iOS 13.0, *) {
                    button.layer.borderColor = UIColor.separator.cgColor
                } else {
                    button.layer.borderColor = UIColor(white: 0.88, alpha: 1.0).cgColor
                }
            }
        }
    }
}

