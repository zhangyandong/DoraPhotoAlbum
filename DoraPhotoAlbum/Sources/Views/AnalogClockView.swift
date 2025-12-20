import UIKit

class AnalogClockView: UIView {
    
    // MARK: - Properties
    
    private let hourHandLayer = CAShapeLayer()
    private let minuteHandLayer = CAShapeLayer()
    private let secondHandLayer = CAShapeLayer()
    private let faceLayer = CAShapeLayer()
    private let centerDotLayer = CAShapeLayer()
    private var numberLayers: [CATextLayer] = []
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrames()
    }
    
    // MARK: - Setup
    
    private func setupLayers() {
        // Face
        faceLayer.strokeColor = UIColor.white.cgColor
        faceLayer.fillColor = UIColor.black.withAlphaComponent(0.3).cgColor
        faceLayer.lineWidth = 4.0
        faceLayer.shadowColor = UIColor.black.cgColor
        faceLayer.shadowOffset = CGSize(width: 2, height: 2)
        faceLayer.shadowOpacity = 0.5
        faceLayer.shadowRadius = 4
        layer.addSublayer(faceLayer)
        
        // Hour Hand
        hourHandLayer.backgroundColor = UIColor.white.cgColor
        hourHandLayer.cornerRadius = 3
        hourHandLayer.shadowColor = UIColor.black.cgColor
        hourHandLayer.shadowOffset = CGSize(width: 1, height: 1)
        hourHandLayer.shadowOpacity = 0.5
        layer.addSublayer(hourHandLayer)
        
        // Minute Hand
        minuteHandLayer.backgroundColor = UIColor.white.cgColor
        minuteHandLayer.cornerRadius = 2
        minuteHandLayer.shadowColor = UIColor.black.cgColor
        minuteHandLayer.shadowOffset = CGSize(width: 1, height: 1)
        minuteHandLayer.shadowOpacity = 0.5
        layer.addSublayer(minuteHandLayer)
        
        // Second Hand
        secondHandLayer.backgroundColor = UIColor.red.cgColor
        secondHandLayer.cornerRadius = 1
        secondHandLayer.shadowColor = UIColor.black.cgColor
        secondHandLayer.shadowOffset = CGSize(width: 1, height: 1)
        secondHandLayer.shadowOpacity = 0.5
        layer.addSublayer(secondHandLayer)
        
        // Center Dot
        centerDotLayer.path = UIBezierPath(ovalIn: CGRect(x: -4, y: -4, width: 8, height: 8)).cgPath
        centerDotLayer.fillColor = UIColor.white.cgColor
        layer.addSublayer(centerDotLayer)
        
        // Numbers
        for i in 1...12 {
            let textLayer = CATextLayer()
            textLayer.string = "\(i)"
            textLayer.font = UIFont.systemFont(ofSize: 20, weight: .bold)
            textLayer.fontSize = 20
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale
            // Add shadow for better visibility
            textLayer.shadowColor = UIColor.black.cgColor
            textLayer.shadowOffset = CGSize(width: 1, height: 1)
            textLayer.shadowOpacity = 0.8
            textLayer.shadowRadius = 2
            
            layer.addSublayer(textLayer)
            numberLayers.append(textLayer)
        }
    }
    
    private func updateLayerFrames() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        // Increase radius to make the clock face larger (use 98% of available space)
        let radius = min(bounds.width, bounds.height) / 2 * 0.98
        
        // Face Path
        let facePath = UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        
        // Add markers
        for i in 0..<60 {
            let angle = CGFloat(i) * .pi / 30
            let isHourMark = (i % 5 == 0)
            
            let innerRadius = radius - (isHourMark ? 20 : 10)
            let outerRadius = radius - 5
            
            let start = CGPoint(x: center.x + innerRadius * sin(angle), y: center.y - innerRadius * cos(angle))
            let end = CGPoint(x: center.x + outerRadius * sin(angle), y: center.y - outerRadius * cos(angle))
            
            facePath.move(to: start)
            facePath.addLine(to: end)
        }
        
        faceLayer.path = facePath.cgPath
        
        // Update Numbers
        let numberRadius = radius - 35
        for (index, textLayer) in numberLayers.enumerated() {
            let i = index + 1
            let angle = CGFloat(i) * .pi / 6
            let x = center.x + numberRadius * sin(angle)
            let y = center.y - numberRadius * cos(angle)
            
            // Adjust font size based on clock size
            let fontSize = max(12, radius * 0.15)
            textLayer.fontSize = fontSize
            
            let size = textLayer.preferredFrameSize()
            textLayer.frame = CGRect(x: x - size.width/2, y: y - size.height/2, width: size.width, height: size.height)
        }
        
        // Hand Frames (centered initially, then rotated)
        
        // Hour Hand: shorter and thicker (increased length to match larger face)
        let hourW: CGFloat = 8
        let hourH: CGFloat = radius * 0.7
        hourHandLayer.bounds = CGRect(x: 0, y: 0, width: hourW, height: hourH)
        hourHandLayer.position = center
        hourHandLayer.anchorPoint = CGPoint(x: 0.5, y: 0.9) // Rotate around near bottom
        
        // Minute Hand: longer and thinner (increased length to match larger face)
        let minW: CGFloat = 4
        let minH: CGFloat = radius * 0.85
        minuteHandLayer.bounds = CGRect(x: 0, y: 0, width: minW, height: minH)
        minuteHandLayer.position = center
        minuteHandLayer.anchorPoint = CGPoint(x: 0.5, y: 0.9)
        
        // Second Hand: longest and thinnest (increased length to match larger face)
        let secW: CGFloat = 2
        let secH: CGFloat = radius * 1
        secondHandLayer.bounds = CGRect(x: 0, y: 0, width: secW, height: secH)
        secondHandLayer.position = center
        secondHandLayer.anchorPoint = CGPoint(x: 0.5, y: 0.82) // Rotate around near bottom
        
        // Update Center Dot Position
        centerDotLayer.position = center
        
        // Force update hands immediately to new position
        updateTime()
        
        CATransaction.commit()
    }
    
    // MARK: - Update
    
    func updateTime() {
        let date = Date()
        let calendar = Calendar.current
        
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        guard let hour = components.hour, let minute = components.minute, let second = components.second, let nano = components.nanosecond else { return }
        
        // Calculate angles
        // Second: full circle = 60 seconds
        let secAngle = (Double(second) + Double(nano) / 1_000_000_000) * (2 * .pi / 60)
        
        // Minute: full circle = 60 minutes + seconds progress
        let minAngle = (Double(minute) + Double(second) / 60.0) * (2 * .pi / 60)
        
        // Hour: full circle = 12 hours + minutes progress
        let hourVal = Double(hour % 12)
        let hourAngle = (hourVal + Double(minute) / 60.0) * (2 * .pi / 12)
        
        secondHandLayer.transform = CATransform3DMakeRotation(CGFloat(secAngle), 0, 0, 1)
        minuteHandLayer.transform = CATransform3DMakeRotation(CGFloat(minAngle), 0, 0, 1)
        hourHandLayer.transform = CATransform3DMakeRotation(CGFloat(hourAngle), 0, 0, 1)
    }
}
