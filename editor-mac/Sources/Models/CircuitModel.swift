import Foundation
import SwiftUI
import Combine

@MainActor
public class CircuitModel: ObservableObject {
    public static let grid: CGFloat = 20.0
    
    @Published public var components: [CircuitComponent] = []
    @Published public var wires: [CircuitWire] = []
    @Published public var nextId: Int = 1
    
    @Published public var selectedComponentId: Int? = nil {
        didSet {
            for c in components {
                c.isSelected = (c.id == selectedComponentId)
            }
            if selectedComponentId != nil {
                selectedWireId = nil
            }
        }
    }
    
    @Published public var selectedWireId: Int? = nil {
        didSet {
            for w in wires {
                w.isSelected = (w.id == selectedWireId)
            }
            if selectedWireId != nil {
                selectedComponentId = nil
            }
        }
    }
    
    // Wire drawing state
    @Published public var isDrawingWire: Bool = false
    @Published public var wireStartCompId: Int = -1
    @Published public var wireStartPinIdx: Int = -1
    @Published public var wireCurrentMousePos: CGPoint = .zero
    @Published public var wireFlipLive: Bool = false
    
    // Viewport
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var panOffset: CGPoint = .zero
    
    // Simulation state
    @Published public var solverMethod: SolverMethod = .newtonRaphson
    @Published public var isSimulating: Bool = false
    @Published public var simulationResult: SimulationResult = .empty
    @Published public var showCurrentIndicators: Bool = false
    
    // File state
    @Published public var currentFileURL: URL? = nil
    @Published public var documentTitle: String = "Untitled Circuit"
    @Published public var isModified: Bool = false
    @Published public var statusMessage: String = "Ready"
    
    public init() {}
    
    public var selectedComponent: CircuitComponent? {
        guard let id = selectedComponentId else { return nil }
        return components.first(where: { $0.id == id })
    }
    
    public var selectedWire: CircuitWire? {
        guard let id = selectedWireId else { return nil }
        return wires.first(where: { $0.id == id })
    }
    
    public static func snap(_ v: CGFloat) -> CGFloat {
        (v / grid).rounded() * grid
    }
    
    public static func snap(_ p: CGPoint) -> CGPoint {
        CGPoint(x: snap(p.x), y: snap(p.y))
    }
    
    // MARK: - Component Management
    
    @discardableResult
    public func addComponent(type: ComponentType, at pos: CGPoint? = nil) -> CircuitComponent {
        let spawnPos = pos ?? CGPoint(
            x: Self.snap(400.0 - panOffset.x),
            y: Self.snap(260.0 - panOffset.y)
        )
        let id = nextId
        nextId += 1
        
        let comp = CircuitComponent(
            id: id,
            type: type,
            position: Self.snap(spawnPos),
            rotation: 0
        )
        components.append(comp)
        selectedComponentId = comp.id
        invalidateSimulation()
        isModified = true
        statusMessage = "Added \(comp.label)"
        return comp
    }
    
    public func removeComponent(id: Int) {
        wires.removeAll(where: { $0.fromComp == id || $0.toComp == id })
        components.removeAll(where: { $0.id == id })
        if selectedComponentId == id {
            selectedComponentId = nil
        }
        invalidateSimulation()
        isModified = true
        objectWillChange.send()
        statusMessage = "Deleted component"
    }
    
    public func rotateSelected() {
        guard let comp = selectedComponent else { return }
        comp.rotation = (comp.rotation + 1) % 4
        invalidateSimulation()
        isModified = true
        objectWillChange.send()
        statusMessage = "Rotated \(comp.label)"
    }
    
    public func duplicateSelected() {
        guard let comp = selectedComponent else { return }
        let newComp = addComponent(
            type: comp.type,
            at: CGPoint(x: comp.position.x + Self.grid * 3, y: comp.position.y + Self.grid * 3)
        )
        newComp.rotation = comp.rotation
        newComp.resistance = comp.resistance
        newComp.voltage = comp.voltage
        newComp.currentValue = comp.currentValue
        newComp.isClosed = comp.isClosed
        newComp.capacitance = comp.capacitance
        newComp.inductance = comp.inductance
        newComp.diodeIs = comp.diodeIs
        newComp.diodeN = comp.diodeN
        newComp.diodeVt = comp.diodeVt
        newComp.transistorIs = comp.transistorIs
        newComp.transistorBetaF = comp.transistorBetaF
        newComp.transistorBetaR = comp.transistorBetaR
        newComp.transistorVt = comp.transistorVt
        selectedComponentId = newComp.id
    }
    
