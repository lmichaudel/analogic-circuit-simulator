import Foundation

public struct EmbeddedCircuitExample: Identifiable {
    public let id: String
    public let title: String
    public let icon: String
    public let content: String
    
    public init(id: String, title: String, icon: String, content: String) {
        self.id = id
        self.title = title
        self.icon = icon
        self.content = content
    }
}

public struct EmbeddedExamples {
    public static let all: [EmbeddedCircuitExample] = [
        EmbeddedCircuitExample(
            id: "bjt",
            title: "BJT Amplifier",
            icon: "waveform",
            content: """
            nextId 10
            COMP 1 Resistor 380 240 R1 0 1
            COMP 2 Resistor 560 120 R2 1 1
            COMP 3 Transistor 520 240 T 0 1e-14 100 5 0.02585
            COMP 5 Ground 560 340 G 0
            COMP 8 VSource 380 340 V 0 5
            WIRE 4 2 1 3 1 0
            WIRE 6 3 2 5 0 0
            WIRE 7 1 1 3 0 0
            WIRE 9 8 0 1 0 0
            """
        ),
        EmbeddedCircuitExample(
            id: "diode_clamp",
            title: "Diode Clamp",
            icon: "arrow.up.and.down.square",
            content: """
            nextId 11
            COMP 1 Resistor 400 120 R 0 1
            COMP 2 Diode 440 200 D1 1 1e-12 1 0.02585
            COMP 3 VSource 360 200 V 1 5
            COMP 8 Diode 520 200 D2 3 1e-12 1 0.02585
            WIRE 4 3 0 1 0 0
            WIRE 5 1 1 2 0 0
            WIRE 6 2 1 3 1 0
            WIRE 9 1 1 8 1 0
            WIRE 10 8 0 2 1 0
            """
        ),
        EmbeddedCircuitExample(
            id: "diode_forward",
            title: "Diode Forward",
            icon: "triangle",
            content: """
            nextId 7
            COMP 1 Resistor 400 120 R 0 1
            COMP 2 Diode 440 200 D 1 1e-12 1 0.02585
            COMP 3 VSource 360 200 V 1 5
            WIRE 4 3 0 1 0 0
            WIRE 5 1 1 2 0 0
            WIRE 6 2 1 3 1 0
            """
        ),
        EmbeddedCircuitExample(
            id: "diode_reversed",
            title: "Diode Reversed",
            icon: "triangle.fill",
            content: """
            nextId 10
            COMP 1 Resistor 400 120 R 0 1
            COMP 3 VSource 360 200 V 1 5
            COMP 7 Diode 440 200 D 3 1e-12 1 0.02585
            WIRE 4 3 0 1 0 0
            WIRE 8 7 0 3 1 0
            WIRE 9 7 1 1 1 0
            """
        ),
        EmbeddedCircuitExample(
            id: "wheatstone",
            title: "Wheatstone Bridge",
            icon: "rhombus",
            content: """
            nextId 12
            COMP 1 Resistor 340 160 R1 0 1
            COMP 2 Resistor 540 160 R2 0 1
            COMP 3 Resistor 320 80 R3 0 1
            COMP 4 Resistor 560 80 R4 0 1
            COMP 5 VSource 440 240 V5 0 5
            WIRE 6 1 1 2 0 0
            WIRE 7 4 0 3 1 0
            WIRE 8 3 0 1 0 1
            WIRE 9 1 0 5 0 1
            WIRE 10 5 1 2 1 0
            WIRE 11 2 1 4 1 0
            """
        ),
        EmbeddedCircuitExample(
            id: "r_serie",
            title: "Series Resistors",
            icon: "link",
            content: """
            nextId 7
            COMP 1 VSource 280 140 V 5 5
            COMP 2 Resistor 400 80 R1 0 1
            COMP 3 Resistor 520 140 R2 1 1
            WIRE 4 1 0 2 0 1
            WIRE 5 2 1 3 0 0
            WIRE 6 3 1 1 1 1
            """
        ),
        EmbeddedCircuitExample(
            id: "r_para",
            title: "Parallel Resistors",
            icon: "equal",
            content: """
            nextId 10
            COMP 1 VSource 280 140 V 5 5
            COMP 2 Resistor 400 140 R1 1 1
            COMP 3 Resistor 520 140 R2 1 1
            WIRE 4 1 0 2 0 1
            WIRE 7 2 0 3 0 0
            WIRE 8 3 1 2 1 0
            WIRE 9 2 1 1 1 0
            """
        ),
        EmbeddedCircuitExample(
            id: "and",
            title: "Logic AND Gate",
            icon: "square.split.diagonal.2x2",
            content: """
            nextId 27
            COMP 1 Resistor 480 160 R 0 10000
            COMP 2 Resistor 480 320 R 0 10000
            COMP 7 Transistor 640 320 T2 0 1e-14 100 5 0.02585
            COMP 8 Transistor 640 160 T1 0 1e-14 100 5 0.02585
            COMP 11 Resistor 680 460 R 1 4700
            COMP 17 Switch 780 360 OUT 0 1
            COMP 19 Ground 680 580 G 0
            COMP 21 VSource 320 160 A 2 6
            COMP 23 VSource 320 320 B 2 6
            COMP 25 VSource 740 80 Vcc 0 6
            WIRE 9 1 1 8 0 0
            WIRE 10 8 2 7 1 0
            WIRE 12 2 1 7 0 0
            WIRE 13 7 2 11 0 0
            WIRE 18 7 2 17 0 0
            WIRE 20 11 1 19 0 0
            WIRE 22 21 0 1 0 0
            WIRE 24 23 0 2 0 0
            WIRE 26 25 0 8 1 0
            """
        )
    ]
}
