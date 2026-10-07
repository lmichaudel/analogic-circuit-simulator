import Foundation
import SwiftUI

public struct InspectorView: View {
    @ObservedObject var model: CircuitModel
    
    public init(model: CircuitModel) {
        self.model = model
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let comp = model.selectedComponent {
                    ComponentDetailView(comp: comp, model: model)
                } else if let wire = model.selectedWire {
                    WireDetailView(wire: wire, model: model)
                } else {
                    CircuitOverviewInspector(model: model)
                }
                
                if model.simulationResult.isSimulated {
                    Divider()
                    SimulationResultsSection(model: model)
                }
            }
            .padding(14)
        }
        .frame(minWidth: 260, idealWidth: 280)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Component Detail View
struct ComponentDetailView: View {
    @ObservedObject var comp: CircuitComponent
    @ObservedObject var model: CircuitModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ComponentIconView(type: comp.type, color: .accentColor, size: 22)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(comp.type.displayName)
                        .font(.headline)
                    Text("ID: #\(comp.id)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            // Name / Label
            VStack(alignment: .leading, spacing: 4) {
                Text("Identifier")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Label", text: $comp.label)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: comp.label) { _, _ in
                        model.invalidateSimulation()
                        model.isModified = true
                    }
            }
            
            // Rotation Control
            VStack(alignment: .leading, spacing: 4) {
                Text("Orientation")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Picker("", selection: $comp.rotation) {
                        Text("0°").tag(0)
                        Text("90°").tag(1)
                        Text("180°").tag(2)
                        Text("270°").tag(3)
                    }
                    .pickerStyle(.segmented)
                    
                    Button {
                        model.rotateSelected()
                    } label: {
                        Image(systemName: "rotate.right")
                    }
                    .help("Rotate 90° Clockwise (⌘R)")
                }
            }
            
            Divider()
            
            // Component-specific parameters
            Group {
                switch comp.type {
                case .resistor:
                    numericField(title: "Resistance (Ω)", value: $comp.resistance, step: 100.0)
                case .voltageSource:
                    numericField(title: "Voltage (V)", value: $comp.voltage, step: 1.0)
                case .currentSource:
                    numericField(title: "Current (A)", value: $comp.currentValue, step: 0.001)
                case .switchComp:
                    Toggle("Closed Contact", isOn: $comp.isClosed)
                        .toggleStyle(.switch)
                        .onChange(of: comp.isClosed) { _, _ in
                            model.invalidateSimulation()
                            model.isModified = true
                        }
                case .capacitor:
                    numericField(title: "Capacitance (F)", value: $comp.capacitance, step: 1e-6)
                    numericField(title: "Time step dt (s)", value: $comp.capacitorDt, step: 0.001)
                case .coil:
                    numericField(title: "Inductance (H)", value: $comp.inductance, step: 1e-3)
                    numericField(title: "Time step dt (s)", value: $comp.coilDt, step: 0.001)
                case .diode:
                    numericField(title: "Saturation Current Is (A)", value: $comp.diodeIs, step: 1e-12)
                    numericField(title: "Ideality Factor n", value: $comp.diodeN, step: 0.1)
                    numericField(title: "Thermal Voltage VT (V)", value: $comp.diodeVt, step: 0.001)
                case .transistor:
                    numericField(title: "Saturation Current Is (A)", value: $comp.transistorIs, step: 1e-14)
                    numericField(title: "Forward Beta (Beta_F)", value: $comp.transistorBetaF, step: 10.0)
                    numericField(title: "Reverse Beta (Beta_R)", value: $comp.transistorBetaR, step: 1.0)
                    numericField(title: "Thermal Voltage VT (V)", value: $comp.transistorVt, step: 0.001)
                case .ground:
                    Text("Ground reference plane (0.0 V)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Delete button
            Button(role: .destructive) {
                model.removeComponent(id: comp.id)
            } label: {
                Label("Delete Component", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func numericField(title: String, value: Binding<Double>, step: Double = 1.0) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: value.wrappedValue) { _, _ in
                    model.invalidateSimulation()
                    model.isModified = true
                }
        }
    }
}

// MARK: - Wire Detail View
struct WireDetailView: View {
    @ObservedObject var wire: CircuitWire
    @ObservedObject var model: CircuitModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.title2)
                    .foregroundColor(.green)
                    .frame(width: 32, height: 32)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wire Connection")
                        .font(.headline)
                    Text("ID: #\(wire.id)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Connection Endpoints")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("From:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Comp #\(wire.fromComp), Pin \(wire.fromPin)")
                        .font(.caption)
                        .monospaced()
                }
                HStack {
                    Text("To:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Comp #\(wire.toComp), Pin \(wire.toPin)")
                        .font(.caption)
                        .monospaced()
                }
            }
            
            Divider()
            
            Toggle("Flipped Manhattan Route", isOn: $wire.isFlipped)
                .onChange(of: wire.isFlipped) { _, _ in
                    model.invalidateSimulation()
                    model.isModified = true
                }
            
            Divider()
            
            Button(role: .destructive) {
                model.removeWire(id: wire.id)
            } label: {
                Label("Delete Wire", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Circuit Overview Inspector
struct CircuitOverviewInspector: View {
    @ObservedObject var model: CircuitModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Circuit Overview", systemImage: "info.circle")
                .font(.headline)
            
            VStack(spacing: 8) {
                statRow(title: "Components", value: "\(model.components.count)")
                statRow(title: "Interconnections", value: "\(model.wires.count)")
                statRow(title: "Document", value: model.documentTitle)
            }
            .padding(10)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            
            Text("Tip: Click a component or wire to inspect its parameters. Drag pins to route wires. Press R to rotate.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Simulation Results Section
struct SimulationResultsSection: View {
    @ObservedObject var model: CircuitModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Operating Point", systemImage: "bolt.badge.clock")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2f ms", model.simulationResult.solveTimeMs))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            
            if !model.simulationResult.netVoltages.isEmpty {
                Text("Node Voltages")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                ForEach(model.simulationResult.netVoltages.sorted(by: { $0.key < $1.key }), id: \.key) { net, v in
                    HStack {
                        Text(net == "0" ? "GND (0)" : net)
                            .font(.caption)
                            .monospaced()
                        Spacer()
                        Text(String(format: "%.3f V", v))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 2)
                }
            }
            
            if !model.simulationResult.componentCurrents.isEmpty {
                Text("Branch Currents")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                ForEach(model.simulationResult.componentCurrents.sorted(by: { $0.key < $1.key }), id: \.key) { label, i in
                    HStack {
                        Text(label)
                            .font(.caption)
                            .monospaced()
                        Spacer()
                        Text(formatCurrent(i))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private func formatCurrent(_ i: Double) -> String {
        if abs(i) < 1e-4 {
            return String(format: "%.3f µA", i * 1e6)
        } else if abs(i) < 1.0 {
            return String(format: "%.3f mA", i * 1e3)
        } else {
            return String(format: "%.3f A", i)
        }
    }
}
