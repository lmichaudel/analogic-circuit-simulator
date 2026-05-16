#include "component.hpp"
#include "wire.hpp"
#include <cmath>
#include <string>
#include <sstream>

using namespace solver;

std::vector<double> Component::characteristic(std::vector<double> voltages) {
    return std::vector<double>(pins.size(), 0.0);
}

std::vector<std::vector<double>> Component::jacobian() {
    std::size_t n = pins.size();
    return std::vector<std::vector<double>>(n, std::vector<double>(n, 0.0));
}

void Component::update() {
    std::vector<double> tensions;
    tensions.reserve(pins.size());
    for (auto& p : pins)
        tensions.push_back(p.wire->potential);
    auto courants = characteristic(tensions);
    for (std::size_t k = 0; k < pins.size(); ++k)
        pins[k].current = courants[k];
}

void Component::serialize(std::ostream& os) const {
    os << "COMP " << id << " " << get_type_name() << " "
       << pos.x << " " << pos.y << " " << label << " " << rotation;
    serialize_attributes(os);
}

std::shared_ptr<Component> Component::deserialize_line(const std::string& line) {
    std::istringstream ss(line);
    std::string tok;
    ss >> tok;
    if (tok != "COMP") return nullptr;

    int id, rot;
    float px, py;
    std::string typeStr, name;
    ss >> id >> typeStr >> px >> py >> name >> rot;

    std::shared_ptr<Component> c;
    if (typeStr == "Resistor") c = std::make_shared<Resistor>(0, name);
    else if (typeStr == "VSource") c = std::make_shared<VoltageSource>(0, name);
    else if (typeStr == "CSource") c = std::make_shared<CurrentSource>(0, name);
    else if (typeStr == "Switch") c = std::make_shared<Switch>(false, name);
    else if (typeStr == "Diode") c = std::make_shared<Diode>(0, 0, 0, name);
    else if (typeStr == "Capacitor") c = std::make_shared<Capacitor>(0, 0.005, name);
    else if (typeStr == "Transistor") c = std::make_shared<Transistor>(0, 0, 0, 0, name);
    else if (typeStr == "Coil") c = std::make_shared<Coil>(0, 0.005, name);
    else if (typeStr == "Ground") c = std::make_shared<Ground>(name);
    else return nullptr;

    c->id = id;
    c->pos = {px, py};
    c->rotation = rot;
    c->deserialize_attributes(ss);
    return c;
}

ImVec2 Component::transform(ImVec2 local) const {
    float angle = rotation * (M_PI / 2.0f);
    float s = std::sin(angle), c = std::cos(angle);
    return {pos.x + local.x * c - local.y * s, pos.y + local.x * s + local.y * c};
}

ImVec2 Component::get_pin_world_pos(std::size_t i) const {
    return transform(get_pin_local_pos(i));
}

Ground::Ground(std::string label) : Component(label) {
    pins.emplace_back(0, this);
}
std::vector<double> Ground::characteristic(std::vector<double> v) { return {0.0}; }
std::vector<std::vector<double>> Ground::jacobian() { return {{0.0}}; }
void Ground::update() {}

ImVec2 Ground::get_pin_local_pos(std::size_t i) const { return {0, -COMP_GRID}; }

void Ground::draw(ImDrawList* dl, ImU32 col) {
    dl->AddLine(transform({0, -COMP_GRID}), transform({0, COMP_GRID * 0.2f}), col, 1.5f);
    for (int i = 0; i < 3; i++) {
        float w = COMP_GRID * (0.8f - i * 0.22f), y = COMP_GRID * 0.2f + i * COMP_GRID * 0.32f;
        dl->AddLine(transform({-w, y}), transform({w, y}), col, 1.5f + i * 0.4f);
    }
}

// -- Resistor -----------------------------------------------------------------

Resistor::Resistor(double resistance, std::string label)
    : Component(label), resistance(resistance) {
    pins.emplace_back(0, this);
    pins.emplace_back(0, this);
}

