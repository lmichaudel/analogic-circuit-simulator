import Foundation
import SwiftUI

public enum ComponentCategory: String, CaseIterable, Identifiable {
    case sources = "Sources"
    case passives = "Passives"
    case semiconductors = "Semiconductors"
    case switches = "Switches"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .sources: return "bolt.circle.fill"
        case .passives: return "waveform.path.ecg"
        case .semiconductors: return "cpu.fill"
        case .switches: return "switch.2"
        }
    }
}

public enum ComponentType: String, CaseIterable, Identifiable {
    case ground = "Ground"
    case resistor = "Resistor"
    case voltageSource = "VSource"
    case currentSource = "CSource"
    case switchComp = "Switch"
    case diode = "Diode"
    case capacitor = "Capacitor"
    case transistor = "Transistor"
    case coil = "Coil"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .ground: return "Ground"
        case .resistor: return "Resistor"
        case .voltageSource: return "Voltage Source"
        case .currentSource: return "Current Source"
        case .switchComp: return "Switch"
        case .diode: return "Diode"
        case .capacitor: return "Capacitor"
        case .transistor: return "NPN Transistor"
        case .coil: return "Inductor (Coil)"
        }
    }
    
    public var defaultPrefix: String {
        switch self {
        case .ground: return "GND"
        case .resistor: return "R"
        case .voltageSource: return "V"
        case .currentSource: return "I"
        case .switchComp: return "SW"
        case .diode: return "D"
        case .capacitor: return "C"
        case .transistor: return "Q"
        case .coil: return "L"
        }
    }
    
    public var category: ComponentCategory {
        switch self {
        case .voltageSource, .currentSource:
            return .sources
        case .ground, .resistor, .capacitor, .coil:
            return .passives
        case .diode, .transistor:
            return .semiconductors
        case .switchComp:
            return .switches
        }
    }
    
    public var sfSymbol: String {
        switch self {
        case .ground: return "arrow.down.to.line"
        case .resistor: return "alternatingcurrent"
        case .voltageSource: return "plus.slash.minus"
        case .currentSource: return "arrow.up.circle"
        case .switchComp: return "power"
        case .diode: return "triangle.fill"
        case .capacitor: return "pause"
        case .transistor: return "point.3.filled.connected.triangle.path"
        case .coil: return "skew"
        }
    }
    
    public var pinCount: Int {
        switch self {
        case .ground: return 1
        case .transistor: return 3
        default: return 2
        }
    }
    
    public func pinLocalPos(index: Int, grid: CGFloat = 20.0) -> CGPoint {
        switch self {
        case .ground:
            return CGPoint(x: 0, y: -grid)
        case .transistor:
            if index == 0 { return CGPoint(x: -2 * grid, y: 0) }               // Base
            if index == 1 { return CGPoint(x: 2 * grid, y: -2 * grid) }        // Collector
            return CGPoint(x: 2 * grid, y: 2 * grid)                           // Emitter
        default:
            return (index == 0) ? CGPoint(x: -2 * grid, y: 0) : CGPoint(x: 2 * grid, y: 0)
        }
    }
    
    public func pinName(index: Int) -> String {
        switch self {
        case .ground:
            return "GND"
        case .transistor:
            switch index {
            case 0: return "Base"
            case 1: return "Collector"
            case 2: return "Emitter"
            default: return "Pin \(index)"
            }
        case .voltageSource:
            return index == 0 ? "(+) Anode" : "(-) Cathode"
        case .currentSource:
            return index == 0 ? "(+) In" : "(-) Out"
        case .diode:
            return index == 0 ? "Anode" : "Cathode"
        default:
            return index == 0 ? "Terminal 1" : "Terminal 2"
        }
    }
}
