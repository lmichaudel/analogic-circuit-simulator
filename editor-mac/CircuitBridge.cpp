#include "CircuitBridge.h"
#include "../solver/circuit.hpp"
#include "../solver/component.hpp"
#include "../solver/solver.hpp"

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

struct WireDesc {
    int id;
    int fromComp;
    int fromPin;
    int toComp;
    int toPin;
    bool flipped;
};

static SimulationResultC* run_simulation(
    const std::vector<std::shared_ptr<solver::Component>>& comps,
    const std::vector<WireDesc>& wires,
    int solver_method
) {
    SimulationResultC* res = (SimulationResultC*)calloc(1, sizeof(SimulationResultC));
    if (!res) return nullptr;

    try {
        solver::Circuit circuit;

        for (auto& c : comps) {
            c->reset_state();
            c->set_dt(0.005);
            if (c->get_type_name() != "Ground") {
                circuit.add_component(c);
            }
        }

        std::map<int, int> parent;
        auto find = [&](int x) {
            int curr = x;
            while (parent.count(curr) && parent[curr] != curr) curr = parent[curr];
            if (!parent.count(curr)) parent[curr] = curr;
            int root = curr;
            curr = x;
            while (parent.count(curr) && parent[curr] != curr) {
                int nxt = parent[curr];
                parent[curr] = root;
                curr = nxt;
            }
            return root;
        };
        auto merge = [&](int a, int b) { parent[find(a)] = find(b); };

        for (auto& c : comps) {
            for (std::size_t i = 0; i < c->pin_count(); i++) {
                find(c->id * 10 + (int)i);
            }
        }

        for (auto& w : wires) {
            merge(w.fromComp * 10 + w.fromPin, w.toComp * 10 + w.toPin);
        }

        std::map<int, std::vector<int>> nets;
        for (auto& c : comps) {
            for (std::size_t i = 0; i < c->pin_count(); i++) {
                nets[find(c->id * 10 + (int)i)].push_back(c->id * 10 + (int)i);
            }
        }

        int netIdx = 1;
        std::map<int, std::string> pin_net_names;

        for (auto& net : nets) {
            bool isGnd = false;
            std::vector<solver::Pin*> dpins;
            for (int p : net.second) {
                int cid = p / 10;
                int pidx = p % 10;
                auto it = std::find_if(comps.begin(), comps.end(),
                                       [&](const std::shared_ptr<solver::Component>& x) { return x->id == cid; });
                if (it != comps.end()) {
                    if ((*it)->get_type_name() == "Ground") {
                        isGnd = true;
                    } else {
                        dpins.push_back(&((*it)->get_pin(pidx)));
                    }
                }
            }
            if (!dpins.empty()) {
                std::string nname = isGnd ? "0" : "n" + std::to_string(netIdx++);
                circuit.add_wire(dpins, nname);
                for (int p : net.second) {
                    pin_net_names[p] = nname;
                }
            }
        }

        std::unique_ptr<solver::Solver> solver;
        switch (solver_method) {
            case 0:
                solver = std::make_unique<solver::SimpleResolver>();
                break;
            case 1:
                solver = std::make_unique<solver::NumericalGradientDescent>(10.0, 1e-8, 100000, 1e-6, 0.5);
                break;
            case 2:
                solver = std::make_unique<solver::GradientDescent>(10.0, 1e-8, 100000, 0.5);
                break;
            case 3:
            default:
                solver = std::make_unique<solver::NewtonRaphson>();
                break;
        }

        auto start_time = std::chrono::high_resolution_clock::now();
        circuit.solve(*solver);
        auto end_time = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double, std::milli> elapsed = end_time - start_time;

        solver::Snapshot snapshot = circuit.snapshot(0.0f);
        std::map<std::string, double> sim_v;
        std::map<std::string, double> sim_i;
        for (auto& [label, val] : snapshot.voltages) sim_v[label] = val;
        for (auto& [label, val] : snapshot.currents) sim_i[label] = val;

        res->success = 1;
        res->solve_time_ms = elapsed.count();
        res->error_message = nullptr;

        // Collect pin voltages
        std::vector<PinVoltageResult> pvr;
        for (auto& [pid, nname] : pin_net_names) {
            PinVoltageResult item;
            item.pin_id = pid;
            item.net_name = strdup(nname.c_str());
            item.voltage = sim_v.count(nname) ? sim_v[nname] : 0.0;
            pvr.push_back(item);
        }

        res->num_pin_voltages = (int)pvr.size();
        if (res->num_pin_voltages > 0) {
            res->pin_voltages = (PinVoltageResult*)malloc(sizeof(PinVoltageResult) * pvr.size());
            for (size_t i = 0; i < pvr.size(); ++i) {
                res->pin_voltages[i] = pvr[i];
            }
        }

        // Collect component currents
        std::vector<CompCurrentResult> ccr;
        for (auto& c : comps) {
            if (sim_i.count(c->label)) {
                CompCurrentResult item;
                item.comp_label = strdup(c->label.c_str());
                item.current = sim_i[c->label];
                ccr.push_back(item);
            }
        }

        res->num_comp_currents = (int)ccr.size();
        if (res->num_comp_currents > 0) {
            res->comp_currents = (CompCurrentResult*)malloc(sizeof(CompCurrentResult) * ccr.size());
            for (size_t i = 0; i < ccr.size(); ++i) {
                res->comp_currents[i] = ccr[i];
            }
        }

        return res;

    } catch (const std::exception& ex) {
        res->success = 0;
        res->error_message = strdup(ex.what());
        return res;
    } catch (...) {
        res->success = 0;
        res->error_message = strdup("Unknown error during simulation");
        return res;
    }
}

