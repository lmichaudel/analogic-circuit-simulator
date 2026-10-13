import Foundation
import SwiftUI

// MARK: - Resistor Schematic Icon
public struct ResistorIconView: View {
    public var color: Color = .accentColor
    public var size: CGFloat = 18.0
    
    public init(color: Color = .accentColor, size: CGFloat = 18.0) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let midY = h / 2.0
            
            var path = Path()
            path.move(to: CGPoint(x: 1.0, y: midY))
            path.addLine(to: CGPoint(x: 3.5, y: midY))
            
            let zigzagW = (w - 7.0) / 5.0
            let amp = h * 0.35
            path.addLine(to: CGPoint(x: 3.5 + zigzagW * 0.5, y: midY - amp))
            path.addLine(to: CGPoint(x: 3.5 + zigzagW * 1.5, y: midY + amp))
            path.addLine(to: CGPoint(x: 3.5 + zigzagW * 2.5, y: midY - amp))
            path.addLine(to: CGPoint(x: 3.5 + zigzagW * 3.5, y: midY + amp))
            path.addLine(to: CGPoint(x: 3.5 + zigzagW * 4.5, y: midY - amp))
            path.addLine(to: CGPoint(x: w - 3.5, y: midY))
            path.addLine(to: CGPoint(x: w - 1.0, y: midY))
            
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Capacitor Schematic Icon
public struct CapacitorIconView: View {
    public var color: Color = .accentColor
    public var size: CGFloat = 18.0
    
    public init(color: Color = .accentColor, size: CGFloat = 18.0) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let midY = h / 2.0
            let p1 = w * 0.42
            let p2 = w * 0.58
            let topY = h * 0.18
            let botY = h * 0.82
            
            var path = Path()
            // Left lead
            path.move(to: CGPoint(x: 1.0, y: midY))
            path.addLine(to: CGPoint(x: p1, y: midY))
            // Left plate
            path.move(to: CGPoint(x: p1, y: topY))
            path.addLine(to: CGPoint(x: p1, y: botY))
            
            // Right plate
            path.move(to: CGPoint(x: p2, y: topY))
            path.addLine(to: CGPoint(x: p2, y: botY))
            // Right lead
            path.move(to: CGPoint(x: p2, y: midY))
            path.addLine(to: CGPoint(x: w - 1.0, y: midY))
            
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Ground Schematic Icon
public struct GroundIconView: View {
    public var color: Color = .accentColor
    public var size: CGFloat = 18.0
    
    public init(color: Color = .accentColor, size: CGFloat = 18.0) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let midX = w / 2.0
            
            var path = Path()
            // Vertical stem
            path.move(to: CGPoint(x: midX, y: 1.0))
            path.addLine(to: CGPoint(x: midX, y: h * 0.45))
            
            // 3 horizontal decreasing lines
            path.move(to: CGPoint(x: w * 0.15, y: h * 0.45))
            path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.45))
            
            path.move(to: CGPoint(x: w * 0.3, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.65))
            
            path.move(to: CGPoint(x: w * 0.42, y: h * 0.85))
            path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.85))
            
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Diode Schematic Icon
public struct DiodeIconView: View {
    public var color: Color = .accentColor
    public var size: CGFloat = 18.0
    
    public init(color: Color = .accentColor, size: CGFloat = 18.0) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let midY = h / 2.0
            let aX = w * 0.30
            let kX = w * 0.70
            let topY = h * 0.20
            let botY = h * 0.80
            
            // Leads
            var leads = Path()
            leads.move(to: CGPoint(x: 1.0, y: midY))
            leads.addLine(to: CGPoint(x: aX, y: midY))
            leads.move(to: CGPoint(x: kX, y: midY))
            leads.addLine(to: CGPoint(x: w - 1.0, y: midY))
            
