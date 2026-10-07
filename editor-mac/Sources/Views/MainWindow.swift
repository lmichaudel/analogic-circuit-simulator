import Foundation
import SwiftUI
import AppKit

public struct MainWindow: View {
    @StateObject var model = CircuitModel()
    @State private var showInspector: Bool = true
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            CanvasView(model: model)
                .frame(minWidth: 500)
                .inspector(isPresented: $showInspector) {
                    InspectorView(model: model)
                        .inspectorColumnWidth(min: 260, ideal: 280, max: 360)
                }
        }
        .navigationTitle(model.documentTitle + (model.isModified ? " — Edited" : ""))
        .navigationSubtitle("\(model.components.count) components, \(model.wires.count) wires • \(model.statusMessage)")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    openFileDialog()
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .help("Open Circuit (.circ / .cir)")
                
                Button {
                    saveFileDialog()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .help("Save Circuit (⌘S)")
                
                Divider()
                
                Button {
                    Task {
                        await runSimulation()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(nsColor: .systemGreen))
                        Text("Simulate")
                    }
                }
                .help("Run Circuit Simulation (⌘B)")
                .disabled(model.isSimulating)
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                // Edit Actions ControlGroup
                ControlGroup {
                    Button {
                        model.rotateSelected()
                    } label: {
                        Image(systemName: "rotate.right")
                    }
                    .disabled(model.selectedComponent == nil)
                    .help("Rotate 90° (⌘R)")
                    .keyboardShortcut("r", modifiers: [.command])
                    
                    Button {
                        model.duplicateSelected()
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .disabled(model.selectedComponent == nil)
                    .help("Duplicate (⌘D)")
                    .keyboardShortcut("d", modifiers: [.command])
                    
                    Button(role: .destructive) {
                        model.removeSelected()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(model.selectedComponent == nil && model.selectedWire == nil)
                    .help("Delete Selected (⌫)")
                }
                
                // Zoom ControlGroup
                ControlGroup {
                    Button {
                        model.zoomScale = max(0.25, model.zoomScale - 0.15)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .help("Zoom Out (⌘-)")
                    .keyboardShortcut("-", modifiers: [.command])
                    
                    Button {
                        model.zoomScale = 1.0
                        model.panOffset = .zero
                    } label: {
                        Text("\(Int(round(model.zoomScale * 100)))%")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .help("Reset Zoom to 100% (⌘0)")
                    .keyboardShortcut("0", modifiers: [.command])
                    
                    Button {
                        model.zoomScale = min(4.0, model.zoomScale + 0.15)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .help("Zoom In (⌘+)")
                    .keyboardShortcut("+", modifiers: [.command])
                }
                
                // Toggle Inspector Button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInspector.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help("Toggle Inspector Panel (⌥⌘I)")
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }
    }
    
    // MARK: - Simulation Helper
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
    
    // MARK: - Native File Dialogs
    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Open Circuit Schematic"
        
        if panel.runModal() == .OK, let url = panel.url {
            _ = model.load(from: url)
        }
    }
    
    private func saveFileDialog() {
        if let existing = model.currentFileURL {
            _ = model.save(to: existing)
            return
        }
        
        let panel = NSSavePanel()
        panel.title = "Save Circuit Schematic"
        panel.nameFieldStringValue = model.documentTitle.hasSuffix(".circ") ? model.documentTitle : "\(model.documentTitle).circ"
        
        if panel.runModal() == .OK, let url = panel.url {
            _ = model.save(to: url)
        }
    }
}