std::vector<double> Resistor::characteristic(std::vector<double> v) {
    double I = (v[0] - v[1]) / resistance;
    return {-I, +I};
}

std::vector<std::vector<double>> Resistor::jacobian() {
    double g = 1.0 / resistance;
    return {{-g, +g}, {+g, -g}};
}

void Resistor::update() {
    auto I = characteristic({pins[0].wire->potential, pins[1].wire->potential});
    pins[0].current = I[0];
    pins[1].current = I[1];
}

bool Resistor::render_properties() {
    return ImGui::InputDouble("R (Ohm)", &resistance);
}

void Resistor::serialize_attributes(std::ostream& os) const { os << " " << resistance; }
void Resistor::deserialize_attributes(std::istream& is) { is >> resistance; }

ImVec2 Resistor::get_pin_local_pos(std::size_t i) const {
    return (i == 0) ? ImVec2{-2 * COMP_GRID, 0} : ImVec2{2 * COMP_GRID, 0};
}

void Resistor::draw(ImDrawList* dl, ImU32 col) {
    float hw = COMP_GRID * 1.f, hh = COMP_GRID * 0.4f;
    dl->AddLine(transform({-2 * COMP_GRID, 0}), transform({-hw, 0}), col, 1.5f);
    dl->AddLine(transform({hw, 0}), transform({2 * COMP_GRID, 0}), col, 1.5f);
    ImVec2 p = transform({-hw, 0});
    int n = 6;
    float step = hw * 2.f / n;
    for (int i = 1; i <= n; i++) {
        ImVec2 q = transform({-hw + i * step, (float)(i % 2 == 0 ? hh : -hh)});
        dl->AddLine(p, q, col, 1.5f);
        p = q;
    }
    dl->AddLine(p, transform({hw, 0}), col, 1.5f);
}

// -- VoltageSource ------------------------------------------------------------

VoltageSource::VoltageSource(double voltage, std::string label)
    : Component(label), voltage(voltage) {
    pins.emplace_back(0, this);
    pins.emplace_back(0, this);
}

bool VoltageSource::render_properties() {
    return ImGui::InputDouble("V (Volts)", &voltage);
}

void VoltageSource::serialize_attributes(std::ostream& os) const { os << " " << voltage; }
void VoltageSource::deserialize_attributes(std::istream& is) { is >> voltage; }

ImVec2 VoltageSource::get_pin_local_pos(std::size_t i) const {
    return (i == 0) ? ImVec2{-2 * COMP_GRID, 0} : ImVec2{2 * COMP_GRID, 0};
}

void VoltageSource::draw(ImDrawList* dl, ImU32 col) {
    float r = COMP_GRID * 0.8f, s = 5.f;
    dl->AddCircle(pos, r, col, 32, 1.5f);
    dl->AddLine(transform({-2 * COMP_GRID, 0}), transform({-r, 0}), col, 1.5f);
    dl->AddLine(transform({r, 0}), transform({2 * COMP_GRID, 0}), col, 1.5f);
    dl->AddLine(transform({-s, -COMP_GRID * 0.4f}), transform({s, -COMP_GRID * 0.4f}), col, 1.5f);
    dl->AddLine(transform({0, -COMP_GRID * 0.4f - s}), transform({0, -COMP_GRID * 0.4f + s}), col, 1.5f);
    dl->AddLine(transform({-s, COMP_GRID * 0.4f}), transform({s, COMP_GRID * 0.4f}), col, 1.5f);
}

// -- CurrentSource ------------------------------------------------------------

CurrentSource::CurrentSource(double current, std::string label)
    : Component(label), current_value(current) {
    pins.emplace_back(0, this);
    pins.emplace_back(0, this);
}

std::vector<double> CurrentSource::characteristic(std::vector<double> /*v*/) {
    return {+current_value, -current_value};
}

