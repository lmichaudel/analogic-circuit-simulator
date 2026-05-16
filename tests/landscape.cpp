#include "../solver/circuit.hpp"
#include "../solver/component.hpp"
#include "../solver/solver.hpp"

#include <iostream>
#include <functional>
#include <cmath>

using Builder = std::function<void(solver::Circuit&)>;

// -- Circuits -----------------------------------------------------------------

static void build_chained(solver::Circuit& c) {
    auto vs = c.add_component<solver::VoltageSource>(5.0);
    auto r1 = c.add_component<solver::Resistor>(1.0, "r1");
    auto r2 = c.add_component<solver::Resistor>(1.0, "r2");
    c.add_wire({&vs->get_pin(0), &r1->get_pin(0)}, "w1");
    c.add_wire({&r1->get_pin(1), &r2->get_pin(0)}, "w2");
    c.add_wire({&vs->get_pin(1), &r2->get_pin(1)}, "w3");
}

static void build_chained3(solver::Circuit& c) {
    auto vs = c.add_component<solver::VoltageSource>(5.0);
    auto r1 = c.add_component<solver::Resistor>(1.0, "r1");
    auto r2 = c.add_component<solver::Resistor>(1.0, "r2");
    auto r3 = c.add_component<solver::Resistor>(1.0, "r3");
    c.add_wire({&vs->get_pin(0), &r1->get_pin(0)}, "w1");
    c.add_wire({&r1->get_pin(1), &r2->get_pin(0)}, "w2");
    c.add_wire({&r2->get_pin(1), &r3->get_pin(0)}, "w3");
    c.add_wire({&vs->get_pin(1), &r3->get_pin(1)}, "w4");
}

static void build_diode_forward(solver::Circuit& c) {
    auto vs = c.add_component<solver::VoltageSource>(1.0);
    auto r  = c.add_component<solver::Resistor>(1000.0, "r");
    auto d  = c.add_component<solver::Diode>(1e-12, 1.0, 0.02585, "d");
    c.add_wire({&vs->get_pin(0), &r->get_pin(0)}, "w1");
    c.add_wire({&r->get_pin(1),  &d->get_pin(0)}, "w2");
    c.add_wire({&d->get_pin(1),  &vs->get_pin(1)}, "w3");
}

static void build_diode_clamp(solver::Circuit& c) {
    auto vs = c.add_component<solver::VoltageSource>(5.0);
    auto r  = c.add_component<solver::Resistor>(100.0, "r");
    auto d  = c.add_component<solver::Diode>(1e-12, 1.0, 0.02585, "d");
    c.add_wire({&vs->get_pin(0), &r->get_pin(0)}, "w1");
    c.add_wire({&r->get_pin(1),  &d->get_pin(0)}, "w2");
    c.add_wire({&d->get_pin(1),  &vs->get_pin(1)}, "w3");
}

static void build_wheatstone(solver::Circuit& c) {
    auto vs = c.add_component<solver::VoltageSource>(5.0);
    auto r1 = c.add_component<solver::Resistor>(10.0, "r1");
    auto r2 = c.add_component<solver::Resistor>(10.0, "r2");
    auto r3 = c.add_component<solver::Resistor>(10.0, "r3");
    auto r4 = c.add_component<solver::Resistor>(10.0, "r4");
    auto rb = c.add_component<solver::Resistor>(10.0, "rb");
    c.add_wire({&vs->get_pin(0), &r1->get_pin(0), &r3->get_pin(0)}, "A");
    c.add_wire({&r1->get_pin(1), &r2->get_pin(0), &rb->get_pin(0)}, "B");
    c.add_wire({&vs->get_pin(1), &r2->get_pin(1), &r4->get_pin(1)}, "C");
    c.add_wire({&r3->get_pin(1), &r4->get_pin(0), &rb->get_pin(1)}, "D");
}

