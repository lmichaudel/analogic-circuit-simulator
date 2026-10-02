import Foundation

public struct SimulationService {
    public static func simulate(circuitText: String, method: SolverMethod) async -> SimulationResult {
        await Task.detached(priority: .userInitiated) {
            guard let cStr = circuitText.cString(using: .utf8) else {
                return SimulationResult(
                    isSimulated: false,
                    success: false,
                    errorMessage: "Failed to encode circuit text"
                )
            }
            
            guard let rawRes = simulate_circuit_str(cStr, Int32(method.rawValue)) else {
                return SimulationResult(
                    isSimulated: false,
                    success: false,
                    errorMessage: "Solver failed to initialize"
                )
            }
            
            defer {
                free_simulation_result(rawRes)
            }
            
            let res = rawRes.pointee
            let success = (res.success != 0)
            let errorMsg = res.error_message != nil ? String(cString: res.error_message) : nil
            let solveTime = res.solve_time_ms
            
            var pinVoltages: [Int: Double] = [:]
            var pinNetNames: [Int: String] = [:]
            var netVoltages: [String: Double] = [:]
            
            if let pArray = res.pin_voltages {
                for i in 0..<Int(res.num_pin_voltages) {
                    let item = pArray[i]
                    let net = item.net_name != nil ? String(cString: item.net_name) : ""
                    pinVoltages[Int(item.pin_id)] = item.voltage
                    pinNetNames[Int(item.pin_id)] = net
                    netVoltages[net] = item.voltage
                }
            }
            
            var compCurrents: [String: Double] = [:]
            if let cArray = res.comp_currents {
                for i in 0..<Int(res.num_comp_currents) {
                    let item = cArray[i]
                    let label = item.comp_label != nil ? String(cString: item.comp_label) : ""
                    compCurrents[label] = item.current
                }
            }
            
            return SimulationResult(
                isSimulated: true,
                success: success,
                solveTimeMs: solveTime,
                solverMethod: method,
                errorMessage: errorMsg,
                pinVoltages: pinVoltages,
                pinNetNames: pinNetNames,
                componentCurrents: compCurrents,
                netVoltages: netVoltages
            )
        }.value
    }
}
