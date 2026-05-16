#pragma once

#include <memory>
#include <vector>
#include <string>
#include <iostream>
#include "imgui.h"

namespace solver {
    constexpr float COMP_GRID = 20.f;

    struct Pin {
        double current;
        class Component* owner;
        std::shared_ptr<class Wire> wire;

        Pin(double current, class Component* owner)
            : current(current), owner(owner) {}
    };

    class Component {
        protected:
            std::vector<Pin> pins{};
        public:
            std::string label;

            // pour l'éditeur
            int id = 0;
            ImVec2 pos = {0, 0};
            int rotation = 0;
            bool selected = false;

            Pin& get_pin(std::size_t i) { return pins[i]; }
            std::size_t pin_count() const { return pins.size(); }

            Component(std::string label) : label(label) {}
            virtual ~Component() = default;


            virtual std::vector<double> characteristic(std::vector<double> voltages);
            virtual std::vector<std::vector<double>> jacobian();
            virtual void update();
            virtual void advance() {}
            virtual void reset_state() {}
            virtual void set_dt(double new_dt) {}

            virtual std::string get_type_name() const = 0;
            virtual bool render_properties() { return false; }

            // Sérialisation
            virtual void serialize(std::ostream& os) const;
            static std::shared_ptr<Component> deserialize_line(const std::string& line);
            virtual void serialize_attributes(std::ostream& os) const {}
            virtual void deserialize_attributes(std::istream& is) {}

            // Dessin
            virtual ImVec2 get_pin_local_pos(std::size_t i) const = 0;
            ImVec2 get_pin_world_pos(std::size_t i) const;
            ImVec2 transform(ImVec2 local) const;
            virtual void draw(ImDrawList* dl, ImU32 col) = 0;
    };

    // ── Ground (Masse) ────────────────────────────────────────────────────────
    class Ground : public Component {
        public:
            Ground(std::string label = "");
            std::vector<double> characteristic(std::vector<double> voltages) override;
            std::vector<std::vector<double>> jacobian() override;
            void update() override;

            std::string get_type_name() const override { return "Ground"; }
            ImVec2 get_pin_local_pos(std::size_t i) const override;
            void draw(ImDrawList* dl, ImU32 col) override;
    };

    // ── Resistor ──────────────────────────────────────────────────────────────
    class Resistor : public Component {
            double resistance;
        public:
            Resistor(double resistance, std::string label = "");
            std::vector<double> characteristic(std::vector<double> voltages) override;
            std::vector<std::vector<double>> jacobian() override;
            void update() override;

            std::string get_type_name() const override { return "Resistor"; }
            bool render_properties() override;
            void serialize_attributes(std::ostream& os) const override;
            void deserialize_attributes(std::istream& is) override;
            ImVec2 get_pin_local_pos(std::size_t i) const override;
            void draw(ImDrawList* dl, ImU32 col) override;
    };

    // ── VoltageSource ─────────────────────────────────────────────────────────
    class VoltageSource : public Component {
            double voltage;
        public:
            VoltageSource(double voltage, std::string label = "");
            double get_voltage() const { return voltage; }

            std::string get_type_name() const override { return "VSource"; }
            bool render_properties() override;
            void serialize_attributes(std::ostream& os) const override;
            void deserialize_attributes(std::istream& is) override;
            ImVec2 get_pin_local_pos(std::size_t i) const override;
            void draw(ImDrawList* dl, ImU32 col) override;
    };

    // ── CurrentSource ─────────────────────────────────────────────────────────
    class CurrentSource : public Component {
            double current_value;
        public:
            CurrentSource(double current, std::string label = "");
            std::vector<double> characteristic(std::vector<double> voltages) override;
            std::vector<std::vector<double>> jacobian() override;
            void update() override;

            std::string get_type_name() const override { return "CSource"; }
            bool render_properties() override;
            void serialize_attributes(std::ostream& os) const override;
            void deserialize_attributes(std::istream& is) override;
            ImVec2 get_pin_local_pos(std::size_t i) const override;
            void draw(ImDrawList* dl, ImU32 col) override;
    };

