#pragma once

#include <initializer_list>
#include "component.hpp"
#include <string>

namespace solver {
    class Wire {
        public:
            std::vector<Pin*> connected_pins;
            double potential;
            std::string label;

            Wire(std::initializer_list<Pin*> pins, double potential, std::string label)
            : connected_pins(pins), potential(potential), label(label) {}
            Wire(const std::vector<Pin*>& pins, double potential, std::string label)
            : connected_pins(pins), potential(potential), label(label) {}
    };
}
