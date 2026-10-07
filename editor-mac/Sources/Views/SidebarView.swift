import Foundation
import SwiftUI
import AppKit

public struct SidebarView: View {
    @ObservedObject var model: CircuitModel
    
    public init(model: CircuitModel) {
        self.model = model
    }
    
    public var body: some View {
        List {
            // MARK: - Simulation Control
            Section("Simulation") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Solver", selection: $model.solverMethod) {
                        ForEach(SolverMethod.allCases) { method in
                            Text(method.name).tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text(model.solverMethod.shortDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button {
                        Task {
                            await runSimulation()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if model.isSimulating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(nsColor: .systemGreen))
                            }
                            Text(model.isSimulating ? "Solving..." : "Simulate")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(model.isSimulating)
                    .keyboardShortcut("b", modifiers: [.command])
                    
                    if model.simulationResult.isSimulated {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(model.simulationResult.success ? Color(nsColor: .systemGreen) : Color(nsColor: .systemRed))
                                    .frame(width: 7, height: 7)
                                Text(model.simulationResult.success ? "Converged" : "Failed")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(String(format: "%.2f ms", model.simulationResult.solveTimeMs))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            
                            if let err = model.simulationResult.errorMessage {
                                Text(err)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .cornerRadius(6)
                    }
                }
                .padding(.vertical, 2)
            }
            
            // MARK: - Component Library
            Section("Components") {
                ForEach(ComponentType.allCases) { compType in
                    Button {
                        model.addComponent(type: compType)
                    } label: {
                        HStack(spacing: 10) {
                            ComponentIconView(type: compType, color: .accentColor, size: 18)
                            Text(compType.displayName)
                                .font(.system(size: 13, weight: .regular))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2.5)
                }
            }
            
            // MARK: - Examples
            Section("Examples") {
                ForEach(EmbeddedExamples.all) { example in
                    Button {
                        _ = model.load(from: example.content, title: example.title)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: example.icon)
                                .font(.system(size: 14))
                                .frame(width: 18)
                                .foregroundColor(.secondary)
                            Text(example.title)
                                .font(.system(size: 13, weight: .regular))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2.5)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220, idealWidth: 240)
    }
    
    private func runSimulation() async {
        model.isSimulating = true
        let content = model.serialize()
        let result = await SimulationService.simulate(circuitText: content, method: model.solverMethod)
        model.simulationResult = result
        model.isSimulating = false
        if result.success {
            model.statusMessage = String(format: "Simulation completed in %.3f ms", result.solveTimeMs)
        } else {
            model.statusMessage = "Simulation failed: \(result.errorMessage ?? "Non-convergence")"
        }
    }
}