            // Cathode bar
            leads.move(to: CGPoint(x: kX, y: topY))
            leads.addLine(to: CGPoint(x: kX, y: botY))
            context.stroke(leads, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            
            // Triangle
            var tri = Path()
            tri.move(to: CGPoint(x: aX, y: topY))
            tri.addLine(to: CGPoint(x: kX, y: midY))
            tri.addLine(to: CGPoint(x: aX, y: botY))
            tri.closeSubpath()
            context.fill(tri, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Voltage Source Schematic Icon
public struct VoltageSourceIconView: View {
    public var color: Color = .accentColor
    public var size: CGFloat = 18.0
    
    public init(color: Color = .accentColor, size: CGFloat = 18.0) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let r = min(w, h) * 0.42
            let center = CGPoint(x: w / 2.0, y: h / 2.0)
            
            // Circle
            let circleRect = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
            context.stroke(Path(ellipseIn: circleRect), with: .color(color), lineWidth: 1.6)
            
            // Plus
            var plus = Path()
            let px = center.x - r * 0.35
            plus.move(to: CGPoint(x: px - 2.5, y: center.y))
            plus.addLine(to: CGPoint(x: px + 2.5, y: center.y))
            plus.move(to: CGPoint(x: px, y: center.y - 2.5))
            plus.addLine(to: CGPoint(x: px, y: center.y + 2.5))
            context.stroke(plus, with: .color(color), lineWidth: 1.4)
            
            // Minus
            var minus = Path()
            let mx = center.x + r * 0.35
            minus.move(to: CGPoint(x: mx - 2.5, y: center.y))
            minus.addLine(to: CGPoint(x: mx + 2.5, y: center.y))
            context.stroke(minus, with: .color(color), lineWidth: 1.4)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Current Source Schematic Icon
public struct CurrentSourceIconView: View {
    public var color: Color = .accentColor
    public var size: CGFloat = 18.0
    
    public init(color: Color = .accentColor, size: CGFloat = 18.0) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let r = min(w, h) * 0.42
            let center = CGPoint(x: w / 2.0, y: h / 2.0)
            
            // Circle
            let circleRect = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
            context.stroke(Path(ellipseIn: circleRect), with: .color(color), lineWidth: 1.6)
            
            // Arrow pointing up
            var arrow = Path()
            arrow.move(to: CGPoint(x: center.x, y: center.y + r * 0.45))
            arrow.addLine(to: CGPoint(x: center.x, y: center.y - r * 0.45))
            arrow.addLine(to: CGPoint(x: center.x - 2.5, y: center.y - r * 0.15))
            arrow.move(to: CGPoint(x: center.x, y: center.y - r * 0.45))
            arrow.addLine(to: CGPoint(x: center.x + 2.5, y: center.y - r * 0.15))
            context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Switch Schematic Icon
public struct SwitchIconView: View {
    public var color: Color = .accentColor
    public var size: CGFloat = 18.0
    
    public init(color: Color = .accentColor, size: CGFloat = 18.0) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let midY = h / 2.0
            let p1 = w * 0.28
            let p2 = w * 0.72
            let dotR: CGFloat = 1.6
            
            var path = Path()
            path.move(to: CGPoint(x: 1.0, y: midY))
            path.addLine(to: CGPoint(x: p1, y: midY))
            path.move(to: CGPoint(x: p2, y: midY))
            path.addLine(to: CGPoint(x: w - 1.0, y: midY))
            
            // Blade angled upward
            path.move(to: CGPoint(x: p1, y: midY))
            path.addLine(to: CGPoint(x: p2 - 1.0, y: midY - h * 0.35))
            
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            
            // Dots
            context.fill(Path(ellipseIn: CGRect(x: p1 - dotR, y: midY - dotR, width: 2 * dotR, height: 2 * dotR)), with: .color(color))
            context.fill(Path(ellipseIn: CGRect(x: p2 - dotR, y: midY - dotR, width: 2 * dotR, height: 2 * dotR)), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Coil Schematic Icon
public struct CoilIconView: View {
    public var color: Color = .accentColor
    public var size: CGFloat = 18.0
    
    public init(color: Color = .accentColor, size: CGFloat = 18.0) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let midY = h * 0.58
            let startX: CGFloat = 1.0
            let endX: CGFloat = w - 1.0
            
            var path = Path()
            path.move(to: CGPoint(x: startX, y: midY))
            path.addLine(to: CGPoint(x: startX + 2.0, y: midY))
            
            let loops = 3
            let span = (endX - startX - 4.0)
            let loopW = span / CGFloat(loops)
            let loopH = h * 0.65
            
            for i in 0..<loops {
                let x0 = startX + 2.0 + CGFloat(i) * loopW
                let x1 = x0 + loopW
                let cx0 = x0 + loopW * 0.1
                let cx1 = x1 - loopW * 0.1
                path.addCurve(
                    to: CGPoint(x: x1, y: midY),
                    control1: CGPoint(x: cx0, y: midY - loopH),
                    control2: CGPoint(x: cx1, y: midY - loopH)
                )
            }
            
            path.addLine(to: CGPoint(x: endX, y: midY))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Transistor Schematic Icon
public struct TransistorIconView: View {
    public var color: Color = .accentColor
    public var size: CGFloat = 18.0
    
    public init(color: Color = .accentColor, size: CGFloat = 18.0) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let midY = h / 2.0
            let bx = w * 0.4
            
            var path = Path()
            path.move(to: CGPoint(x: 1.0, y: midY))
            path.addLine(to: CGPoint(x: bx, y: midY))
            
            path.move(to: CGPoint(x: bx, y: h * 0.2))
            path.addLine(to: CGPoint(x: bx, y: h * 0.8))
            
            path.move(to: CGPoint(x: w - 1.0, y: h * 0.15))
            path.addLine(to: CGPoint(x: bx + 1.0, y: h * 0.35))
            
            path.move(to: CGPoint(x: w - 1.0, y: h * 0.85))
            path.addLine(to: CGPoint(x: bx + 1.0, y: h * 0.65))
            
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            
            var arrow = Path()
            let ex = w * 0.75
            let ey = h * 0.75
            arrow.move(to: CGPoint(x: ex + 2.5, y: ey + 2.5))
            arrow.addLine(to: CGPoint(x: ex - 2.5, y: ey + 0.5))
            arrow.addLine(to: CGPoint(x: ex + 0.5, y: ey - 2.5))
            arrow.closeSubpath()
            context.fill(arrow, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Master Component Icon View
public struct ComponentIconView: View {
    public let type: ComponentType
    public var color: Color = .accentColor
    public var size: CGFloat = 18.0
    
    public init(type: ComponentType, color: Color = .accentColor, size: CGFloat = 18.0) {
        self.type = type
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        switch type {
        case .resistor:
            ResistorIconView(color: color, size: size)
        case .capacitor:
            CapacitorIconView(color: color, size: size)
        case .ground:
            GroundIconView(color: color, size: size)
        case .diode:
            DiodeIconView(color: color, size: size)
        case .voltageSource:
            VoltageSourceIconView(color: color, size: size)
        case .currentSource:
            CurrentSourceIconView(color: color, size: size)
        case .switchComp:
            SwitchIconView(color: color, size: size)
        case .coil:
            CoilIconView(color: color, size: size)
        case .transistor:
            TransistorIconView(color: color, size: size)
        }
    }
}

// MARK: - Menu Image Provider
@MainActor
public extension ComponentIconView {
    private static var _menuImages: [ComponentType: NSImage] = [:]
    
    static func menuImage(for type: ComponentType) -> NSImage {
        if let cached = _menuImages[type] {
            return cached
        }
        let iconView = ComponentIconView(type: type, color: .accentColor, size: 16)
            .padding(1)
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = 2.0
        if let img = renderer.nsImage {
            img.size = NSSize(width: 18, height: 18)
            _menuImages[type] = img
            return img
        }
        return NSImage()
    }
}
