import Foundation
import SwiftUI

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
            // Lead in
            path.move(to: CGPoint(x: startX, y: midY))
            path.addLine(to: CGPoint(x: startX + 2.0, y: midY))
            
            // 3 rounded coil loops with helical depth
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
            
            // Lead out
            path.addLine(to: CGPoint(x: endX, y: midY))
            
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}

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
            // Base lead from left
            path.move(to: CGPoint(x: 1.0, y: midY))
            path.addLine(to: CGPoint(x: bx, y: midY))
            
            // Base vertical bar
            path.move(to: CGPoint(x: bx, y: h * 0.2))
            path.addLine(to: CGPoint(x: bx, y: h * 0.8))
            
            // Collector lead (top right)
            path.move(to: CGPoint(x: w - 1.0, y: h * 0.15))
            path.addLine(to: CGPoint(x: bx + 1.0, y: h * 0.35))
            
            // Emitter lead (bottom right)
            path.move(to: CGPoint(x: w - 1.0, y: h * 0.85))
            path.addLine(to: CGPoint(x: bx + 1.0, y: h * 0.65))
            
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            
            // Emitter outward arrow
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
        case .coil:
            CoilIconView(color: color, size: size)
        case .transistor:
            TransistorIconView(color: color, size: size)
        default:
            Image(systemName: type.sfSymbol)
                .font(.system(size: size * 0.85))
                .frame(width: size, height: size)
                .foregroundColor(color)
        }
    }
}
