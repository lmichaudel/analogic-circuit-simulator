#include "../solver/circuit.hpp"
#include "../solver/component.hpp"
#include "../solver/solver.hpp"

#include <iostream>
#include <chrono>
#include <functional>
#include <cmath>
#include <iomanip>

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

// -- Benchmark ----------------------------------------------------------------

struct Result {
    std::string circuit;
    std::string solver_name;
    int    iterations;
    double time_us;
    double final_error;
    bool   converged;
};

static double compute_error(solver::Circuit& circuit) {
    double E = 0.0;
    for (auto& w : circuit.free_wires()) {
        double e = circuit.kcl_error(w);
        E += e * e;
    }
    return E;
}

static Result bench(const std::string& cname, Builder build,
                    const std::string& sname, solver::Solver& s,
                    double epsilon = 1e-8) {
    solver::Circuit circuit;
    build(circuit);
    s.set_recording(true);

    auto t0 = std::chrono::high_resolution_clock::now();
    circuit.solve(s);
    auto t1 = std::chrono::high_resolution_clock::now();

    double time_us = std::chrono::duration<double, std::micro>(t1 - t0).count();
    double error   = compute_error(circuit);

    return { cname, sname, s.get_iter_count(), time_us, error, error < epsilon };
}

static void write_convergence(const std::string& cname, const std::string& sname,
                               const std::vector<solver::IterStep>& hist) {
    if (hist.empty()) return;
    int n = static_cast<int>(hist[0].potentials.size());
    std::cout << "---BEGIN " << cname << "_" << sname << "\n";
    std::cout << "step";
    for (int j = 0; j < n; ++j) std::cout << ",V" << j;
    std::cout << ",error\n";
    for (int i = 0; i < (int)hist.size(); ++i) {
        std::cout << i;
        for (double v : hist[i].potentials) std::cout << "," << v;
        std::cout << "," << hist[i].error << "\n";
    }
    std::cout << "---END\n";
}

int main() {
    struct Case { std::string name; Builder build; };
    std::vector<Case> cases = {
        { "chained",       build_chained       },
        { "chained3",      build_chained3      },
        { "wheatstone",    build_wheatstone    },
        { "diode_forward", build_diode_forward },
        { "diode_clamp",   build_diode_clamp   },
        { "bjt",           build_bjt           },
    };

    std::vector<Result> results;

    for (auto& cas : cases) {
        double v0 = (cas.name == "bjt") ? 0.5 : 0.0;

        { solver::NewtonRaphson s;
          auto r = bench(cas.name, cas.build, "newton", s);
          results.push_back(r);
          write_convergence(cas.name, "newton", s.get_history()); }

        { solver::SimpleResolver s;
          auto r = bench(cas.name, cas.build, "simple", s);
          results.push_back(r);
          write_convergence(cas.name, "simple", s.get_history()); }

        { solver::GradientDescent s(10.0, 1e-8, 100000, v0);
          auto r = bench(cas.name, cas.build, "gradient", s);
          results.push_back(r);
          write_convergence(cas.name, "gradient", s.get_history()); }

        { solver::NumericalGradientDescent s(10.0, 1e-8, 100000, 1e-6, v0);
          auto r = bench(cas.name, cas.build, "numerical", s);
          results.push_back(r);
          write_convergence(cas.name, "numerical", s.get_history()); }

        std::cerr << "  " << cas.name << " OK\n";
    }

    // métriques
    std::cout << "---BEGIN metrics\n";
    std::cout << "circuit,solver,iterations,time_us,final_error,converged\n";
    for (auto& r : results) {
        std::cout << r.circuit << ","
                  << r.solver_name << ","
                  << r.iterations << ","
                  << r.time_us << ","
                  << r.final_error << ","
                  << (r.converged ? "true" : "false") << "\n";
    }
    std::cout << "---END\n";

    // tableau récapitulatif sur stderr
    std::cerr << std::left;
    std::cerr << "circuit          solver      iter     time(us)   error        conv\n";
    std::cerr << std::string(72, '-') << "\n";
    for (auto& r : results) {
        std::cerr << std::setw(17) << r.circuit
                  << std::setw(12) << r.solver_name
                  << std::setw(9)  << r.iterations
                  << std::setw(11) << (int)r.time_us
                  << std::setw(13) << r.final_error
                  << (r.converged ? "oui" : "non") << "\n";
    }

    return 0;
}
