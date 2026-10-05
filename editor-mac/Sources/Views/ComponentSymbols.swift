import Foundation
import SwiftUI

public struct ComponentSymbolRenderer {
    public static func draw(
        type: ComponentType,
        in context: GraphicsContext,
        size: CGSize,
        strokeColor: Color,
        fillColor: Color,
        lineWidth: CGFloat = 2.0,
        grid: CGFloat = 20.0,
        isClosed: Bool = true
    ) {
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        
        switch type {
        case .resistor:
            drawResistor(context: context, center: center, color: strokeColor, lineWidth: lineWidth, grid: grid)
        case .voltageSource:
            drawVoltageSource(context: context, center: center, color: strokeColor, lineWidth: lineWidth, grid: grid)
        case .currentSource:
            drawCurrentSource(context: context, center: center, color: strokeColor, lineWidth: lineWidth, grid: grid)
        case .ground:
            drawGround(context: context, center: center, color: strokeColor, lineWidth: lineWidth, grid: grid)
        case .capacitor:
            drawCapacitor(context: context, center: center, color: strokeColor, lineWidth: lineWidth, grid: grid)
        case .coil:
            drawCoil(context: context, center: center, color: strokeColor, lineWidth: lineWidth, grid: grid)
        case .diode:
            drawDiode(context: context, center: center, strokeColor: strokeColor, fillColor: fillColor, lineWidth: lineWidth, grid: grid)
        case .transistor:
            drawTransistor(context: context, center: center, color: strokeColor, lineWidth: lineWidth, grid: grid)
        case .switchComp:
            drawSwitch(context: context, center: center, color: strokeColor, lineWidth: lineWidth, grid: grid, isClosed: isClosed)
        }
    }
    
