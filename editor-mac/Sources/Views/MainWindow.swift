import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct MainWindow: View {
    @StateObject var model = CircuitModel()
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            CanvasView(model: model)
                .frame(minWidth: 500)
        }
        .toolbar(removing: .sidebarToggle)
        .navigationTitle(model.documentTitle + (model.isModified ? " — Edited" : ""))
        .navigationSubtitle("\(model.components.count) components, \(model.wires.count) wires • \(model.statusMessage)")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    openFileDialog()
                } label: {
                    Label("Load", systemImage: "folder")
                }
                .help("Load Circuit (.circ / .cir)")
                
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
        }
        .background {
            // Window-wide keyboard shortcut handlers
            Group {
                Button("") { openFileDialog() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("") { saveFileDialog() }
                    .keyboardShortcut("s", modifiers: [.command])
                Button("") { model.removeSelected() }
                    .keyboardShortcut(.delete, modifiers: [])
                Button("") { model.removeSelected() }
                    .keyboardShortcut(.deleteForward, modifiers: [])
                Button("") { model.rotateSelected() }
                    .keyboardShortcut("r", modifiers: [.command])
                Button("") { model.duplicateSelected() }
                    .keyboardShortcut("d", modifiers: [.command])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
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
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Load Circuit Schematic"
        panel.prompt = "Load"
        panel.allowsOtherFileTypes = true
        
        var types: [UTType] = [.plainText, .data]
        if let circType = UTType(filenameExtension: "circ") {
            types.append(circType)
        }
        if let cirType = UTType(filenameExtension: "cir") {
            types.append(cirType)
        }
        panel.allowedContentTypes = types
        
        let targetWindow = NSApp.keyWindow ?? NSApp.mainWindow
        if let window = targetWindow {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url {
                    _ = model.load(from: url)
                }
            }
        } else {
            if panel.runModal() == .OK, let url = panel.url {
                _ = model.load(from: url)
            }
        }
    }
    
    private func saveFileDialog() {
        let panel = NSSavePanel()
        panel.title = "Save Circuit Schematic"
        panel.prompt = "Save"
        panel.nameFieldStringValue = model.documentTitle.hasSuffix(".circ") ? model.documentTitle : "\(model.documentTitle).circ"
        panel.allowsOtherFileTypes = true
        
        var types: [UTType] = [.plainText, .data]
        if let circType = UTType(filenameExtension: "circ") {
            types.insert(circType, at: 0)
        }
        panel.allowedContentTypes = types
        
        let targetWindow = NSApp.keyWindow ?? NSApp.mainWindow
        if let window = targetWindow {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url {
                    _ = model.save(to: url)
                }
            }
        } else {
            if panel.runModal() == .OK, let url = panel.url {
                _ = model.save(to: url)
            }
        }
    }
}
