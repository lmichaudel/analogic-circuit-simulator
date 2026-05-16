#include "../solver/circuit.hpp"
#include "../solver/component.hpp"
#include "../solver/solver.hpp"

#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#include <memory>
#include <filesystem>

static std::string g_method;
static bool g_record = false;

static std::unique_ptr<solver::Solver> make_solver(const std::string& method) {
    if (method == "gradient")  return std::make_unique<solver::GradientDescent>();
    if (method == "numerical") return std::make_unique<solver::NumericalGradientDescent>();
    if (method == "simple")    return std::make_unique<solver::SimpleResolver>();
    return std::make_unique<solver::NewtonRaphson>();
}

static std::unique_ptr<solver::Solver> make_bjt_solver(const std::string& method) {
    // V_init=0.5 necessaire : avec V_BE=0 le transistor ne conduit pas,
    // le gradient est nul et le solver ne peut pas demarrer.
    if (method == "gradient")  return std::make_unique<solver::GradientDescent>(10.0, 1e-8, 100000, 0.5);
    if (method == "numerical") return std::make_unique<solver::NumericalGradientDescent>(10.0, 1e-8, 100000, 1e-6, 0.5);
    if (method == "simple")    return std::make_unique<solver::SimpleResolver>();
    return std::make_unique<solver::NewtonRaphson>();
}

static void write_csv(const std::string& name, solver::Solver& s,
                      const std::vector<std::string>& labels) {
    const auto& hist = s.get_history();
    if (hist.empty()) return;
    std::ofstream f("convergence/" + name + "_" + g_method + ".csv");
    f << "step";
    for (auto& l : labels) f << "," << l;
    f << ",error\n";
    for (int i = 0; i < (int)hist.size(); ++i) {
        f << i;
        for (double v : hist[i].potentials) f << "," << v;
        f << "," << hist[i].error << "\n";
    }
}

void simple(solver::Solver& s) {
    solver::Circuit circuit{};
    auto vs = circuit.add_component<solver::VoltageSource>(5.0);
    auto r  = circuit.add_component<solver::Resistor>(1.0, "r");
    circuit.add_wire({&vs->get_pin(0), &r->get_pin(0)}, "w1");
    circuit.add_wire({&r->get_pin(1),  &vs->get_pin(1)}, "w2");
    s.set_recording(g_record);
    circuit.solve(s);
    write_csv("simple", s, {"w2"});
    circuit.debug();
}

void chained_resistor(solver::Solver& s) {
    solver::Circuit circuit{};
    auto vs = circuit.add_component<solver::VoltageSource>(5.0);
    auto r1 = circuit.add_component<solver::Resistor>(1.0, "r1");
    auto r2 = circuit.add_component<solver::Resistor>(1.0, "r2");
    circuit.add_wire({&vs->get_pin(0), &r1->get_pin(0)}, "w1");
    circuit.add_wire({&r1->get_pin(1), &r2->get_pin(0)}, "w2");
    circuit.add_wire({&vs->get_pin(1), &r2->get_pin(1)}, "w3");
    s.set_recording(g_record);
    circuit.solve(s);
    write_csv("chained", s, {"w2"});
    circuit.debug();
}

void parallel_resistor(solver::Solver& s) {
    solver::Circuit circuit{};
    auto vs = circuit.add_component<solver::VoltageSource>(5.0);
    auto r1 = circuit.add_component<solver::Resistor>(1.0, "r1");
    auto r2 = circuit.add_component<solver::Resistor>(1.0, "r2");
    circuit.add_wire({&vs->get_pin(0), &r1->get_pin(0), &r2->get_pin(0)}, "w1");
    circuit.add_wire({&vs->get_pin(1), &r1->get_pin(1), &r2->get_pin(1)}, "w2");
    circuit.solve(s);
    circuit.debug();
}

void wheatstone_bridge(solver::Solver& s) {
    solver::Circuit circuit{};
    auto vs = circuit.add_component<solver::VoltageSource>(5.0);
    auto r1 = circuit.add_component<solver::Resistor>(10.0, "r1");
    auto r2 = circuit.add_component<solver::Resistor>(10.0, "r2");
    auto r3 = circuit.add_component<solver::Resistor>(10.0, "r3");
    auto r4 = circuit.add_component<solver::Resistor>(10.0, "r4");
    auto rb = circuit.add_component<solver::Resistor>(10.0, "rb");
    circuit.add_wire({&vs->get_pin(0), &r1->get_pin(0), &r3->get_pin(0)}, "A");
    circuit.add_wire({&r1->get_pin(1), &r2->get_pin(0), &rb->get_pin(0)}, "B");
    circuit.add_wire({&vs->get_pin(1), &r2->get_pin(1), &r4->get_pin(1)}, "C");
    circuit.add_wire({&r3->get_pin(1), &r4->get_pin(0), &rb->get_pin(1)}, "D");
    s.set_recording(g_record);
    circuit.solve(s);
    write_csv("wheatstone", s, {"B", "D"});
    circuit.debug();
}

void diode_forward(solver::Solver& s) {
    solver::Circuit circuit{};
    auto vs = circuit.add_component<solver::VoltageSource>(1.0);
    auto r  = circuit.add_component<solver::Resistor>(1000.0, "r");
    auto d  = circuit.add_component<solver::Diode>(1e-12, 1.0, 0.02585, "d");
    circuit.add_wire({&vs->get_pin(0), &r->get_pin(0)}, "w1");
    circuit.add_wire({&r->get_pin(1),  &d->get_pin(0)}, "w2");
    circuit.add_wire({&d->get_pin(1),  &vs->get_pin(1)}, "w3");
    s.set_recording(g_record);
    circuit.solve(s);
    write_csv("diode_forward", s, {"w2"});
    circuit.debug();
}

