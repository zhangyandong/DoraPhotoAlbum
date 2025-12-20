import UIKit

/// Handles Ken Burns effect animation for image views
class KenBurnsAnimator {
    
    struct Configuration {
        static let scaleRange: ClosedRange<CGFloat> = 1.05...1.15
        static let safetyFactor: CGFloat = 0.8
    }
    
    /// Start Ken Burns animation on a view
    static func startAnimation(on view: UIView, duration: TimeInterval, startRandomly: Bool) {
        let endScale = CGFloat.random(in: Configuration.scaleRange)
        
        if startRandomly {
            let startScale = CGFloat.random(in: Configuration.scaleRange)
            let startTranslation = randomTranslation(for: startScale, in: view.bounds.size)
            let startTransform = CGAffineTransform(scaleX: startScale, y: startScale)
                .translatedBy(x: startTranslation.x / startScale, y: startTranslation.y / startScale)
            view.transform = startTransform
        }
        
        let endTranslation = randomTranslation(for: endScale, in: view.bounds.size)
        let endTransform = CGAffineTransform(scaleX: endScale, y: endScale)
            .translatedBy(x: endTranslation.x / endScale, y: endTranslation.y / endScale)

        UIView.animate(withDuration: duration, delay: 0, options: .curveLinear, animations: {
            view.transform = endTransform
        }, completion: nil)
    }
    
    /// Resume Ken Burns animation (restart with remaining duration)
    static func resumeAnimation(on view: UIView, duration: TimeInterval) {
        startAnimation(on: view, duration: duration, startRandomly: false)
    }
    
    private static func randomTranslation(for scale: CGFloat, in size: CGSize) -> CGPoint {
        guard scale > 1.0 else { return .zero }
        
        let maxOffX = ((size.width * scale - size.width) / 2) * Configuration.safetyFactor
        let maxOffY = ((size.height * scale - size.height) / 2) * Configuration.safetyFactor
        
        return CGPoint(
            x: CGFloat.random(in: -maxOffX...maxOffX),
            y: CGFloat.random(in: -maxOffY...maxOffY)
        )
    }
}

