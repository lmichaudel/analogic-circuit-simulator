import Foundation
import SwiftUI

public class CircuitWire: Identifiable, ObservableObject, @unchecked Sendable {
    public let id: Int
    @Published public var fromComp: Int
    @Published public var fromPin: Int
    @Published public var toComp: Int
    @Published public var toPin: Int
    @Published public var isFlipped: Bool
    @Published public var isSelected: Bool = false
    
    public init(id: Int, fromComp: Int, fromPin: Int, toComp: Int, toPin: Int, isFlipped: Bool = false) {
        self.id = id
        self.fromComp = fromComp
        self.fromPin = fromPin
        self.toComp = toComp
        self.toPin = toPin
        self.isFlipped = isFlipped
    }
    
    public func serialize() -> String {
        return "WIRE \(id) \(fromComp) \(fromPin) \(toComp) \(toPin) \(isFlipped ? 1 : 0)"
    }
    
    public static func deserialize(line: String) -> CircuitWire? {
        let parts = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count >= 7, parts[0] == "WIRE" else { return nil }
        guard let id = Int(parts[1]),
              let fc = Int(parts[2]),
              let fp = Int(parts[3]),
              let tc = Int(parts[4]),
              let tp = Int(parts[5]),
              let flip = Int(parts[6]) else {
            return nil
        }
        return CircuitWire(id: id, fromComp: fc, fromPin: fp, toComp: tc, toPin: tp, isFlipped: flip != 0)
    }
    
    public func getElbow(a: CGPoint, b: CGPoint) -> CGPoint {
        isFlipped ? CGPoint(x: a.x, y: b.y) : CGPoint(x: b.x, y: a.y)
    }
}