    // ── Switch ────────────────────────────────────────────────────────────────
    class Switch : public Component {
            bool closed;
            static constexpr double R_closed = 1e-6;
        public:
            Switch(bool closed = true, std::string label = "");
            void set_closed(bool c) { closed = c; }
            bool is_closed() const { return closed; }
            std::vector<double> characteristic(std::vector<double> voltages) override;
            std::vector<std::vector<double>> jacobian() override;
            void update() override;

            std::string get_type_name() const override { return "Switch"; }
            bool render_properties() override;
            void serialize_attributes(std::ostream& os) const override;
            void deserialize_attributes(std::istream& is) override;
            ImVec2 get_pin_local_pos(std::size_t i) const override;
            void draw(ImDrawList* dl, ImU32 col) override;
    };

    // ── Diode (Shockley) ──────────────────────────────────────────────────────
    class Diode : public Component {
        public:
            double saturation_current;
            double ideality_factor;
            double thermal_voltage;

            Diode(double saturation_current = 1e-12,
                  double ideality_factor    = 1.0,
                  double thermal_voltage    = 0.02585,
                  std::string label         = "");

            std::vector<double> characteristic(std::vector<double> voltages) override;
            std::vector<std::vector<double>> jacobian() override;
            void update() override;

            std::string get_type_name() const override { return "Diode"; }
            bool render_properties() override;
            void serialize_attributes(std::ostream& os) const override;
            void deserialize_attributes(std::istream& is) override;
            ImVec2 get_pin_local_pos(std::size_t i) const override;
            void draw(ImDrawList* dl, ImU32 col) override;
    };

    // ── Capacitor ─────────────────────────────────────────────────────────────
    class Capacitor : public Component {
            double capacitance;
            double dt;
            double V_prev;
        public:
            Capacitor(double capacitance, double dt, std::string label = "");
            std::vector<double> characteristic(std::vector<double> voltages) override;
            std::vector<std::vector<double>> jacobian() override;
            void update() override;
            void advance() override;
            void reset_state() override { V_prev = 0.0; }
            void set_dt(double new_dt) override { dt = new_dt; }

            std::string get_type_name() const override { return "Capacitor"; }
            bool render_properties() override;
            void serialize_attributes(std::ostream& os) const override;
            void deserialize_attributes(std::istream& is) override;
            ImVec2 get_pin_local_pos(std::size_t i) const override;
            void draw(ImDrawList* dl, ImU32 col) override;
    };

    // ── Transistor (NPN, Ebers-Moll) ─────────────────────────────────────────
    class Transistor : public Component {
        public:
            double saturation_current;
            double beta_f;
            double beta_r;
            double thermal_voltage;

            Transistor(double saturation_current = 1e-14,
                       double beta_f             = 100.0,
                       double beta_r             = 5.0,
                       double thermal_voltage    = 0.02585,
                       std::string label         = "");

            std::vector<double> characteristic(std::vector<double> voltages) override;
            std::vector<std::vector<double>> jacobian() override;
            void update() override;

            std::string get_type_name() const override { return "Transistor"; }
            bool render_properties() override;
            void serialize_attributes(std::ostream& os) const override;
            void deserialize_attributes(std::istream& is) override;
            ImVec2 get_pin_local_pos(std::size_t i) const override;
            void draw(ImDrawList* dl, ImU32 col) override;
    };

    // ── Coil ─────────────────────────────────────────────────────────────────
    class Coil : public Component {
            double inductance;
            double dt;
            double I_prev;
        public:
            Coil(double inductance, double dt, std::string label = "");
            std::vector<double> characteristic(std::vector<double> voltages) override;
            std::vector<std::vector<double>> jacobian() override;
            void update() override;
            void advance() override;
            void reset_state() override { I_prev = 0.0; }
            void set_dt(double new_dt) override { dt = new_dt; }

            std::string get_type_name() const override { return "Coil"; }
            bool render_properties() override;
            void serialize_attributes(std::ostream& os) const override;
            void deserialize_attributes(std::istream& is) override;
            ImVec2 get_pin_local_pos(std::size_t i) const override;
            void draw(ImDrawList* dl, ImU32 col) override;
    };
}