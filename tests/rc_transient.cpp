#include "../solver/circuit.hpp"
#include "../solver/component.hpp"
#include "../solver/solver.hpp"

#include <iostream>
#include <cmath>
#include <vector>

static constexpr double VS      = 5.0;
static constexpr double R       = 1000.0;    // 1 kΩ
static constexpr double C_VAL   = 1e-6;      // 1 µF
static constexpr double TAU     = R * C_VAL; // 1 ms
static constexpr double DT      = TAU / 100; // 10 µs
static constexpr int    N_STEPS = 500;       // 5τ

using namespace solver;

struct StepData { double v_mid; int iters; };

static std::vector<StepData> run_rc(Solver& s) {
    Circuit c;
    auto vs  = c.add_component<VoltageSource>(VS);
    auto r   = c.add_component<Resistor>(R,      "r");
    auto cap = c.add_component<Capacitor>(C_VAL, DT, "c");
    c.add_wire({&vs->get_pin(0), &r->get_pin(0)},   "w_vcc");
    c.add_wire({&r->get_pin(1),  &cap->get_pin(0)},  "w_mid");
    c.add_wire({&vs->get_pin(1), &cap->get_pin(1)},  "w_gnd");
    c.init_potentials(0.0);

    auto fils = c.free_wires();
    std::vector<StepData> out;
    out.reserve(N_STEPS);

    for (int i = 0; i < N_STEPS; ++i) {
        s.solve(c);
        double v = 0.0;
        for (auto& w : fils)
            if (w->label == "w_mid") { v = w->potential; break; }
        out.push_back({v, s.get_iter_count()});
        c.advance();
    }
    return out;
}

int main() {
    NewtonRaphson            nr;
    GradientDescent          gd;
    NumericalGradientDescent ngd;
    SimpleResolver           sr;

    std::cerr << "Simulation RC — " << N_STEPS << " pas de " << DT * 1e6 << " µs...\n";
    auto data_nr  = run_rc(nr);  std::cerr << "  Newton OK\n";
    auto data_gd  = run_rc(gd);  std::cerr << "  Gradient analytique OK\n";
    auto data_ngd = run_rc(ngd); std::cerr << "  Gradient numerique OK\n";
    auto data_sr  = run_rc(sr);  std::cerr << "  Simple OK\n";

    std::cout << "---BEGIN rc_transient\n";
    std::cout << "time_us,newton,gradient,numerical,simple,analytical,"
                 "iter_newton,iter_gradient,iter_numerical,iter_simple\n";
    for (int i = 0; i < N_STEPS; ++i) {
        double t    = (i + 1) * DT;
        double v_th = VS * (1.0 - std::exp(-t / TAU));
        std::cout << t * 1e6
                  << "," << data_nr [i].v_mid
                  << "," << data_gd [i].v_mid
                  << "," << data_ngd[i].v_mid
                  << "," << data_sr [i].v_mid
                  << "," << v_th
                  << "," << data_nr [i].iters
                  << "," << data_gd [i].iters
                  << "," << data_ngd[i].iters
                  << "," << data_sr [i].iters << "\n";
    }
    std::cout << "---END\n";

    return 0;
}
