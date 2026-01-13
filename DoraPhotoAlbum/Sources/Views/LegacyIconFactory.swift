import UIKit

/// iOS 12 fallback icons (since SF Symbols are iOS 13+).
/// Produces simple, clean, template-rendered vector icons for tinting.
enum LegacyIconFactory {
    
    static func icon(forSystemName systemName: String, pointSize: CGFloat) -> UIImage? {
        // Map SF Symbols names used in the app to our fallback icons.
        switch systemName {
        case "pause.fill":
            return pause(size: pointSize)
        case "play.fill":
            return play(size: pointSize)
        case "music.note":
            return music(size: pointSize)
        case "speaker.wave.2.fill":
            return speaker(size: pointSize)
        case "clock.fill":
            return clock(size: pointSize)
        case "gearshape.fill", "gearshape":
            return gear(size: pointSize)
        case "xmark", "xmark.circle.fill":
            return xmark(size: pointSize)
        default:
            return nil
        }
    }
    
    // MARK: - Drawing helpers
    
    private static func render(size: CGFloat, draw: (CGRect) -> Void) -> UIImage? {
        let canvas = CGSize(width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(canvas, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        UIColor.black.setFill()
        UIColor.black.setStroke()
        draw(CGRect(origin: .zero, size: canvas))
        
        let img = UIGraphicsGetImageFromCurrentImageContext()
        return img?.withRenderingMode(.alwaysTemplate)
    }
    
    private static func play(size: CGFloat) -> UIImage? {
        return render(size: size) { rect in
            let inset = rect.width * 0.18
            let r = rect.insetBy(dx: inset, dy: inset)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: r.minX, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            path.close()
            path.fill()
        }
    }
    
    private static func pause(size: CGFloat) -> UIImage? {
        return render(size: size) { rect in
            let inset = rect.width * 0.22
            let r = rect.insetBy(dx: inset, dy: inset)
            let barW = r.width * 0.28
            let gap = r.width * 0.18
            let left = CGRect(x: r.minX, y: r.minY, width: barW, height: r.height)
            let right = CGRect(x: r.minX + barW + gap, y: r.minY, width: barW, height: r.height)
            UIBezierPath(roundedRect: left, cornerRadius: barW * 0.2).fill()
            UIBezierPath(roundedRect: right, cornerRadius: barW * 0.2).fill()
        }
    }
    
    private static func music(size: CGFloat) -> UIImage? {
        return render(size: size) { rect in
            // A cleaner quaver (♪): tilted head + stem + flag
            let inset = rect.width * 0.16
            let r = rect.insetBy(dx: inset, dy: inset)
            
            // Head (tilted oval)
            let headW = r.width * 0.34
            let headH = r.width * 0.24
            let headRect = CGRect(
                x: r.minX + r.width * 0.18,
                y: r.minY + r.height * 0.62,
                width: headW,
                height: headH
            )
            let headPath = UIBezierPath(ovalIn: headRect)
            var headT = CGAffineTransform(translationX: -headRect.midX, y: -headRect.midY)
            headT = headT.rotated(by: -CGFloat.pi / 10) // -18°
            headT = headT.translatedBy(x: headRect.midX, y: headRect.midY)
            headPath.apply(headT)
            headPath.fill()
            
            // Stem (thicker stroke, rounded)
            let lineW = max(2, r.width * 0.11)
            let stemX = headRect.maxX - headW * 0.10
            let stemTopY = r.minY + r.height * 0.12
            let stemBottomY = headRect.midY + headH * 0.05
            let stem = UIBezierPath()
            stem.lineWidth = lineW
            stem.lineCapStyle = .round
            stem.move(to: CGPoint(x: stemX, y: stemBottomY))
            stem.addLine(to: CGPoint(x: stemX, y: stemTopY))
            stem.stroke()
            
            // Flag (filled curved wedge)
            let flag = UIBezierPath()
            let flagStart = CGPoint(x: stemX, y: stemTopY + lineW * 0.2)
            let flagEnd = CGPoint(x: r.maxX - r.width * 0.05, y: r.minY + r.height * 0.34)
            let flagInnerEnd = CGPoint(x: r.maxX - r.width * 0.14, y: r.minY + r.height * 0.44)
            flag.move(to: flagStart)
            flag.addQuadCurve(to: flagEnd, controlPoint: CGPoint(x: r.maxX - r.width * 0.02, y: r.minY + r.height * 0.12))
            flag.addQuadCurve(to: flagInnerEnd, controlPoint: CGPoint(x: r.maxX - r.width * 0.02, y: r.minY + r.height * 0.30))
            flag.addQuadCurve(to: CGPoint(x: stemX + lineW * 0.55, y: stemTopY + r.height * 0.14),
                              controlPoint: CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.44))
            flag.close()
            flag.fill()
        }
    }
    
    private static func speaker(size: CGFloat) -> UIImage? {
        return render(size: size) { rect in
            let inset = rect.width * 0.18
            let r = rect.insetBy(dx: inset, dy: inset)
            
            // Speaker body (trapezoid)
            let body = UIBezierPath()
            let left = r.minX
            let midX = r.minX + r.width * 0.32
            let topY = r.minY + r.height * 0.28
            let botY = r.minY + r.height * 0.72
            body.move(to: CGPoint(x: left, y: topY))
            body.addLine(to: CGPoint(x: midX, y: topY))
            body.addLine(to: CGPoint(x: r.maxX - r.width * 0.20, y: r.minY))
            body.addLine(to: CGPoint(x: r.maxX - r.width * 0.20, y: r.maxY))
            body.addLine(to: CGPoint(x: midX, y: botY))
            body.addLine(to: CGPoint(x: left, y: botY))
            body.close()
            body.fill()
            
            // Waves (two arcs)
            let center = CGPoint(x: r.maxX - r.width * 0.10, y: r.midY)
            let lineW = max(2, r.width * 0.10)
            UIColor.black.setStroke()
            
            for factor in [0.35, 0.55] {
                let radius = r.width * factor
                let arc = UIBezierPath(arcCenter: center, radius: radius, startAngle: -CGFloat.pi / 3, endAngle: CGFloat.pi / 3, clockwise: true)
                arc.lineWidth = lineW
                arc.lineCapStyle = .round
                arc.stroke()
            }
        }
    }
    
    private static func clock(size: CGFloat) -> UIImage? {
        return render(size: size) { rect in
            let inset = rect.width * 0.14
            let r = rect.insetBy(dx: inset, dy: inset)
            let lineW = max(2, r.width * 0.10)
            
            // Circle
            let circle = UIBezierPath(ovalIn: r)
            circle.lineWidth = lineW
            circle.stroke()
            
            // Hands
            let center = CGPoint(x: r.midX, y: r.midY)
            let hour = UIBezierPath()
            hour.lineWidth = lineW
            hour.lineCapStyle = .round
            hour.move(to: center)
            hour.addLine(to: CGPoint(x: center.x, y: center.y - r.height * 0.22))
            hour.stroke()
            
            let minute = UIBezierPath()
            minute.lineWidth = lineW
            minute.lineCapStyle = .round
            minute.move(to: center)
            minute.addLine(to: CGPoint(x: center.x + r.width * 0.22, y: center.y))
            minute.stroke()
            
            // Center dot
            let dotR = r.width * 0.08
            UIBezierPath(ovalIn: CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2)).fill()
        }
    }
    