std::vector<std::vector<double>> CurrentSource::jacobian() {
    return {{0.0, 0.0}, {0.0, 0.0}};
}

void CurrentSource::update() {
    auto I = characteristic({});
    pins[0].current = I[0];
    pins[1].current = I[1];
}

bool CurrentSource::render_properties() {
    return ImGui::InputDouble("I (Amps)", &current_value);
}

void CurrentSource::serialize_attributes(std::ostream& os) const { os << " " << current_value; }
void CurrentSource::deserialize_attributes(std::istream& is) { is >> current_value; }

ImVec2 CurrentSource::get_pin_local_pos(std::size_t i) const {
    return (i == 0) ? ImVec2{-2 * COMP_GRID, 0} : ImVec2{2 * COMP_GRID, 0};
}

void CurrentSource::draw(ImDrawList* dl, ImU32 col) {
    float r = COMP_GRID * 0.8f;
    dl->AddCircle(pos, r, col, 32, 1.5f);
    dl->AddLine(transform({-2 * COMP_GRID, 0}), transform({-r, 0}), col, 1.5f);
    dl->AddLine(transform({r, 0}), transform({2 * COMP_GRID, 0}), col, 1.5f);
    dl->AddLine(transform({0, -COMP_GRID*0.5f}), transform({0, COMP_GRID*0.5f}), col, 1.5f);
    dl->AddTriangleFilled(transform({-5.f, COMP_GRID*0.2f}), transform({5.f, COMP_GRID*0.2f}), transform({0, COMP_GRID*0.5f}), col);
}

// -- Switch -------------------------------------------------------------------

Switch::Switch(bool closed, std::string label)
    : Component(label), closed(closed) {
    pins.emplace_back(0, this);
    pins.emplace_back(0, this);
}

std::vector<double> Switch::characteristic(std::vector<double> v) {
    if (!closed) return {0.0, 0.0};
    double I = (v[0] - v[1]) / R_closed;
    return {-I, +I};
}

std::vector<std::vector<double>> Switch::jacobian() {
    if (!closed) return {{0.0, 0.0}, {0.0, 0.0}};
    double g = 1.0 / R_closed;
    return {{-g, +g}, {+g, -g}};
}

void Switch::update() {
    auto I = characteristic({pins[0].wire->potential, pins[1].wire->potential});
    pins[0].current = I[0];
    pins[1].current = I[1];
}

bool Switch::render_properties() {
    return ImGui::Checkbox("Fermé", &closed);
}

void Switch::serialize_attributes(std::ostream& os) const { os << " " << closed; }
void Switch::deserialize_attributes(std::istream& is) { is >> closed; }

ImVec2 Switch::get_pin_local_pos(std::size_t i) const {
    return (i == 0) ? ImVec2{-2 * COMP_GRID, 0} : ImVec2{2 * COMP_GRID, 0};
}

void Switch::draw(ImDrawList* dl, ImU32 col) {
    dl->AddLine(transform({-2 * COMP_GRID, 0}), transform({-COMP_GRID, 0}), col, 1.5f);
    dl->AddLine(transform({COMP_GRID, 0}), transform({2 * COMP_GRID, 0}), col, 1.5f);
    dl->AddCircle(transform({-COMP_GRID, 0}), 2.f, col, 12, 1.5f);
    dl->AddCircle(transform({COMP_GRID, 0}), 2.f, col, 12, 1.5f);
    if (closed) {
        dl->AddLine(transform({-COMP_GRID, 0}), transform({COMP_GRID, 0}), col, 1.5f);
    } else {
        dl->AddLine(transform({-COMP_GRID, 0}), transform({COMP_GRID*0.8f, -COMP_GRID*0.8f}), col, 1.5f);
    }
}

// -- Diode (modele de Shockley) -----------------------------------------------

