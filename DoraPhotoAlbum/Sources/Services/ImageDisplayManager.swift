import UIKit
import Photos

/// Manages image display and transitions for slideshow
class ImageDisplayManager {
    
    weak var delegate: ImageDisplayManagerDelegate?
    
    private let frontImageView: UIImageView
    private let backImageView: UIImageView
    private var currentImageRequestId: PHImageRequestID?
    private var currentImageItemId: String?
    private var currentAnimatingView: UIView?
    
    var contentMode: UIView.ContentMode = .scaleAspectFill
    
    init(frontImageView: UIImageView, backImageView: UIImageView) {
        self.frontImageView = frontImageView
        self.backImageView = backImageView
    }
    
    // MARK: - Image Loading
    
    func showImage(item: UnifiedMediaItem, targetSize: CGSize, contentMode: PHImageContentMode, kenBurnsDuration: TimeInterval, transitionDuration: TimeInterval, isPaused: Bool = false) {
        cancelImageRequest()
        
        let itemId = item.id
        currentImageItemId = itemId
        
        prepareImageViewsForTransition()
        
        currentImageRequestId = PhotoService.shared.requestImage(for: item, targetSize: targetSize, contentMode: contentMode) { [weak self] image in
            guard let self = self else { return }
            
            // Check if this request is still valid
            guard self.currentImageItemId == itemId else {
                print("ImageDisplayManager: Image load completed but item changed, ignoring")
                return
            }
            
            self.currentImageRequestId = nil
            self.currentImageItemId = nil
            
            guard let image = image else {
                DispatchQueue.main.async {
                    if self.currentImageItemId == nil || self.currentImageItemId == itemId {
                        self.delegate?.imageDisplayManager(self, didFailToLoad: item)
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                guard self.currentImageItemId == nil || self.currentImageItemId == itemId else {
                    print("ImageDisplayManager: Image loaded but item changed, ignoring")
                    return
                }
                self.displayImage(image, kenBurnsDuration: kenBurnsDuration, transitionDuration: transitionDuration, isPaused: isPaused)
            }
        }
    }
    
    func cancelImageRequest() {
        if let requestId = currentImageRequestId {
            PHImageManager.default().cancelImageRequest(requestId)
            currentImageRequestId = nil
        }
        currentImageItemId = nil
    }
    
    // MARK: - Display & Transition
    
    private func displayImage(_ image: UIImage, kenBurnsDuration: TimeInterval, transitionDuration: TimeInterval, isPaused: Bool = false) {
        let incomingView = (frontImageView.alpha == 0) ? frontImageView : backImageView
        let outgoingView = (incomingView == frontImageView) ? backImageView : frontImageView
        
        // Set image first before any transition
        incomingView.image = image
        incomingView.contentMode = contentMode
        incomingView.transform = .identity
        incomingView.alpha = 0
        
        // Ensure outgoing view is visible before transition
        if outgoingView.alpha == 0 {
            outgoingView.alpha = 1
        }
        
        performTransition(incoming: incomingView, outgoing: outgoingView, kenBurnsDuration: kenBurnsDuration, transitionDuration: transitionDuration, isPaused: isPaused)
        delegate?.imageDisplayManager(self, didDisplayImage: image)
    }
    
    private func prepareImageViewsForTransition() {
        // If both imageViews are hidden (coming from video), clear old images
        if frontImageView.alpha == 0 && backImageView.alpha == 0 {
            frontImageView.image = nil
            backImageView.image = nil
            frontImageView.transform = .identity
            backImageView.transform = .identity
            backImageView.alpha = 0
        }
    }
    
    func performTransition(incoming: UIView, outgoing: UIView, kenBurnsDuration: TimeInterval, transitionDuration: TimeInterval, isPaused: Bool = false) {
        incoming.alpha = 0
        outgoing.alpha = 1
        incoming.transform = .identity
        
        currentAnimatingView = incoming
        
        // Start Ken Burns animation on incoming view
        if !isPaused {
            startKenBurnsAnimation(on: incoming, duration: kenBurnsDuration, startRandomly: true, isPaused: isPaused)
        }
        
        // Fade transition
        UIView.animate(withDuration: transitionDuration, animations: {
            incoming.alpha = 1
            outgoing.alpha = 0
        }) { [weak self] _ in
            // Only clear outgoing image if incoming is fully visible and has an image
            if incoming.alpha >= 1.0, let incomingImageView = incoming as? UIImageView, incomingImageView.image != nil {
                outgoing.transform = .identity
                if self?.currentAnimatingView == outgoing {
                    self?.currentAnimatingView = nil
                }
                if let imageView = outgoing as? UIImageView {
                    imageView.image = nil
                }
            }
        }
    }
    
    // MARK: - Animation Control
    
    func startKenBurnsAnimation(on view: UIView, duration: TimeInterval, startRandomly: Bool, isPaused: Bool = false) {
        guard !isPaused else { return } // Don't start animation if paused
        currentAnimatingView = view
        KenBurnsAnimator.startAnimation(on: view, duration: duration, startRandomly: startRandomly)
    }
    
    func resumeKenBurnsAnimation(on view: UIView, duration: TimeInterval, isPaused: Bool = false) {
        guard !isPaused else { return }
        currentAnimatingView = view
        KenBurnsAnimator.resumeAnimation(on: view, duration: duration)
    }
    
    func stopAnimations() {
        if let animatingView = currentAnimatingView {
            animatingView.layer.removeAllAnimations()
        }
    }
    
    func getCurrentAnimatingView() -> UIView? {
        return currentAnimatingView
    }
    
    func getVisibleImageView() -> UIImageView? {
        if frontImageView.alpha > 0 {
            return frontImageView
        } else if backImageView.alpha > 0 {
            return backImageView
        }
        return nil
    }
    
    // MARK: - Content Mode
    
    func updateContentMode(_ mode: UIView.ContentMode) {
        contentMode = mode
        if frontImageView.alpha > 0 {
            frontImageView.contentMode = mode
        } else {
            backImageView.contentMode = mode
        }
    }
    
    // MARK: - Memory Management
    
    func clearHiddenImages() {
        if frontImageView.alpha == 0 {
            frontImageView.image = nil
        }
        if backImageView.alpha == 0 {
            backImageView.image = nil
        }
    }
    
    func clearAllImages() {
        frontImageView.image = nil
        backImageView.image = nil
    }
    
    func hideImageViews(animated: Bool, duration: TimeInterval = 0.5) {
        if animated {
            UIView.animate(withDuration: duration) {
                self.frontImageView.alpha = 0
                self.backImageView.alpha = 0
            }
        } else {
            frontImageView.alpha = 0
            backImageView.alpha = 0
        }
    }
}

// MARK: - ImageDisplayManagerDelegate

protocol ImageDisplayManagerDelegate: AnyObject {
    func imageDisplayManager(_ manager: ImageDisplayManager, didDisplayImage image: UIImage)
    func imageDisplayManager(_ manager: ImageDisplayManager, didFailToLoad item: UnifiedMediaItem)
}

