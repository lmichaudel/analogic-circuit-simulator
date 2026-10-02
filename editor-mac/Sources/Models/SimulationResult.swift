import Foundation

public enum SolverMethod: Int, CaseIterable, Identifiable, Sendable {
    case simple = 0
    case numericalGradient = 1
    case analyticalGradient = 2
    case newtonRaphson = 3
    
    public var id: Int { rawValue }
    
    public var name: String {
        switch self {
        case .simple: return "Simple (Naive)"
        case .numericalGradient: return "Numerical Gradient"
        case .analyticalGradient: return "Analytical Gradient"
        case .newtonRaphson: return "Newton-Raphson"
        }
    }
    
    public var shortDescription: String {
        switch self {
        case .simple: return "Fixed-step relaxation solver"
        case .numericalGradient: return "Finite-difference gradient descent"
        case .analyticalGradient: return "Exact Jacobian gradient descent"
        case .newtonRaphson: return "Second-order Newton-Raphson MNA"
        }
    }
}

public struct SimulationResult: Sendable {
    public var isSimulated: Bool
    public var success: Bool
    public var solveTimeMs: Double
    public var solverMethod: SolverMethod
    public var errorMessage: String?
    
    public var pinVoltages: [Int: Double] // compId * 10 + pinIdx -> Voltage
    public var pinNetNames: [Int: String] // compId * 10 + pinIdx -> Net Name
    public var componentCurrents: [String: Double] // Label -> Current (A)
    public var netVoltages: [String: Double] // Net Name -> Voltage (V)
    
    public init(
        isSimulated: Bool = false,
        success: Bool = false,
        solveTimeMs: Double = 0.0,
        solverMethod: SolverMethod = .newtonRaphson,
        errorMessage: String? = nil,
        pinVoltages: [Int: Double] = [:],
        pinNetNames: [Int: String] = [:],
        componentCurrents: [String: Double] = [:],
        netVoltages: [String: Double] = [:]
    ) {
        self.isSimulated = isSimulated
        self.success = success
        self.solveTimeMs = solveTimeMs
        self.solverMethod = solverMethod
        self.errorMessage = errorMessage
        self.pinVoltages = pinVoltages
        self.pinNetNames = pinNetNames
        self.componentCurrents = componentCurrents
        self.netVoltages = netVoltages
    }
    
    public static var empty: SimulationResult {
        SimulationResult()
    }
}