Diode::Diode(double saturation_current, double ideality_factor,
             double thermal_voltage, std::string label)
    : Component(label),
      saturation_current(saturation_current),
      ideality_factor(ideality_factor),
      thermal_voltage(thermal_voltage)
{
    pins.emplace_back(0, this);
    pins.emplace_back(0, this);
}

std::vector<double> Diode::characteristic(std::vector<double> v) {
    double exposant = (v[0] - v[1]) / (ideality_factor * thermal_voltage);
    if (exposant > 80.0) exposant = 80.0;
    double I = saturation_current * (std::exp(exposant) - 1.0);
    return {-I, +I};
}

std::vector<std::vector<double>> Diode::jacobian() {
    double v0 = pins[0].wire->potential;
    double v1 = pins[1].wire->potential;
    double exposant = (v0 - v1) / (ideality_factor * thermal_voltage);
    if (exposant > 80.0) exposant = 80.0;
    double gd = saturation_current / (ideality_factor * thermal_voltage) * std::exp(exposant);
    return {{-gd, +gd}, {+gd, -gd}};
}

void Diode::update() {
    auto I = characteristic({pins[0].wire->potential, pins[1].wire->potential});
    pins[0].current = I[0];
    pins[1].current = I[1];
}

bool Diode::render_properties() {
    bool changed = false;
    changed |= ImGui::InputDouble("I_s (A)", &saturation_current, 0.0, 0.0, "%.3e");
    changed |= ImGui::InputDouble("Facteur n", &ideality_factor);
    changed |= ImGui::InputDouble("V_T (Volts)", &thermal_voltage, 0.0, 0.0, "%.5f");
    return changed;
}

void Diode::serialize_attributes(std::ostream& os) const {
    os << " " << saturation_current << " " << ideality_factor << " " << thermal_voltage;
}

void Diode::deserialize_attributes(std::istream& is) {
    is >> saturation_current >> ideality_factor >> thermal_voltage;
}

ImVec2 Diode::get_pin_local_pos(std::size_t i) const {
    return (i == 0) ? ImVec2{-2 * COMP_GRID, 0} : ImVec2{2 * COMP_GRID, 0};
}

void Diode::draw(ImDrawList* dl, ImU32 col) {
    float hw = COMP_GRID * 0.6f, hh = COMP_GRID * 0.5f;
    dl->AddLine(transform({-2 * COMP_GRID, 0}), transform({2 * COMP_GRID, 0}), col, 1.5f);
    dl->AddTriangle(transform({-hw, -hh}), transform({-hw, hh}), transform({hw, 0}), col, 1.5f);
    dl->AddLine(transform({hw, -hh}), transform({hw, hh}), col, 2.f);
}

// -- Capacitor ----------------------------------------------------------------

Capacitor::Capacitor(double capacitance, double dt, std::string label)
    : Component(label), capacitance(capacitance), dt(dt), V_prev(0.0) {
    pins.emplace_back(0, this);
    pins.emplace_back(0, this);
}

std::vector<double> Capacitor::characteristic(std::vector<double> v) {
    double I = capacitance * ((v[0] - v[1]) - V_prev) / dt;
    return {-I, +I};
}

std::vector<std::vector<double>> Capacitor::jacobian() {
    double g = capacitance / dt;
    return {{-g, +g}, {+g, -g}};
}

void Capacitor::update() {
    auto I = characteristic({pins[0].wire->potential, pins[1].wire->potential});
    pins[0].current = I[0];
    pins[1].current = I[1];
}

void Capacitor::advance() {
    V_prev = pins[0].wire->potential - pins[1].wire->potential;
}

bool Capacitor::render_properties() {
    return ImGui::InputDouble("C (Farads)", &capacitance, 0.0, 0.0, "%.3e");
}

void Capacitor::serialize_attributes(std::ostream& os) const { os << " " << capacitance << " " << dt; }
void Capacitor::deserialize_attributes(std::istream& is) { is >> capacitance >> dt; }

