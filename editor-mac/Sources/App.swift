import SwiftUI
import AppKit

@main
struct CircuitSimulatorApp: App {
    init() {
        // Configure standard macOS app appearance
        NSApplication.shared.setActivationPolicy(.regular)
    }
    
    var body: some Scene {
        WindowGroup {
            MainWindow()
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Circuit") {
                    NotificationCenter.default.post(name: .newCircuitAction, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            
            CommandMenu("Simulation") {
                Button("Run Simulation") {
                    NotificationCenter.default.post(name: .runSimulationAction, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let newCircuitAction = Notification.Name("newCircuitAction")
    static let runSimulationAction = Notification.Name("runSimulationAction")
}