    // MARK: - Resistor
    private static func drawResistor(context: GraphicsContext, center: CGPoint, color: Color, lineWidth: CGFloat, grid: CGFloat) {
        var path = Path()
        let hw = grid * 1.0
        let hh = grid * 0.45
        
        // Leads
        path.move(to: CGPoint(x: center.x - 2 * grid, y: center.y))
        path.addLine(to: CGPoint(x: center.x - hw, y: center.y))
        
        path.move(to: CGPoint(x: center.x + hw, y: center.y))
        path.addLine(to: CGPoint(x: center.x + 2 * grid, y: center.y))
        
        // Zigzag (6 teeth)
        path.move(to: CGPoint(x: center.x - hw, y: center.y))
        let n = 6
        let step = (hw * 2.0) / CGFloat(n)
        for i in 1...n {
            let yOffset = (i % 2 == 0) ? hh : -hh
            let pt = CGPoint(x: center.x - hw + CGFloat(i) * step, y: center.y + yOffset)
            path.addLine(to: pt)
        }
        path.addLine(to: CGPoint(x: center.x + hw, y: center.y))
        
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Voltage Source
    private static func drawVoltageSource(context: GraphicsContext, center: CGPoint, color: Color, lineWidth: CGFloat, grid: CGFloat) {
        let r = grid * 0.85
        let circleRect = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
        
        var leads = Path()
        leads.move(to: CGPoint(x: center.x - 2 * grid, y: center.y))
        leads.addLine(to: CGPoint(x: center.x - r, y: center.y))
        leads.move(to: CGPoint(x: center.x + r, y: center.y))
        leads.addLine(to: CGPoint(x: center.x + 2 * grid, y: center.y))
        context.stroke(leads, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        
        // Circle body
        context.stroke(Path(ellipseIn: circleRect), with: .color(color), style: StrokeStyle(lineWidth: lineWidth))
        
        // Plus symbol on positive terminal side (top or left)
        let s: CGFloat = 4.0
        var plus = Path()
        plus.move(to: CGPoint(x: center.x - grid * 0.35 - s, y: center.y))
        plus.addLine(to: CGPoint(x: center.x - grid * 0.35 + s, y: center.y))
        plus.move(to: CGPoint(x: center.x - grid * 0.35, y: center.y - s))
        plus.addLine(to: CGPoint(x: center.x - grid * 0.35, y: center.y + s))
        context.stroke(plus, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        
        // Minus symbol on negative terminal side
        var minus = Path()
        minus.move(to: CGPoint(x: center.x + grid * 0.35 - s, y: center.y))
        minus.addLine(to: CGPoint(x: center.x + grid * 0.35 + s, y: center.y))
        context.stroke(minus, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }
    
    // MARK: - Current Source
    private static func drawCurrentSource(context: GraphicsContext, center: CGPoint, color: Color, lineWidth: CGFloat, grid: CGFloat) {
        let r = grid * 0.85
        let circleRect = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
        
        var leads = Path()
        leads.move(to: CGPoint(x: center.x - 2 * grid, y: center.y))
        leads.addLine(to: CGPoint(x: center.x - r, y: center.y))
        leads.move(to: CGPoint(x: center.x + r, y: center.y))
        leads.addLine(to: CGPoint(x: center.x + 2 * grid, y: center.y))
        context.stroke(leads, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        
        context.stroke(Path(ellipseIn: circleRect), with: .color(color), style: StrokeStyle(lineWidth: lineWidth))
        
        // Internal arrow pointing in flow direction
        var arrow = Path()
        let arrowLen = grid * 0.5
        arrow.move(to: CGPoint(x: center.x - arrowLen, y: center.y))
        arrow.addLine(to: CGPoint(x: center.x + arrowLen, y: center.y))
        
        // Arrow head
        arrow.move(to: CGPoint(x: center.x + arrowLen - 4, y: center.y - 4))
        arrow.addLine(to: CGPoint(x: center.x + arrowLen, y: center.y))
        arrow.addLine(to: CGPoint(x: center.x + arrowLen - 4, y: center.y + 4))
        context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Ground
    private static func drawGround(context: GraphicsContext, center: CGPoint, color: Color, lineWidth: CGFloat, grid: CGFloat) {
        var path = Path()
        // Pin stem
        path.move(to: CGPoint(x: center.x, y: center.y - grid))
        path.addLine(to: CGPoint(x: center.x, y: center.y + grid * 0.2))
        
        // 3 descending horizontal lines
        let widths: [CGFloat] = [grid * 1.6, grid * 1.0, grid * 0.4]
        for i in 0..<3 {
            let w = widths[i]
            let y = center.y + grid * 0.2 + CGFloat(i) * grid * 0.3
            path.move(to: CGPoint(x: center.x - w / 2.0, y: y))
            path.addLine(to: CGPoint(x: center.x + w / 2.0, y: y))
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
    
    // MARK: - Capacitor
    private static func drawCapacitor(context: GraphicsContext, center: CGPoint, color: Color, lineWidth: CGFloat, grid: CGFloat) {
        let hw = grid * 0.35
        let hh = grid * 0.8
        
        var path = Path()
        // Leads
        path.move(to: CGPoint(x: center.x - 2 * grid, y: center.y))
        path.addLine(to: CGPoint(x: center.x - hw, y: center.y))
        path.move(to: CGPoint(x: center.x + hw, y: center.y))
        path.addLine(to: CGPoint(x: center.x + 2 * grid, y: center.y))
        
        // Left plate
        path.move(to: CGPoint(x: center.x - hw, y: center.y - hh))
        path.addLine(to: CGPoint(x: center.x - hw, y: center.y + hh))
        
        // Right plate
        path.move(to: CGPoint(x: center.x + hw, y: center.y - hh))
        path.addLine(to: CGPoint(x: center.x + hw, y: center.y + hh))
        
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
    
    // MARK: - Inductor (Coil)
    private static func drawCoil(context: GraphicsContext, center: CGPoint, color: Color, lineWidth: CGFloat, grid: CGFloat) {
        let hw = grid * 1.0
        let loops = 4
        let loopWidth = (hw * 2.0) / CGFloat(loops)
        
        var path = Path()
        // Left lead
        path.move(to: CGPoint(x: center.x - 2 * grid, y: center.y))
        path.addLine(to: CGPoint(x: center.x - hw, y: center.y))
        
        // 4 continuous rounded coil loops with genuine circular arched geometry
        for i in 0..<loops {
            let startX = center.x - hw + CGFloat(i) * loopWidth
            let endX = startX + loopWidth
            let domeHeight = grid * 0.75
            
            path.addCurve(
                to: CGPoint(x: endX, y: center.y),
                control1: CGPoint(x: startX, y: center.y - domeHeight * 1.35),
                control2: CGPoint(x: endX, y: center.y - domeHeight * 1.35)
            )
        }
        
        // Right lead
        path.addLine(to: CGPoint(x: center.x + 2 * grid, y: center.y))
        
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }
    
    // MARK: - Diode
    private static func drawDiode(context: GraphicsContext, center: CGPoint, strokeColor: Color, fillColor: Color, lineWidth: CGFloat, grid: CGFloat) {
        let hw = grid * 0.6
        let hh = grid * 0.55
        
        // Main lead line
        var lead = Path()
        lead.move(to: CGPoint(x: center.x - 2 * grid, y: center.y))
        lead.addLine(to: CGPoint(x: center.x + 2 * grid, y: center.y))
        context.stroke(lead, with: .color(strokeColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        
        // Triangle pointing right
        var triangle = Path()
        triangle.move(to: CGPoint(x: center.x - hw, y: center.y - hh))
        triangle.addLine(to: CGPoint(x: center.x - hw, y: center.y + hh))
        triangle.addLine(to: CGPoint(x: center.x + hw, y: center.y))
        triangle.closeSubpath()
        context.fill(triangle, with: .color(fillColor))
        context.stroke(triangle, with: .color(strokeColor), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
        
        // Cathode bar
        var bar = Path()
        bar.move(to: CGPoint(x: center.x + hw, y: center.y - hh))
        bar.addLine(to: CGPoint(x: center.x + hw, y: center.y + hh))
        context.stroke(bar, with: .color(strokeColor), style: StrokeStyle(lineWidth: lineWidth + 0.5, lineCap: .round))
    }
    
    // MARK: - BJT Transistor (NPN)
    private static func drawTransistor(context: GraphicsContext, center: CGPoint, color: Color, lineWidth: CGFloat, grid: CGFloat) {
        let bw = grid * 0.5
        let bh = grid * 1.0
        
        var path = Path()
        // Base terminal lead
        path.move(to: CGPoint(x: center.x - 2 * grid, y: center.y))
        path.addLine(to: CGPoint(x: center.x - bw, y: center.y))
        
        // Base bar
        path.move(to: CGPoint(x: center.x - bw, y: center.y - bh))
        path.addLine(to: CGPoint(x: center.x - bw, y: center.y + bh))
        
        // Collector lead: from pin (2*grid, -2*grid) down to (2*grid, -bh) then diagonal to base bar
        path.move(to: CGPoint(x: center.x + 2 * grid, y: center.y - 2 * grid))
        path.addLine(to: CGPoint(x: center.x + 2 * grid, y: center.y - bh))
        path.addLine(to: CGPoint(x: center.x - bw + 1.0, y: center.y - bh * 0.4))
        
        // Emitter lead: from pin (2*grid, 2*grid) up to (2*grid, bh) then diagonal to base bar
        path.move(to: CGPoint(x: center.x + 2 * grid, y: center.y + 2 * grid))
        path.addLine(to: CGPoint(x: center.x + 2 * grid, y: center.y + bh))
        path.addLine(to: CGPoint(x: center.x - bw + 1.0, y: center.y + bh * 0.4))
        
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        
        // Emitter arrow (outward)
        var arrow = Path()
        let ax = center.x + grid * 0.9
        let ay = center.y + bh * 0.85
        arrow.move(to: CGPoint(x: ax, y: ay))
        arrow.addLine(to: CGPoint(x: ax - grid * 0.45, y: ay - grid * 0.25))
        arrow.addLine(to: CGPoint(x: ax - grid * 0.25, y: ay - grid * 0.45))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color))
    }
    
    // MARK: - Switch
    private static func drawSwitch(context: GraphicsContext, center: CGPoint, color: Color, lineWidth: CGFloat, grid: CGFloat, isClosed: Bool) {
        var leads = Path()
        leads.move(to: CGPoint(x: center.x - 2 * grid, y: center.y))
        leads.addLine(to: CGPoint(x: center.x - grid, y: center.y))
        leads.move(to: CGPoint(x: center.x + grid, y: center.y))
        leads.addLine(to: CGPoint(x: center.x + 2 * grid, y: center.y))
        context.stroke(leads, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        
        // Terminals
        let r: CGFloat = 3.0
        let leftTerminal = CGRect(x: center.x - grid - r, y: center.y - r, width: 2 * r, height: 2 * r)
        let rightTerminal = CGRect(x: center.x + grid - r, y: center.y - r, width: 2 * r, height: 2 * r)
        context.stroke(Path(ellipseIn: leftTerminal), with: .color(color), style: StrokeStyle(lineWidth: lineWidth))
        context.stroke(Path(ellipseIn: rightTerminal), with: .color(color), style: StrokeStyle(lineWidth: lineWidth))
        
        // Switch contact arm
        var arm = Path()
        if isClosed {
            arm.move(to: CGPoint(x: center.x - grid, y: center.y))
            arm.addLine(to: CGPoint(x: center.x + grid, y: center.y))
        } else {
            arm.move(to: CGPoint(x: center.x - grid, y: center.y))
            arm.addLine(to: CGPoint(x: center.x + grid * 0.75, y: center.y - grid * 0.75))
        }
        context.stroke(arm, with: .color(color), style: StrokeStyle(lineWidth: lineWidth + 0.5, lineCap: .round))
    }
}