static SimulationResultC* parse_and_simulate(std::istream& is, int solver_method) {
    std::vector<std::shared_ptr<solver::Component>> comps;
    std::vector<WireDesc> wires;

    std::string line;
    while (std::getline(is, line)) {
        if (line.empty()) continue;
        std::istringstream ss(line);
        std::string tok;
        ss >> tok;
        if (tok == "COMP") {
            auto c = solver::Component::deserialize_line(line);
            if (c) comps.push_back(c);
        } else if (tok == "WIRE") {
            WireDesc w;
            int flip = 0;
            ss >> w.id >> w.fromComp >> w.fromPin >> w.toComp >> w.toPin >> flip;
            w.flipped = (flip != 0);
            wires.push_back(w);
        }
    }

    return run_simulation(comps, wires, solver_method);
}

SimulationResultC* simulate_circuit_str(const char* circuit_str, int solver_method) {
    if (!circuit_str) return nullptr;
    std::istringstream iss(circuit_str);
    return parse_and_simulate(iss, solver_method);
}

SimulationResultC* simulate_circuit_file(const char* file_path, int solver_method) {
    if (!file_path) return nullptr;
    std::ifstream ifs(file_path);
    if (!ifs) {
        SimulationResultC* res = (SimulationResultC*)calloc(1, sizeof(SimulationResultC));
        res->success = 0;
        res->error_message = strdup("Failed to open circuit file");
        return res;
    }
    return parse_and_simulate(ifs, solver_method);
}

void free_simulation_result(SimulationResultC* res) {
    if (!res) return;
    if (res->error_message) {
        free((void*)res->error_message);
    }
    if (res->pin_voltages) {
        for (int i = 0; i < res->num_pin_voltages; ++i) {
            if (res->pin_voltages[i].net_name) {
                free((void*)res->pin_voltages[i].net_name);
            }
        }
        free(res->pin_voltages);
    }
    if (res->comp_currents) {
        for (int i = 0; i < res->num_comp_currents; ++i) {
            if (res->comp_currents[i].comp_label) {
                free((void*)res->comp_currents[i].comp_label);
            }
        }
        free(res->comp_currents);
    }
    free(res);
}
