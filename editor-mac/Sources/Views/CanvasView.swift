import Foundation
import SwiftUI
import AppKit

public struct CanvasView: View {
    @ObservedObject var model: CircuitModel
    
    @State private var dragComponentId: Int? = nil
    @State private var dragStartCompPos: CGPoint = .zero
    @State private var dragStartMousePos: CGPoint = .zero
    @State private var hoveredPin: (compId: Int, pinIdx: Int)? = nil
    
    // Pan & Zoom tracking
    @State private var isPanning: Bool = false
    @State private var panStartOffset: CGPoint = .zero
    @State private var currentMousePos: CGPoint = CGPoint(x: 400, y: 300)
    @State private var lastMagnification: CGFloat = 1.0
    @State private var eventMonitor: Any? = nil
    
    public init(model: CircuitModel) {
        self.model = model
    }
    
    private func screenToWorld(_ pt: CGPoint) -> CGPoint {
        CGPoint(
            x: (pt.x - model.panOffset.x) / model.zoomScale,
            y: (pt.y - model.panOffset.y) / model.zoomScale
        )
    }
    
    private func worldToScreen(_ pt: CGPoint) -> CGPoint {
        CGPoint(
            x: pt.x * model.zoomScale + model.panOffset.x,
            y: pt.y * model.zoomScale + model.panOffset.y
        )
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color matching macOS content area
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
                
                // Drawing Canvas
                Canvas { context, size in
                    drawGrid(context: context, size: size)
                    drawWires(context: context)
                    drawActiveWirePreview(context: context)
                    drawComponents(context: context)
                    drawSimulationBadges(context: context)
                }
                .drawingGroup() // Metal hardware acceleration
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .local)
                    .onChanged { value in
                        handleDragChanged(value: value, in: geometry.size)
                    }
                    .onEnded { value in
                        handleDragEnded(value: value)
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastMagnification
                        lastMagnification = value
                        zoomAtScreenPoint(factor: delta, screenPt: currentMousePos)
                    }
                    .onEnded { _ in
                        lastMagnification = 1.0
                    }
            )
            .onTapGesture { location in
                handleTap(at: location)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    currentMousePos = location
                    handleHover(at: location)
                case .ended:
                    hoveredPin = nil
                }
            }
            .contextMenu {
                if let comp = model.selectedComponent {
                    Text("\(comp.label) (\(comp.type.displayName))")
                        .font(.headline)
                    Divider()
                    Button {
                        model.rotateSelected()
                    } label: {
                        Label("Rotate 90°", systemImage: "rotate.right")
                    }
                    Button {
                        model.duplicateSelected()
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) {
                        model.removeSelected()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Divider()
                }
                
                Section("Add Component Here") {
                    ForEach(ComponentType.allCases) { type in
                        Button {
                            let worldPos = screenToWorld(currentMousePos)
                            model.addComponent(type: type, at: worldPos)
                        } label: {
                            Label(type.displayName, systemImage: type.sfSymbol)
                        }
                    }
                }
            }
            .onAppear {
                setupTrackpadMonitor()
            }
            .onDisappear {
                removeTrackpadMonitor()
            }
        }
    }
    
    // MARK: - Trackpad Gesture Monitor
    private func setupTrackpadMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.magnify, .scrollWheel, .smartMagnify, .rightMouseDown]) { event in
            guard let window = NSApp.keyWindow, event.window == window else { return event }
            
            let winLoc = event.locationInWindow
            let winH = window.contentView?.frame.height ?? 800
            let screenPt = CGPoint(x: winLoc.x, y: winH - winLoc.y)
            
            switch event.type {
            case .rightMouseDown:
                currentMousePos = screenPt
                if model.isDrawingWire {
                    model.cancelWire()
                } else {
                    let worldPt = screenToWorld(screenPt)
                    var found = false
                    for comp in model.components.reversed() {
                        let dx = abs(worldPt.x - comp.position.x)
                        let dy = abs(worldPt.y - comp.position.y)
                        if dx <= CircuitModel.grid * 2.0 && dy <= CircuitModel.grid * 2.0 {
                            model.selectedComponentId = comp.id
                            found = true
                            break
                        }
                    }
                    if !found {
                        model.selectedComponentId = nil
                    }
                }
                return event // Let AppKit display the contextMenu
                
            case .magnify:
                // Smooth trackpad pinch gesture zoom centered on cursor
                let factor = 1.0 + event.magnification
                zoomAtScreenPoint(factor: factor, screenPt: screenPt)
                return nil
                
            case .scrollWheel:
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
                    // Command/Option + two-finger scroll zooms in/out
                    let factor = 1.0 + (event.scrollingDeltaY * 0.015)
                    zoomAtScreenPoint(factor: factor, screenPt: screenPt)
                    return nil
                } else if !model.isDrawingWire && dragComponentId == nil {
                    // Smooth two-finger trackpad panning with inertia
                    let dx = event.scrollingDeltaX
                    let dy = event.scrollingDeltaY
                    if abs(dx) > 0.01 || abs(dy) > 0.01 {
                        model.panOffset.x += dx
                        model.panOffset.y += dy
                    }
                    return nil
                }
                
            case .smartMagnify:
                // Two-finger double tap smart zoom toggle
                withAnimation(.easeOut(duration: 0.2)) {
                    if abs(model.zoomScale - 1.0) < 0.15 {
                        zoomAtScreenPoint(factor: 1.5, screenPt: screenPt)
                    } else {
                        model.zoomScale = 1.0
                    }
                }
                return nil
                
            default:
                break
            }
            
            return event
        }
    }
    
    private func removeTrackpadMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func zoomAtScreenPoint(factor: CGFloat, screenPt: CGPoint) {
        let oldScale = model.zoomScale
        let newScale = min(max(oldScale * factor, 0.25), 4.0)
        guard abs(newScale - oldScale) > 1e-4 else { return }
        
        // Pivot point in world space before zoom
        let worldX = (screenPt.x - model.panOffset.x) / oldScale
        let worldY = (screenPt.y - model.panOffset.y) / oldScale
        
        model.zoomScale = newScale
        model.panOffset = CGPoint(
            x: screenPt.x - worldX * newScale,
            y: screenPt.y - worldY * newScale
        )
    }
    
    // MARK: - Grid Drawing
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let grid = CircuitModel.grid * model.zoomScale
        guard grid >= 8.0 else { return }
        
        let startX = model.panOffset.x.truncatingRemainder(dividingBy: grid)
        let startY = model.panOffset.y.truncatingRemainder(dividingBy: grid)
        
        var dotPath = Path()
        let dotR: CGFloat = model.zoomScale > 1.2 ? 1.2 : 0.9
        
        var x = startX
        while x < size.width {
            var y = startY
            while y < size.height {
                dotPath.addEllipse(in: CGRect(x: x - dotR, y: y - dotR, width: 2 * dotR, height: 2 * dotR))
                y += grid
            }
            x += grid
        }
        
        let dotColor = Color.primary.opacity(0.12)
        context.fill(dotPath, with: .color(dotColor))
    }
    
    // MARK: - Wires Drawing
    private func drawWires(context: GraphicsContext) {
        let compMap = Dictionary(uniqueKeysWithValues: model.components.map { ($0.id, $0) })
        
        for wire in model.wires {
            guard let fc = compMap[wire.fromComp], let tc = compMap[wire.toComp] else { continue }
            let pA = worldToScreen(fc.getPinWorldPos(index: wire.fromPin))
            let pB = worldToScreen(tc.getPinWorldPos(index: wire.toPin))
            let elbow = wire.isFlipped ? CGPoint(x: pA.x, y: pB.y) : CGPoint(x: pB.x, y: pA.y)
            
            var path = Path()
            path.move(to: pA)
            path.addLine(to: elbow)
            path.addLine(to: pB)
            
            if wire.isSelected {
                context.stroke(path, with: .color(Color.green.opacity(0.35)), style: StrokeStyle(lineWidth: 6.0 * model.zoomScale, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(Color.green), style: StrokeStyle(lineWidth: 2.2 * model.zoomScale, lineCap: .round, lineJoin: .round))
            } else {
                let wireColor = Color.primary.opacity(0.85)
                context.stroke(path, with: .color(wireColor), style: StrokeStyle(lineWidth: 1.6 * model.zoomScale, lineCap: .round, lineJoin: .round))
            }
        }
    }
    
    // MARK: - Active Wire Preview
    private func drawActiveWirePreview(context: GraphicsContext) {
        guard model.isDrawingWire,
              let startComp = model.components.first(where: { $0.id == model.wireStartCompId }) else {
            return
        }
        
        let pA = worldToScreen(startComp.getPinWorldPos(index: model.wireStartPinIdx))
        let pB = worldToScreen(model.wireCurrentMousePos)
        let elbow = model.wireFlipLive ? CGPoint(x: pA.x, y: pB.y) : CGPoint(x: pB.x, y: pA.y)
        
        var path = Path()
        path.move(to: pA)
        path.addLine(to: elbow)
        path.addLine(to: pB)
        
        let dashStyle = StrokeStyle(lineWidth: 2.0 * model.zoomScale, lineCap: .round, lineJoin: .round, dash: [6, 4])
        context.stroke(path, with: .color(Color.accentColor), style: dashStyle)
    }
    
    // MARK: - Components Drawing
    private func drawComponents(context: GraphicsContext) {
        for comp in model.components {
            let screenPos = worldToScreen(comp.position)
            let compSize = CGSize(width: 120 * model.zoomScale, height: 120 * model.zoomScale)
            
            var compContext = context
            compContext.translateBy(x: screenPos.x, y: screenPos.y)
            compContext.rotate(by: Angle(degrees: Double(comp.rotation * 90)))
            compContext.translateBy(x: -compSize.width / 2.0, y: -compSize.height / 2.0)
            
            if comp.isSelected {
                let haloRect = CGRect(x: 20 * model.zoomScale, y: 20 * model.zoomScale, width: 80 * model.zoomScale, height: 80 * model.zoomScale)
                compContext.fill(Path(roundedRect: haloRect, cornerRadius: 10 * model.zoomScale), with: .color(Color.accentColor.opacity(0.15)))
                compContext.stroke(Path(roundedRect: haloRect, cornerRadius: 10 * model.zoomScale), with: .color(Color.accentColor), style: StrokeStyle(lineWidth: 1.5 * model.zoomScale, dash: [4, 4]))
            }
            
            let strokeColor = comp.isSelected ? Color.accentColor : Color.primary
            let fillColor = comp.isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.1)
            
            ComponentSymbolRenderer.draw(
                type: comp.type,
                in: compContext,
                size: compSize,
                strokeColor: strokeColor,
                fillColor: fillColor,
                lineWidth: 1.8 * model.zoomScale,
                grid: CircuitModel.grid * model.zoomScale,
                isClosed: comp.isClosed
            )
            
            // Draw pin terminals
            for i in 0..<comp.pinCount {
                let pinWorld = comp.getPinWorldPos(index: i)
                let pinScreen = worldToScreen(pinWorld)
                let isHovered = hoveredPin?.compId == comp.id && hoveredPin?.pinIdx == i
                let isWireStart = model.isDrawingWire && model.wireStartCompId == comp.id && model.wireStartPinIdx == i
                
                let r: CGFloat = (isHovered || isWireStart ? 5.5 : 3.8) * model.zoomScale
                let pinRect = CGRect(x: pinScreen.x - r, y: pinScreen.y - r, width: 2 * r, height: 2 * r)
                
                let pinColor = (isHovered || isWireStart) ? Color.accentColor : Color.blue.opacity(0.7)
                context.fill(Path(ellipseIn: pinRect), with: .color(pinColor))
                context.stroke(Path(ellipseIn: pinRect), with: .color(.white), style: StrokeStyle(lineWidth: 1.0 * model.zoomScale))
            }
            
            // Draw Component Label
            let labelPos = worldToScreen(CGPoint(
                x: comp.position.x + CircuitModel.grid * 1.6,
                y: comp.position.y - CircuitModel.grid * 1.4
            ))
            let labelText = Text(comp.label)
                .font(.system(size: max(9, 11 * model.zoomScale), weight: .bold, design: .monospaced))
                .foregroundColor(comp.isSelected ? .accentColor : .primary.opacity(0.8))
            context.draw(labelText, at: labelPos, anchor: .topLeading)
        }
    }
    
    // MARK: - Simulation Badges Drawing
    private func drawSimulationBadges(context: GraphicsContext) {
        guard model.simulationResult.isSimulated else { return }
        
        let compMap = Dictionary(uniqueKeysWithValues: model.components.map { ($0.id, $0) })
        
        // Node Voltages
        for (pid, voltage) in model.simulationResult.pinVoltages {
            let cid = pid / 10
            let pidx = pid % 10
            guard let comp = compMap[cid] else { continue }
            
            let pinWorld = comp.getPinWorldPos(index: pidx)
            let pinScreen = worldToScreen(pinWorld)
            
            let badgeText = String(format: "%.2f V", voltage)
            let formatted = Text(badgeText)
                .font(.system(size: max(8, 10 * model.zoomScale), weight: .semibold, design: .rounded))
                .foregroundColor(Color.green)
            
            let badgePos = CGPoint(x: pinScreen.x + 12 * model.zoomScale, y: pinScreen.y - 12 * model.zoomScale)
            context.draw(formatted, at: badgePos, anchor: .bottomLeading)
        }
        
        // Component Branch Currents
        for (label, current) in model.simulationResult.componentCurrents {
            guard let comp = model.components.first(where: { $0.label == label }) else { continue }
            let compScreen = worldToScreen(comp.position)
            
            let badgeText: String
            if abs(current) < 1e-4 {
                badgeText = String(format: "%.2f µA", current * 1e6)
            } else if abs(current) < 1.0 {
                badgeText = String(format: "%.2f mA", current * 1e3)
            } else {
                badgeText = String(format: "%.2f A", current)
            }
            
            let formatted = Text(badgeText)
                .font(.system(size: max(8, 10 * model.zoomScale), weight: .bold, design: .rounded))
                .foregroundColor(Color.red)
            
            let badgePos = CGPoint(x: compScreen.x, y: compScreen.y + CircuitModel.grid * 1.5 * model.zoomScale)
            context.draw(formatted, at: badgePos, anchor: .top)
        }
    }
    
    // MARK: - Gesture Handlers
    
    private func handleHover(at location: CGPoint) {
        let worldPt = screenToWorld(location)
        if model.isDrawingWire {
            model.wireCurrentMousePos = worldPt
        }
        
        var foundPin: (compId: Int, pinIdx: Int)? = nil
        let hitRadius = CircuitModel.grid * 0.9
        
        for comp in model.components {
            for i in 0..<comp.pinCount {
                let pinPos = comp.getPinWorldPos(index: i)
                let dx = worldPt.x - pinPos.x
                let dy = worldPt.y - pinPos.y
                if sqrt(dx * dx + dy * dy) < hitRadius {
                    foundPin = (comp.id, i)
                    break
                }
            }
            if foundPin != nil { break }
        }
        hoveredPin = foundPin
    }
    
    private func handleTap(at location: CGPoint) {
        let worldPt = screenToWorld(location)
        let hitRadius = CircuitModel.grid * 0.9
        
        // 1. Check if clicking on a pin
        for comp in model.components {
            for i in 0..<comp.pinCount {
                let pinPos = comp.getPinWorldPos(index: i)
                let dx = worldPt.x - pinPos.x
                let dy = worldPt.y - pinPos.y
                if sqrt(dx * dx + dy * dy) < hitRadius {
                    if model.isDrawingWire {
                        model.finishWire(toComp: comp.id, toPin: i)
                    } else {
                        model.startWire(fromComp: comp.id, fromPin: i)
                    }
                    return
                }
            }
        }
        
        if model.isDrawingWire {
            model.cancelWire()
            return
        }
        
        // 2. Check if clicking on a component body
        for comp in model.components.reversed() {
            let dx = abs(worldPt.x - comp.position.x)
            let dy = abs(worldPt.y - comp.position.y)
            if dx <= CircuitModel.grid * 2.0 && dy <= CircuitModel.grid * 2.0 {
                model.selectedComponentId = comp.id
                return
            }
        }
        
        // 3. Check if clicking on a wire
        var clickedWireId: Int? = nil
        var minDistance: CGFloat = 8.0 / model.zoomScale
        let compMap = Dictionary(uniqueKeysWithValues: model.components.map { ($0.id, $0) })
        
        for wire in model.wires {
            guard let fc = compMap[wire.fromComp], let tc = compMap[wire.toComp] else { continue }
            let pA = fc.getPinWorldPos(index: wire.fromPin)
            let pB = tc.getPinWorldPos(index: wire.toPin)
            let elbow = wire.isFlipped ? CGPoint(x: pA.x, y: pB.y) : CGPoint(x: pB.x, y: pA.y)
            
            let d1 = distanceToSegment(p: worldPt, a: pA, b: elbow)
            let d2 = distanceToSegment(p: worldPt, a: elbow, b: pB)
            let dist = min(d1, d2)
            if dist < minDistance {
                minDistance = dist
                clickedWireId = wire.id
            }
        }
        
        if let wid = clickedWireId {
            model.selectedWireId = wid
            return
        }
        
        // 4. Clicked empty space
        model.selectedComponentId = nil
        model.selectedWireId = nil
    }
    
    private func handleDragChanged(value: DragGesture.Value, in size: CGSize) {
        if model.isDrawingWire {
            model.wireCurrentMousePos = screenToWorld(value.location)
            return
        }
        
        if dragComponentId == nil && !isPanning {
            let startWorld = screenToWorld(value.startLocation)
            for comp in model.components.reversed() {
                let dx = abs(startWorld.x - comp.position.x)
                let dy = abs(startWorld.y - comp.position.y)
                if dx <= CircuitModel.grid * 2.0 && dy <= CircuitModel.grid * 2.0 {
                    dragComponentId = comp.id
                    dragStartCompPos = comp.position
                    dragStartMousePos = startWorld
                    model.selectedComponentId = comp.id
                    break
                }
            }
            
            if dragComponentId == nil {
                isPanning = true
                panStartOffset = model.panOffset
            }
        }
        
        if let cid = dragComponentId, let comp = model.components.first(where: { $0.id == cid }) {
            let currentWorld = screenToWorld(value.location)
            let deltaX = currentWorld.x - dragStartMousePos.x
            let deltaY = currentWorld.y - dragStartMousePos.y
            let targetPos = CGPoint(x: dragStartCompPos.x + deltaX, y: dragStartCompPos.y + deltaY)
            comp.position = CircuitModel.snap(targetPos)
            model.invalidateSimulation()
            model.isModified = true
        } else if isPanning {
            model.panOffset = CGPoint(
                x: panStartOffset.x + value.translation.width,
                y: panStartOffset.y + value.translation.height
            )
        }
    }
    
    private func handleDragEnded(value: DragGesture.Value) {
        dragComponentId = nil
        isPanning = false
    }
    
    private func distanceToSegment(p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        if len2 < 1e-5 {
            let px = p.x - a.x, py = p.y - a.y
            return sqrt(px * px + py * py)
        }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
        t = max(0.0, min(1.0, t))
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        let rx = p.x - projX
        let ry = p.y - projY
        return sqrt(rx * rx + ry * ry)
    }
}