    private static func gear(size: CGFloat) -> UIImage? {
        return render(size: size) { rect in
            // Cleaner gear: outer body + teeth, inner hole via even-odd fill.
            let inset = rect.width * 0.14
            let r = rect.insetBy(dx: inset, dy: inset)
            let center = CGPoint(x: r.midX, y: r.midY)
            
            let outerRadius = r.width * 0.36
            let holeRadius = outerRadius * 0.42
            
            let toothW = r.width * 0.14
            let toothH = r.width * 0.18
            let toothCorner = toothW * 0.25
            
            let gearPath = UIBezierPath()
            
            // Teeth (12 teeth looks closer to a real gear)
            for i in 0..<12 {
                let angle = CGFloat(i) * (2 * CGFloat.pi / 12)
                let radial = outerRadius + toothH * 0.25
                
                let toothRect = CGRect(
                    x: center.x + cos(angle) * radial - toothW / 2,
                    y: center.y + sin(angle) * radial - toothH / 2,
                    width: toothW,
                    height: toothH
                )
                let tooth = UIBezierPath(roundedRect: toothRect, cornerRadius: toothCorner)
                
                // Rotate tooth around center
                var t = CGAffineTransform(translationX: -center.x, y: -center.y)
                t = t.rotated(by: angle)
                t = t.translatedBy(x: center.x, y: center.y)
                tooth.apply(t)
                
                gearPath.append(tooth)
            }
            
            // Outer body circle
            let outerCircle = UIBezierPath(ovalIn: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2))
            gearPath.append(outerCircle)
            
            // Inner hole (cut out)
            let hole = UIBezierPath(ovalIn: CGRect(x: center.x - holeRadius, y: center.y - holeRadius, width: holeRadius * 2, height: holeRadius * 2))
            gearPath.append(hole)
            gearPath.usesEvenOddFillRule = true
            gearPath.fill()
        }
    }
    
    private static func xmark(size: CGFloat) -> UIImage? {
        return render(size: size) { rect in
            let inset = rect.width * 0.24
            let r = rect.insetBy(dx: inset, dy: inset)
            let lineW = max(2, r.width * 0.16)
            let p = UIBezierPath()
            p.lineWidth = lineW
            p.lineCapStyle = .round
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.move(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.stroke()
        }
    }
}

