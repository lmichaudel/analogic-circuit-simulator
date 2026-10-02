import Foundation
import SwiftUI

public class CircuitComponent: Identifiable, ObservableObject, @unchecked Sendable {
    public let id: Int
    @Published public var type: ComponentType
    @Published public var position: CGPoint
    @Published public var rotation: Int // 0: 0°, 1: 90°, 2: 180°, 3: 270°
    @Published public var label: String
    @Published public var isSelected: Bool = false
    
    // Attributes
    @Published public var resistance: Double = 1000.0
    @Published public var voltage: Double = 5.0
    @Published public var currentValue: Double = 0.01
    @Published public var isClosed: Bool = true
    
    // Diode
    @Published public var diodeIs: Double = 1e-12
    @Published public var diodeN: Double = 1.0
    @Published public var diodeVt: Double = 0.02585
    
    // Capacitor
    @Published public var capacitance: Double = 100e-6
    @Published public var capacitorDt: Double = 0.005
    
    // Transistor
    @Published public var transistorIs: Double = 1e-14
    @Published public var transistorBetaF: Double = 100.0
    @Published public var transistorBetaR: Double = 5.0
    @Published public var transistorVt: Double = 0.02585
    
    // Coil
    @Published public var inductance: Double = 1e-3
    @Published public var coilDt: Double = 0.005
    
    public init(id: Int, type: ComponentType, position: CGPoint, rotation: Int = 0, label: String = "") {
        self.id = id
        self.type = type
        self.position = position
        self.rotation = rotation % 4
        self.label = label.isEmpty ? "\(type.defaultPrefix)\(id)" : label
        
        switch type {
        case .resistor: self.resistance = 1000.0
        case .voltageSource: self.voltage = 5.0
        case .currentSource: self.currentValue = 0.01
        case .switchComp: self.isClosed = true
        case .capacitor: self.capacitance = 100e-6
        case .coil: self.inductance = 1e-3
        case .diode:
            self.diodeIs = 1e-12
            self.diodeN = 1.0
            self.diodeVt = 0.02585
        case .transistor:
            self.transistorIs = 1e-14
            self.transistorBetaF = 100.0
            self.transistorBetaR = 5.0
            self.transistorVt = 0.02585
        default: break
        }
    }
    
    public var pinCount: Int {
        type.pinCount
    }
    
    public func transform(local: CGPoint) -> CGPoint {
        let angle = Double(rotation) * Double.pi / 2.0
        let s = sin(angle)
        let c = cos(angle)
        return CGPoint(
            x: position.x + local.x * c - local.y * s,
            y: position.y + local.x * s + local.y * c
        )
    }
    
    public func getPinWorldPos(index: Int, grid: CGFloat = 20.0) -> CGPoint {
        transform(local: type.pinLocalPos(index: index, grid: grid))
    }
    
    public func serialize() -> String {
        var line = "COMP \(id) \(type.rawValue) \(Int(round(position.x))) \(Int(round(position.y))) \(label) \(rotation)"
        switch type {
        case .resistor:
            line += " \(resistance)"
        case .voltageSource:
            line += " \(voltage)"
        case .currentSource:
            line += " \(currentValue)"
        case .switchComp:
            line += " \(isClosed ? 1 : 0)"
        case .diode:
            line += " \(diodeIs) \(diodeN) \(diodeVt)"
        case .capacitor:
            line += " \(capacitance) \(capacitorDt)"
        case .transistor:
            line += " \(transistorIs) \(transistorBetaF) \(transistorBetaR) \(transistorVt)"
        case .coil:
            line += " \(inductance) \(coilDt)"
        case .ground:
            break
        }
        return line
    }
    
    public static func deserialize(line: String) -> CircuitComponent? {
        let parts = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count >= 6, parts[0] == "COMP" else { return nil }
        
        guard let id = Int(parts[1]),
              let compType = ComponentType(rawValue: parts[2]),
              let px = Double(parts[3]),
              let py = Double(parts[4]),
              let rot = Int(parts[6]) else {
            return nil
        }
        let name = parts[5]
        
        let comp = CircuitComponent(id: id, type: compType, position: CGPoint(x: px, y: py), rotation: rot, label: name)
        let attrCount = parts.count - 7
        
        switch compType {
        case .resistor:
            if attrCount >= 1, let r = Double(parts[7]) { comp.resistance = r }
        case .voltageSource:
            if attrCount >= 1, let v = Double(parts[7]) { comp.voltage = v }
        case .currentSource:
            if attrCount >= 1, let c = Double(parts[7]) { comp.currentValue = c }
        case .switchComp:
            if attrCount >= 1, let s = Int(parts[7]) { comp.isClosed = (s != 0) }
        case .diode:
            if attrCount >= 3,
               let isVal = Double(parts[7]),
               let nVal = Double(parts[8]),
               let vtVal = Double(parts[9]) {
                comp.diodeIs = isVal
                comp.diodeN = nVal
                comp.diodeVt = vtVal
            }
        case .capacitor:
            if attrCount >= 2,
               let cVal = Double(parts[7]),
               let dtVal = Double(parts[8]) {
                comp.capacitance = cVal
                comp.capacitorDt = dtVal
            }
        case .transistor:
            if attrCount >= 4,
               let isVal = Double(parts[7]),
               let bfVal = Double(parts[8]),
               let brVal = Double(parts[9]),
               let vtVal = Double(parts[10]) {
                comp.transistorIs = isVal
                comp.transistorBetaF = bfVal
                comp.transistorBetaR = brVal
                comp.transistorVt = vtVal
            }
        case .coil:
            if attrCount >= 2,
               let lVal = Double(parts[7]),
               let dtVal = Double(parts[8]) {
                comp.inductance = lVal
                comp.coilDt = dtVal
            }
        case .ground:
            break
        }
        
        return comp
    }
}
