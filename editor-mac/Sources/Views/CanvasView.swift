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
            ZStack(alignment: .topTrailing) {
                // Interactive Schematic Canvas
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
                                Label {
                                    Text(type.displayName)
                                } icon: {
                                    Image(nsImage: ComponentIconView.menuImage(for: type))
                                }
                            }
                        }
                    }
                }
                
                // Floating Inspector overlay on component or wire selection
                if let comp = model.selectedComponent {
                    FloatingInspectorView(comp: comp, model: model)
                        .padding(16)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing))
                        ))
                } else if let wire = model.selectedWire {
                    FloatingWireInspector(wire: wire, model: model)
                        .padding(16)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing))
                        ))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: model.selectedComponentId)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: model.selectedWireId)
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
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.magnify, .scrollWheel, .smartMagnify, .rightMouseDown, .keyDown]) { event in
            guard let window = NSApp.keyWindow, event.window == window else { return event }
            
            if event.type == .keyDown {
                // If the user is currently editing inside a text field, let standard typing proceed
                if let responder = window.firstResponder, responder.isKind(of: NSTextView.self) {
                    return event
                }
                
                // Key code 53: Escape (⎋) to deselect / dismiss floating inspector
                if event.keyCode == 53 {
                    if model.selectedComponentId != nil || model.selectedWireId != nil {
                        model.selectedComponentId = nil
                        model.selectedWireId = nil
                        return nil
                    }
                }
                
                // Key code 51: Backspace / Delete (⌫), Key code 117: Forward Delete (⌦)
                if event.keyCode == 51 || event.keyCode == 117 {
                    if model.selectedComponentId != nil || model.selectedWireId != nil {
                        model.removeSelected()
                        return nil
                    }
                }
                
                // Key code 15: 'r' / 'R' to rotate selected component
                if event.keyCode == 15 && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) {
                    if model.selectedComponentId != nil {
                        model.rotateSelected()
                        return nil
                    }
                }
                
                return event
            }
            
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
        
        let zoom = model.zoomScale
        let pinV = model.simulationResult.pinVoltages
        
        // 1. Draw Voltage Arrows on Components
        for comp in model.components {
            if comp.type == .transistor {
                // For BJT: Draw arrows for Vce (collector-emitter) and Vbe (base-emitter)
                if let vc = pinV[comp.id * 10 + 1], let ve = pinV[comp.id * 10 + 2] {
                    let pc = worldToScreen(comp.getPinWorldPos(index: 1))
                    let pe = worldToScreen(comp.getPinWorldPos(index: 2))
                    let diff = vc - ve
                    let (from, to) = diff >= 0 ? (pe, pc) : (pc, pe)
                    drawVoltageArrow(context: context, from: from, to: to, voltage: abs(diff), label: "Vce", normalSign: 1.0)
                }
                if let vb = pinV[comp.id * 10 + 0], let ve = pinV[comp.id * 10 + 2] {
                    let pb = worldToScreen(comp.getPinWorldPos(index: 0))
                    let pe = worldToScreen(comp.getPinWorldPos(index: 2))
                    let diff = vb - ve
                    let (from, to) = diff >= 0 ? (pe, pb) : (pb, pe)
                    drawVoltageArrow(context: context, from: from, to: to, voltage: abs(diff), label: "Vbe", normalSign: -1.0)
                }
            } else if comp.pinCount == 2 {
                // 2-terminal components: Resistor, VoltageSource, CurrentSource, Switch, Diode, Capacitor, Coil
                if let v0 = pinV[comp.id * 10 + 0], let v1 = pinV[comp.id * 10 + 1] {
                    let p0 = worldToScreen(comp.getPinWorldPos(index: 0))
                    let p1 = worldToScreen(comp.getPinWorldPos(index: 1))
                    let diff = v0 - v1
                    // Arrow points toward the higher potential terminal
                    let (from, to) = diff >= 0 ? (p1, p0) : (p0, p1)
                    drawVoltageArrow(context: context, from: from, to: to, voltage: abs(diff))
                }
            }
        }
        
        // 2. Component Branch Currents
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
                .font(.system(size: max(8, 10 * zoom), weight: .bold, design: .rounded))
                .foregroundColor(Color.red)
            
            let badgePos = CGPoint(x: compScreen.x, y: compScreen.y + CircuitModel.grid * 1.5 * zoom)
            context.draw(formatted, at: badgePos, anchor: .top)
        }
    }
    
    // MARK: - Voltage Arrow Drawing
    private func drawVoltageArrow(
        context: GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        voltage: Double,
        label: String? = nil,
        normalSign: CGFloat = 1.0
    ) {
        let zoom = model.zoomScale
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = hypot(dx, dy)
        guard len > 1.0 else { return }
        
        let ux = dx / len
        let uy = dy / len
        let nx = -uy
        let ny = ux
        
        // Prefer normal pointing upward/leftward so arrows arch away consistently
        let preferUp = (ny < -0.01 || (abs(ny) <= 0.01 && nx < 0))
        let baseNormX = preferUp ? nx : -nx
        let baseNormY = preferUp ? ny : -ny
        let normX = baseNormX * normalSign
        let normY = baseNormY * normalSign
        
        let pinOffset = 6.0 * zoom
        let archHeight = 24.0 * zoom
        let startPt = CGPoint(x: from.x + normX * pinOffset, y: from.y + normY * pinOffset)
        let endPt = CGPoint(x: to.x + normX * pinOffset, y: to.y + normY * pinOffset)
        let midPt = CGPoint(x: (from.x + to.x) / 2.0, y: (from.y + to.y) / 2.0)
        let ctrlPt = CGPoint(x: midPt.x + normX * (pinOffset + archHeight), y: midPt.y + normY * (pinOffset + archHeight))
        
        // Arrowhead geometry
        let headLen = 8.5 * zoom
        let headWidth = 4.2 * zoom
        
        // Tangent vector entering endPt
        let tax = endPt.x - ctrlPt.x
        let tay = endPt.y - ctrlPt.y
        let taLen = hypot(tax, tay)
        let tux = taLen > 0.001 ? tax / taLen : ux
        let tuy = taLen > 0.001 ? tay / taLen : uy
        
        let arrowBase = CGPoint(x: endPt.x - tux * headLen, y: endPt.y - tuy * headLen)
        let tnx = -tuy
        let tny = tux
        let arrowLeft = CGPoint(x: arrowBase.x + tnx * headWidth, y: arrowBase.y + tny * headWidth)
        let arrowRight = CGPoint(x: arrowBase.x - tnx * headWidth, y: arrowBase.y - tny * headWidth)
        
        let arrowColor = Color(nsColor: .systemGreen)
        
        // Draw the curved shaft
        var shaft = Path()
        shaft.move(to: startPt)
        if voltage >= 1e-4 {
            shaft.addQuadCurve(to: arrowBase, control: ctrlPt)
        } else {
            shaft.addQuadCurve(to: endPt, control: ctrlPt)
        }
        context.stroke(
            shaft,
            with: .color(arrowColor),
            style: StrokeStyle(lineWidth: 1.6 * zoom, lineCap: .round, lineJoin: .round)
        )
        
        // Draw arrowhead or zero-voltage endpoints
        if voltage >= 1e-4 {
            var head = Path()
            head.move(to: endPt)
            head.addLine(to: arrowLeft)
            head.addLine(to: arrowRight)
            head.closeSubpath()
            context.fill(head, with: .color(arrowColor))
        } else {
            let r = 2.0 * zoom
            context.fill(Path(ellipseIn: CGRect(x: startPt.x - r, y: startPt.y - r, width: 2 * r, height: 2 * r)), with: .color(arrowColor))
            context.fill(Path(ellipseIn: CGRect(x: endPt.x - r, y: endPt.y - r, width: 2 * r, height: 2 * r)), with: .color(arrowColor))
        }
        
        // Peak of the curve at t = 0.5
        let apex = CGPoint(
            x: 0.25 * startPt.x + 0.5 * ctrlPt.x + 0.25 * endPt.x,
            y: 0.25 * startPt.y + 0.5 * ctrlPt.y + 0.25 * endPt.y
        )
        
        let vText: String
        if let customLabel = label {
            vText = "\(customLabel): \(formatVoltage(voltage))"
        } else {
            vText = formatVoltage(voltage)
        }
        
        let fontSize = max(8.5, 9.5 * zoom)
        let charWidth = fontSize * 0.62
        let badgeW = CGFloat(vText.count) * charWidth + 10.0 * zoom
        let badgeH = fontSize + 6.0 * zoom
        let badgeCenter = CGPoint(x: apex.x + normX * 4.0 * zoom, y: apex.y + normY * 4.0 * zoom)
        let badgeRect = CGRect(x: badgeCenter.x - badgeW / 2.0, y: badgeCenter.y - badgeH / 2.0, width: badgeW, height: badgeH)
        
        // Background pill badge
        context.fill(
            Path(roundedRect: badgeRect, cornerRadius: 4.0 * zoom),
            with: .color(Color(nsColor: .windowBackgroundColor).opacity(0.92))
        )
        context.stroke(
            Path(roundedRect: badgeRect, cornerRadius: 4.0 * zoom),
            with: .color(arrowColor.opacity(0.4)),
            lineWidth: 1.0 * zoom
        )
        
        let textObj = Text(vText)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundColor(arrowColor)
        context.draw(textObj, at: badgeCenter, anchor: .center)
    }
    
    private func formatVoltage(_ v: Double) -> String {
        let absV = abs(v)
        if absV >= 1000.0 {
            return String(format: "%.2f kV", v / 1000.0)
        } else if absV >= 0.1 {
            return String(format: "%.2f V", v)
        } else if absV >= 0.0001 {
            return String(format: "%.1f mV", v * 1000.0)
        } else if absV > 0 {
            return String(format: "%.1f µV", v * 1_000_000.0)
        } else {
            return "0.00 V"
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