    // MARK: - Wire Management
    
    public func startWire(fromComp: Int, fromPin: Int) {
        isDrawingWire = true
        wireStartCompId = fromComp
        wireStartPinIdx = fromPin
        selectedComponentId = nil
        selectedWireId = nil
        statusMessage = "Select second pin to connect wire"
    }
    
    public func finishWire(toComp: Int, toPin: Int) {
        guard isDrawingWire else { return }
        if wireStartCompId == toComp && wireStartPinIdx == toPin {
            cancelWire()
            return
        }
        
        let wid = nextId
        nextId += 1
        let wire = CircuitWire(
            id: wid,
            fromComp: wireStartCompId,
            fromPin: wireStartPinIdx,
            toComp: toComp,
            toPin: toPin,
            isFlipped: wireFlipLive
        )
        wires.append(wire)
        selectedWireId = wire.id
        cancelWire()
        invalidateSimulation()
        isModified = true
        statusMessage = "Connected wire #\(wid)"
    }
    
    public func cancelWire() {
        isDrawingWire = false
        wireStartCompId = -1
        wireStartPinIdx = -1
        wireFlipLive = false
    }
    
    public func removeWire(id: Int) {
        wires.removeAll(where: { $0.id == id })
        if selectedWireId == id {
            selectedWireId = nil
        }
        invalidateSimulation()
        isModified = true
        statusMessage = "Deleted wire"
    }
    
    public func flipSelectedWire() {
        guard let wire = selectedWire else { return }
        wire.isFlipped.toggle()
        invalidateSimulation()
        isModified = true
    }
    
    public func removeSelected() {
        if let cid = selectedComponentId {
            removeComponent(id: cid)
        } else if let wid = selectedWireId {
            removeWire(id: wid)
        }
    }
    
    // MARK: - Simulation Management
    
    public func invalidateSimulation() {
        if simulationResult.isSimulated {
            simulationResult = .empty
        }
    }
    
    public func clearCircuit() {
        components.removeAll()
        wires.removeAll()
        nextId = 1
        selectedComponentId = nil
        selectedWireId = nil
        cancelWire()
        invalidateSimulation()
        currentFileURL = nil
        documentTitle = "Untitled Circuit"
        isModified = false
        statusMessage = "Created new empty circuit"
    }
    
    // MARK: - Serialization
    
    public func serialize() -> String {
        var lines: [String] = []
        lines.append("nextId \(nextId)")
        for c in components {
            lines.append(c.serialize())
        }
        for w in wires {
            lines.append(w.serialize())
        }
        return lines.joined(separator: "\n") + "\n"
    }
    
    public func load(from content: String, fileURL: URL? = nil, title: String? = nil) -> Bool {
        var newComponents: [CircuitComponent] = []
        var newWires: [CircuitWire] = []
        var parsedNextId = 1
        
        let lines = content.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            if line.hasPrefix("nextId") {
                let parts = line.split(separator: " ")
                if parts.count >= 2, let id = Int(parts[1]) {
                    parsedNextId = id
                }
            } else if line.hasPrefix("COMP") {
                if let c = CircuitComponent.deserialize(line: line) {
                    newComponents.append(c)
                }
            } else if line.hasPrefix("WIRE") {
                if let w = CircuitWire.deserialize(line: line) {
                    newWires.append(w)
                }
            }
        }
        
        self.components = newComponents
        self.wires = newWires
        self.nextId = max(parsedNextId, (newComponents.map(\.id) + newWires.map(\.id)).max().map { $0 + 1 } ?? 1)
        self.selectedComponentId = nil
        self.selectedWireId = nil
        self.cancelWire()
        self.invalidateSimulation()
        self.currentFileURL = fileURL
        self.documentTitle = title ?? fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled Circuit"
        self.isModified = false
        self.statusMessage = "Loaded \(newComponents.count) components, \(newWires.count) wires"
        return true
    }
    
    public func save(to url: URL) -> Bool {
        let content = serialize()
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            currentFileURL = url
            documentTitle = url.deletingPathExtension().lastPathComponent
            isModified = false
            statusMessage = "Saved to \(url.lastPathComponent)"
            return true
        } catch {
            statusMessage = "Error saving file: \(error.localizedDescription)"
            return false
        }
    }
    
    public func load(from url: URL) -> Bool {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return load(from: content, fileURL: url)
        } catch {
            statusMessage = "Error opening file: \(error.localizedDescription)"
            return false
        }
    }
}
