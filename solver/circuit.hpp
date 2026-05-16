#pragma once

#include "component.hpp"
#include "wire.hpp"

#include <initializer_list>
#include <memory>
#include <vector>
#include <string>
#include <utility>
#include <type_traits>

namespace solver {
    class Solver;

    struct Snapshot {
        double time;
        std::vector<std::pair<std::string, double>> voltages;
        std::vector<std::pair<std::string, double>> currents;
    };

    class Circuit {
        std::vector<std::shared_ptr<Component>>     components;
        std::vector<std::shared_ptr<VoltageSource>> voltage_sources;
        std::vector<std::shared_ptr<Wire>>          wires;

        public:
            template<typename T, typename... Args>
            std::shared_ptr<T> add_component(Args&&... args) {
                auto component = std::make_shared<T>(std::forward<Args>(args)...);
                if constexpr (std::is_same_v<T, VoltageSource>) {
                    voltage_sources.emplace_back(component);
                } else {
                    components.emplace_back(component);
                }
                return component;
            }

            // Permet d'ajouter un composant déjà instancié (pour l'éditeur)
            void add_component(std::shared_ptr<Component> comp) {
                if (auto vs = std::dynamic_pointer_cast<VoltageSource>(comp)) {
                    voltage_sources.emplace_back(vs);
                } else {
                    components.emplace_back(comp);
                }
            }

            void add_wire(std::initializer_list<Pin*> pins, std::string label = "");
            void add_wire(const std::vector<Pin*>& pins, std::string label = "");

            const std::vector<std::shared_ptr<Component>>& get_components() const {
                return components;
            }

            bool is_fixed(std::shared_ptr<Wire> wire);
            void init_potentials(double V_init = 0.0);
            void compute_currents();
            double kcl_error(std::shared_ptr<Wire> wire);
            std::vector<std::shared_ptr<Wire>> free_wires();

            void solve();
            void solve(Solver& solver);
            void advance();
            void step(Solver& solver);

            Snapshot snapshot(double t);
            std::vector<Snapshot> simulate(int n_steps, double dt, Solver& solver);

            void debug();
    };
}