ImVec2 Capacitor::get_pin_local_pos(std::size_t i) const {
    return (i == 0) ? ImVec2{-2 * COMP_GRID, 0} : ImVec2{2 * COMP_GRID, 0};
}

void Capacitor::draw(ImDrawList* dl, ImU32 col) {
    float hw = COMP_GRID * 0.3f, hh = COMP_GRID * 0.8f;
    dl->AddLine(transform({-2 * COMP_GRID, 0}), transform({-hw, 0}), col, 1.5f);
    dl->AddLine(transform({hw, 0}), transform({2 * COMP_GRID, 0}), col, 1.5f);
    dl->AddLine(transform({-hw, -hh}), transform({-hw, hh}), col, 1.5f);
    dl->AddLine(transform({hw, -hh}), transform({hw, hh}), col, 1.5f);
}

// -- Transistor NPN (modele d'Ebers-Moll) ------------------------------------

Transistor::Transistor(double saturation_current, double beta_f, double beta_r,
                       double thermal_voltage, std::string label)
    : Component(label),
      saturation_current(saturation_current),
      beta_f(beta_f), beta_r(beta_r),
      thermal_voltage(thermal_voltage)
{
    pins.emplace_back(0, this);
    pins.emplace_back(0, this);
    pins.emplace_back(0, this);
}

std::vector<double> Transistor::characteristic(std::vector<double> v) {
    double v_b = v[0], v_c = v[1], v_e = v[2];
    double vbe = v_b - v_e;
    double vbc = v_b - v_c;
    double exp_be = std::exp(std::min(vbe / thermal_voltage, 80.0));
    double exp_bc = std::exp(std::min(vbc / thermal_voltage, 80.0));
    double i_c = saturation_current * (exp_be - exp_bc) - (saturation_current / beta_r) * (exp_bc - 1.0);
    double i_b = (saturation_current / beta_f) * (exp_be - 1.0) + (saturation_current / beta_r) * (exp_bc - 1.0);
    double i_e = -(i_b + i_c);
    return {-i_b, -i_c, -i_e};
}

std::vector<std::vector<double>> Transistor::jacobian() {
    double v_b = pins[0].wire->potential;
    double v_c = pins[1].wire->potential;
    double v_e = pins[2].wire->potential;
    double vbe = v_b - v_e;
    double vbc = v_b - v_c;
    double exp_be = std::exp(std::min(vbe / thermal_voltage, 80.0));
    double exp_bc = std::exp(std::min(vbc / thermal_voltage, 80.0));
    double d_be = saturation_current / thermal_voltage * exp_be;
    double d_bc = saturation_current / thermal_voltage * exp_bc;
    return {
        {-d_be / beta_f,              +d_bc / beta_r,               +d_be / beta_f              },
        {-d_be,                       -d_bc * (1.0 + 1.0 / beta_r),  +d_be                      },
        {+d_be * (1.0 + 1.0 / beta_f), +d_bc,                       -d_be * (1.0 + 1.0 / beta_f)}
    };
}

void Transistor::update() {
    auto I = characteristic({pins[0].wire->potential, pins[1].wire->potential, pins[2].wire->potential});
    pins[0].current = I[0];
    pins[1].current = I[1];
    pins[2].current = I[2];
}

bool Transistor::render_properties() {
    bool changed = false;
    changed |= ImGui::InputDouble("I_s (A)", &saturation_current, 0.0, 0.0, "%.3e");
    changed |= ImGui::InputDouble("Beta_F", &beta_f);
    changed |= ImGui::InputDouble("Beta_R", &beta_r);
    changed |= ImGui::InputDouble("V_T (Volts)", &thermal_voltage, 0.0, 0.0, "%.5f");
    return changed;
}

void Transistor::serialize_attributes(std::ostream& os) const {
    os << " " << saturation_current << " " << beta_f << " " << beta_r << " " << thermal_voltage;
}

