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
}
