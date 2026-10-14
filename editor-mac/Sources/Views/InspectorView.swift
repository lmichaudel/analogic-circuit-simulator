import Foundation
import SwiftUI
import AppKit

// MARK: - Native macOS Behind-Window Material Blur
public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .sidebar
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    public init(material: NSVisualEffectView.Material = .sidebar, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

public struct InspectorView: View {
    @ObservedObject var model: CircuitModel
    
    public init(model: CircuitModel) {
        self.model = model
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Right panel header
                HStack(spacing: 8) {
                    Text("Inspector")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                }
                .padding(.bottom, 2)
                
                if let comp = model.selectedComponent {
                    inspectorSection(title: "Component Properties") {
                        ComponentDetailView(comp: comp, model: model)
                    }
                } else if let wire = model.selectedWire {
                    inspectorSection(title: "Wire Connection") {
                        WireDetailView(wire: wire, model: model)
                    }
                } else {
                    inspectorSection(title: "Circuit Overview") {
                        CircuitOverviewInspector(model: model)
                    }
                }
                
                if model.simulationResult.isSimulated {
                    inspectorSection(title: "Operating Point") {
                        SimulationResultsSection(model: model)
                    }
                }
            }
            .padding(14)
        }
        .scrollContentBackground(.hidden)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
        .frame(minWidth: 280, idealWidth: 300)
    }
    
    private func inspectorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.6)
            
            content()
        }
    }
}

// MARK: - Component Detail View
struct ComponentDetailView: View {
    @ObservedObject var comp: CircuitComponent
    @ObservedObject var model: CircuitModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ComponentIconView(type: comp.type, color: .accentColor, size: 24)
                    .frame(width: 34, height: 34)
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
                        model.objectWillChange.send()
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
                    .onChange(of: comp.rotation) { _, _ in
                        model.invalidateSimulation()
                        model.isModified = true
                        model.objectWillChange.send()
                    }
                    
                    Button {
                        model.rotateSelected()
                    } label: {
                        Image(systemName: "rotate.right")
                    }
                    .help("Rotate 90° Clockwise (⌘R / R)")
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
                            model.objectWillChange.send()
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
                Label("Delete Component (⌫)", systemImage: "trash")
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
                    model.objectWillChange.send()
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
                    model.objectWillChange.send()
                }
            
            Divider()
            
            Button(role: .destructive) {
                model.removeWire(id: wire.id)
            } label: {
                Label("Delete Wire (⌫)", systemImage: "trash")
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
            VStack(spacing: 8) {
                statRow(title: "Components", value: "\(model.components.count)")
                statRow(title: "Interconnections", value: "\(model.wires.count)")
                statRow(title: "Document", value: model.documentTitle)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            
            Text("Tip: Click a component or wire to inspect its parameters. Drag pins to route wires. Press R to rotate.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
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

// MARK: - Floating Component Inspector
public struct FloatingInspectorView: View {
    @ObservedObject var comp: CircuitComponent
    @ObservedObject var model: CircuitModel
    
    public init(comp: CircuitComponent, model: CircuitModel) {
        self.comp = comp
        self.model = model
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Icon + Title + Close Button
            HStack(spacing: 8) {
                ComponentIconView(type: comp.type, color: .accentColor, size: 20)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(comp.type.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    Text("Component #\(comp.id)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    model.selectedComponentId = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Deselect (ESC)")
            }
            
            Divider()
            
            // Identifier & Quick Action Buttons
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Label")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("", text: $comp.label)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(maxWidth: 80)
                        .onChange(of: comp.label) { _, _ in
                            model.invalidateSimulation()
                            model.isModified = true
                            model.objectWillChange.send()
                        }
                }
                
                Spacer()
                
                // Rotate Button
                Button {
                    model.rotateSelected()
                } label: {
                    Image(systemName: "rotate.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Rotate 90° (⌘R / R)")
                
                // Duplicate Button
                Button {
                    model.duplicateSelected()
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Duplicate (⌘D)")
                
                // Delete Button
                Button(role: .destructive) {
                    model.removeSelected()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Delete (⌫)")
            }
            
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
                        .font(.system(size: 12))
                        .onChange(of: comp.isClosed) { _, _ in
                            model.invalidateSimulation()
                            model.isModified = true
                            model.objectWillChange.send()
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
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            // Live Simulation Operating Point
            if model.simulationResult.isSimulated {
                let pinV = model.simulationResult.pinVoltages
                let currents = model.simulationResult.componentCurrents
                let hasCurrent = currents[comp.label] != nil
                let hasVoltage = comp.pinCount == 2 && pinV[comp.id * 10 + 0] != nil && pinV[comp.id * 10 + 1] != nil
                
                if hasCurrent || hasVoltage {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OPERATING POINT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        if let current = currents[comp.label] {
                            HStack {
                                Text("Current")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrent(current))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if comp.pinCount == 2,
                           let v0 = pinV[comp.id * 10 + 0],
                           let v1 = pinV[comp.id * 10 + 1] {
                            HStack {
                                Text("Voltage (ΔV)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatVoltage(abs(v0 - v1)))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(Color(nsColor: .systemGreen))
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 250)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 5)
    }
    
    private func numericField(title: String, value: Binding<Double>, step: Double = 1.0) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .onChange(of: value.wrappedValue) { _, _ in
                    model.invalidateSimulation()
                    model.isModified = true
                    model.objectWillChange.send()
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
}

// MARK: - Floating Wire Inspector
public struct FloatingWireInspector: View {
    @ObservedObject var wire: CircuitWire
    @ObservedObject var model: CircuitModel
    
    public init(wire: CircuitWire, model: CircuitModel) {
        self.wire = wire
        self.model = model
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Wire Connection")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Wire #\(wire.id)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    model.selectedWireId = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Deselect (ESC)")
            }
            
            Divider()
            
            HStack(spacing: 8) {
                Button {
                    model.flipSelectedWire()
                } label: {
                    Label("Invert Elbow (F)", systemImage: "arrow.triangle.swap")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(role: .destructive) {
                    model.removeSelected()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Delete Wire (⌫)")
            }
        }
        .padding(12)
        .frame(width: 250)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 5)
    }
}