void Transistor::deserialize_attributes(std::istream& is) {
    is >> saturation_current >> beta_f >> beta_r >> thermal_voltage;
}

ImVec2 Transistor::get_pin_local_pos(std::size_t i) const {
    if (i == 0) return {-2 * COMP_GRID, 0};
    if (i == 1) return {2 * COMP_GRID, -2 * COMP_GRID};
    return {2 * COMP_GRID, 2 * COMP_GRID};
}

void Transistor::draw(ImDrawList* dl, ImU32 col) {
    float bw = COMP_GRID * 0.5f, bh = COMP_GRID * 1.0f;
    dl->AddLine(transform({-2 * COMP_GRID, 0}), transform({-bw, 0}), col, 1.5f);
    dl->AddLine(transform({-bw, -bh}), transform({-bw, bh}), col, 2.0f);
    dl->AddLine(transform({2 * COMP_GRID, -2 * COMP_GRID}), transform({2 * COMP_GRID, -bh}), col, 1.5f);
    dl->AddLine(transform({2 * COMP_GRID, -bh}), transform({-bw + 1.f, -bh * 0.4f}), col, 1.5f);
    dl->AddLine(transform({2 * COMP_GRID, 2 * COMP_GRID}), transform({2 * COMP_GRID, bh}), col, 1.5f);
    dl->AddLine(transform({2 * COMP_GRID, bh}), transform({-bw + 1.f, bh * 0.4f}), col, 1.5f);
    dl->AddTriangleFilled(transform({COMP_GRID, bh}), transform({COMP_GRID * 0.3f, bh - COMP_GRID * 0.3f}),
                          transform({COMP_GRID * 1.1f, bh - COMP_GRID * 0.7f}), col);
}

// -- Coil (bobine) ------------------------------------------------------------

Coil::Coil(double inductance, double dt, std::string label)
    : Component(label), inductance(inductance), dt(dt), I_prev(0.0) {
    pins.emplace_back(0, this);
    pins.emplace_back(0, this);
}

std::vector<double> Coil::characteristic(std::vector<double> v) {
    double I = I_prev + (v[0] - v[1]) * dt / inductance;
    return {-I, +I};
}

std::vector<std::vector<double>> Coil::jacobian() {
    double g = dt / inductance;
    return {{-g, +g}, {+g, -g}};
}

void Coil::update() {
    auto I = characteristic({pins[0].wire->potential, pins[1].wire->potential});
    pins[0].current = I[0];
    pins[1].current = I[1];
}

void Coil::advance() {
    double v0 = pins[0].wire->potential;
    double v1 = pins[1].wire->potential;
    I_prev += (v0 - v1) * dt / inductance;
}

bool Coil::render_properties() {
    return ImGui::InputDouble("L (Henry)", &inductance, 0.0, 0.0, "%.3e");
}

void Coil::serialize_attributes(std::ostream& os) const { os << " " << inductance << " " << dt; }
void Coil::deserialize_attributes(std::istream& is) { is >> inductance >> dt; }

ImVec2 Coil::get_pin_local_pos(std::size_t i) const {
    return (i == 0) ? ImVec2{-2 * COMP_GRID, 0} : ImVec2{2 * COMP_GRID, 0};
}

void Coil::draw(ImDrawList* dl, ImU32 col) {
    float hw = COMP_GRID * 1.0f, r = COMP_GRID * 0.25f;
    dl->AddLine(transform({-2 * COMP_GRID, 0}), transform({-hw, 0}), col, 1.5f);
    dl->AddLine(transform({hw, 0}), transform({2 * COMP_GRID, 0}), col, 1.5f);
    for (int i = 0; i < 4; i++) {
        float cx = -hw + r + i * (hw * 2 / 4.0f);
        dl->AddBezierQuadratic(transform({cx - r, 0}), transform({cx, -COMP_GRID * 0.6f}), transform({cx + r, 0}), col, 1.5f);
    }
}