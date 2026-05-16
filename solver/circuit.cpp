#include "circuit.hpp"
#include "solver.hpp"
#include <iostream>

using namespace solver;

bool Circuit::is_fixed(std::shared_ptr<Wire> wire) {
    for (Pin* pin : wire->connected_pins) {
        for (auto& vs : voltage_sources) {
            if (pin->owner == vs.get()) return true;
        }
    }
    return false;
}

void Circuit::init_potentials(double V_init) {
    for (auto& wire : wires)
        wire->potential = V_init;
    for (auto& vs : voltage_sources) {
        vs->get_pin(0).wire->potential = vs->get_voltage();
        vs->get_pin(1).wire->potential = 0.0;
    }
}

void Circuit::compute_currents() {
    for (auto& comp : components)
        comp->update();
}

double Circuit::kcl_error(std::shared_ptr<Wire> wire) {
    double sum = 0.0;
    for (Pin* pin : wire->connected_pins)
        sum += pin->current;
    return sum;
}

std::vector<std::shared_ptr<Wire>> Circuit::free_wires() {
    std::vector<std::shared_ptr<Wire>> result;
    for (auto& wire : wires)
        if (!is_fixed(wire)) result.push_back(wire);
    return result;
}

void Circuit::add_wire(std::initializer_list<Pin*> pins, std::string label) {
    auto wire = std::make_shared<Wire>(pins, 0.0, label);
    wires.emplace_back(wire);
    for (auto pin : pins)
        pin->wire = wire;
}

void Circuit::add_wire(const std::vector<Pin*>& pins, std::string label) {
    auto wire = std::make_shared<Wire>(pins, 0.0, label);
    wires.emplace_back(wire);
    for (auto pin : pins)
        pin->wire = wire;
}

void Circuit::solve() {
    NewtonRaphson newton;
    newton.solve(*this);
}

void Circuit::solve(Solver& solver) {
    solver.solve(*this);
}

void Circuit::advance() {
    for (auto& comp : components)
        comp->advance();
}

void Circuit::step(Solver& solver) {
    solver.solve(*this);
    advance();
}

Snapshot Circuit::snapshot(double t) {
    Snapshot s;
    s.time = t;
    for (auto& wire : wires)
        s.voltages.push_back({wire->label, wire->potential});
    for (auto& comp : components)
        s.currents.push_back({comp->label, std::abs(comp->get_pin(0).current)});
    return s;
}

std::vector<Snapshot> Circuit::simulate(int n_steps, double dt, Solver& solver) {
    std::vector<Snapshot> history;
    history.reserve(n_steps);
    for (int i = 0; i < n_steps; ++i) {
        solver.solve(*this);
        history.push_back(snapshot(i * dt));
        advance();
    }
    return history;
}

void Circuit::debug() {
    for (auto& wire : wires)
        std::cout << wire->label << ": " << wire->potential << " V" << std::endl;
    for (auto& comp : components) {
        if (comp->pin_count() == 2) {
            std::cout << comp->label << ": "
                      << std::abs(comp->get_pin(0).current) << " A" << std::endl;
        } else {
            for (std::size_t i = 0; i < comp->pin_count(); ++i)
                std::cout << comp->label << "[" << i << "]: "
                          << comp->get_pin(i).current << " A" << std::endl;
        }
    }
    std::cout << std::endl;
}