static void build_bjt(solver::Circuit& c) {
    auto vcc = c.add_component<solver::VoltageSource>(5.0, "vcc");
    auto r_b = c.add_component<solver::Resistor>(470e3, "r_b");
    auto r_c = c.add_component<solver::Resistor>(1000.0, "r_c");
    auto bjt = c.add_component<solver::Transistor>(1e-14, 100.0, 5.0, 0.02585, "bjt");
    c.add_wire({&vcc->get_pin(0), &r_b->get_pin(0), &r_c->get_pin(0)}, "w_vcc");
    c.add_wire({&r_b->get_pin(1), &bjt->get_pin(0)},                   "w_base");
    c.add_wire({&r_c->get_pin(1), &bjt->get_pin(1)},                   "w_collector");
    c.add_wire({&vcc->get_pin(1), &bjt->get_pin(2)},                   "w_gnd");
}

// -- Calcul du paysage d'erreur -----------------------------------------------

static double erreur(solver::Circuit& circuit,
                     const std::vector<std::shared_ptr<solver::Wire>>& fils) {
    double E = 0.0;
    circuit.compute_currents();
    for (auto& w : fils) { double e = circuit.kcl_error(w); E += e * e; }
    return E;
}

static void sweep_1d(const std::string& name, Builder build,
                     double v_min, double v_max, int n) {
    solver::Circuit ref; build(ref);
    solver::NewtonRaphson nr; nr.solve(ref);
    double v_sol = ref.free_wires()[0]->potential;

    solver::Circuit circuit; build(circuit);
    circuit.init_potentials();
    auto fils = circuit.free_wires();

    std::cout << "---BEGIN " << name << "_1d\n";
    std::cout << "V,E,V_sol\n";
    std::cout << ",,," << v_sol << "\n";
    for (int i = 0; i <= n; ++i) {
        double v = v_min + (v_max - v_min) * i / n;
        fils[0]->potential = v;
        std::cout << v << "," << erreur(circuit, fils) << "\n";
    }
    std::cout << "---END\n";
    std::cerr << "  1D " << name << "\n";
}

static void sweep_2d(const std::string& name, Builder build,
                     double v0_min, double v0_max,
                     double v1_min, double v1_max, int n) {
    solver::Circuit ref; build(ref);
    solver::NewtonRaphson nr; nr.solve(ref);
    auto ref_fils = ref.free_wires();
    double v0_sol = ref_fils[0]->potential;
    double v1_sol = ref_fils[1]->potential;

    solver::Circuit circuit; build(circuit);
    circuit.init_potentials();
    auto fils = circuit.free_wires();

    std::cout << "---BEGIN " << name << "_2d\n";
    std::cout << "V0,V1,E,V0_sol,V1_sol\n";
    std::cout << ",,," << v0_sol << "," << v1_sol << "\n";
    for (int i = 0; i <= n; ++i) {
        double v0 = v0_min + (v0_max - v0_min) * i / n;
        for (int j = 0; j <= n; ++j) {
            double v1 = v1_min + (v1_max - v1_min) * j / n;
            fils[0]->potential = v0;
            fils[1]->potential = v1;
            std::cout << v0 << "," << v1 << "," << erreur(circuit, fils) << "\n";
        }
    }
    std::cout << "---END\n";
    std::cerr << "  2D " << name << "\n";
}

int main() {
    std::cerr << "Calcul des paysages d'erreur...\n";

    sweep_1d("chained",       build_chained,       -0.5, 5.5,  500);
    sweep_1d("diode_forward", build_diode_forward,  0.0, 1.0,  500);
    sweep_1d("diode_clamp",   build_diode_clamp,    0.0, 5.0,  500);

    sweep_2d("chained3",   build_chained3,   0.0, 5.0, 0.0, 5.0, 100);
    sweep_2d("wheatstone", build_wheatstone, 0.0, 5.0, 0.0, 5.0, 100);
    sweep_2d("bjt",        build_bjt,        0.0, 1.0, 0.0, 5.0, 100);

    std::cerr << "Termine.\n";
    return 0;
}
