import UIKit

extension UIColor {
    // MARK: - Semantic text colors
    static var appLabel: UIColor {
        if #available(iOS 13.0, *) { return .label }
        return .black
    }
    
    static var appSecondaryLabel: UIColor {
        if #available(iOS 13.0, *) { return .secondaryLabel }
        return .darkGray
    }
    
    // MARK: - Semantic backgrounds
    static var appSystemBackground: UIColor {
        if #available(iOS 13.0, *) { return .systemBackground }
        return .white
    }
    
    static var appSystemGroupedBackground: UIColor {
        if #available(iOS 13.0, *) { return .systemGroupedBackground }
        return .groupTableViewBackground
    }
    
    static var appSecondarySystemGroupedBackground: UIColor {
        if #available(iOS 13.0, *) { return .secondarySystemGroupedBackground }
        return .white
    }
    
    // MARK: - Accent colors (with iOS 12 fallback)
    static var appAccentBlue: UIColor {
        if #available(iOS 13.0, *) { return .systemBlue }
        return .blue
    }
    
    static var appAccentGreen: UIColor {
        if #available(iOS 13.0, *) { return .systemGreen }
        // close to systemGreen
        return UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
    }
    
    static var appAccentRed: UIColor {
        if #available(iOS 13.0, *) { return .systemRed }
        return .red
    }
}