void diode_reverse(solver::Solver& s) {
    solver::Circuit circuit{};
    auto vs = circuit.add_component<solver::VoltageSource>(1.0);
    auto r  = circuit.add_component<solver::Resistor>(1000.0, "r");
    auto d  = circuit.add_component<solver::Diode>(1e-12, 1.0, 0.02585, "d");
    circuit.add_wire({&vs->get_pin(0), &d->get_pin(1)}, "w1");
    circuit.add_wire({&d->get_pin(0),  &r->get_pin(0)}, "w2");
    circuit.add_wire({&r->get_pin(1),  &vs->get_pin(1)}, "w3");
    s.set_recording(g_record);
    circuit.solve(s);
    write_csv("diode_reverse", s, {"w2"});
    circuit.debug();
}

void diode_clamp(solver::Solver& s) {
    solver::Circuit circuit{};
    auto vs = circuit.add_component<solver::VoltageSource>(5.0);
    auto r  = circuit.add_component<solver::Resistor>(100.0, "r");
    auto d  = circuit.add_component<solver::Diode>(1e-12, 1.0, 0.02585, "d");
    circuit.add_wire({&vs->get_pin(0), &r->get_pin(0)}, "w1");
    circuit.add_wire({&r->get_pin(1),  &d->get_pin(0)}, "w2");
    circuit.add_wire({&d->get_pin(1),  &vs->get_pin(1)}, "w3");
    s.set_recording(g_record);
    circuit.solve(s);
    write_csv("diode_clamp", s, {"w2"});
    circuit.debug();
}

void bjt_common_emitter(solver::Solver& s) {
    solver::Circuit circuit;
    auto vcc = circuit.add_component<solver::VoltageSource>(5.0, "vcc");
    auto r_b = circuit.add_component<solver::Resistor>(470e3, "r_b");
    auto r_c = circuit.add_component<solver::Resistor>(1000.0, "r_c");
    auto bjt = circuit.add_component<solver::Transistor>(1e-14, 100.0, 5.0, 0.02585, "bjt");
    circuit.add_wire({&vcc->get_pin(0), &r_b->get_pin(0), &r_c->get_pin(0)}, "w_vcc");
    circuit.add_wire({&r_b->get_pin(1), &bjt->get_pin(0)},                   "w_base");
    circuit.add_wire({&r_c->get_pin(1), &bjt->get_pin(1)},                   "w_collector");
    circuit.add_wire({&vcc->get_pin(1), &bjt->get_pin(2)},                   "w_gnd");
    s.set_recording(g_record);
    circuit.solve(s);
    write_csv("bjt", s, {"w_base", "w_collector"});
    circuit.debug();
}

void rc_circuit(solver::Solver& s) {
    const double dt = 0.005;
    solver::Circuit circuit;
    auto vs = circuit.add_component<solver::VoltageSource>(5.0, "vs");
    auto r  = circuit.add_component<solver::Resistor>(1000.0, "r");
    auto c  = circuit.add_component<solver::Capacitor>(100e-6, dt, "c");
    circuit.add_wire({&vs->get_pin(0), &r->get_pin(0)}, "w_source");
    circuit.add_wire({&r->get_pin(1),  &c->get_pin(0)}, "w_mid");
    circuit.add_wire({&vs->get_pin(1), &c->get_pin(1)}, "w_gnd");

    auto history = circuit.simulate(100, dt, s);

    std::cout << std::fixed << std::setprecision(4);
    std::cout << "  t(s)    V_mid(V)   I_r(A)" << std::endl;
    for (auto& snap : history) {
        double v_mid = 0.0, i_r = 0.0;
        for (auto& [label, v] : snap.voltages)
            if (label == "w_mid") v_mid = v;
        for (auto& [label, i] : snap.currents)
            if (label == "r") i_r = i;
        std::cout << "  " << snap.time
                  << "   " << v_mid
                  << "   " << i_r << std::endl;
    }
}

int main(int argc, char* argv[]) {
    g_method = "newton";
    if (argc >= 2) g_method = argv[1];

    if (g_method != "newton" && g_method != "gradient" &&
        g_method != "numerical" && g_method != "simple") {
        std::cerr << "Usage: " << argv[0]
                  << " [newton|gradient|numerical|simple]" << std::endl;
        return 1;
    }

    g_record = (g_method == "gradient" || g_method == "numerical");
    if (g_record) std::filesystem::create_directories("convergence");

    std::cout << "Solver: " << g_method << std::endl << std::endl;

    auto s     = make_solver(g_method);
    auto s_bjt = make_bjt_solver(g_method);

    std::cout << "--- Simple Resistor    ---" << std::endl; simple(*s);
    std::cout << "--- Chained Resistors  ---" << std::endl; chained_resistor(*s);
    std::cout << "--- Parallel Resistors ---" << std::endl; parallel_resistor(*s);
    std::cout << "--- Wheatstone Bridge  ---" << std::endl; wheatstone_bridge(*s);
    std::cout << "--- Diode Forward      ---" << std::endl; diode_forward(*s);
    std::cout << "--- Diode Reverse      ---" << std::endl; diode_reverse(*s);
    std::cout << "--- Diode Clamp        ---" << std::endl; diode_clamp(*s);
    std::cout << "--- Transistor Common-Emitter ---" << std::endl; bjt_common_emitter(*s_bjt);
    std::cout << "--- RC Circuit (temporal) ---" << std::endl; rc_circuit(*s);

    return 0;
}
