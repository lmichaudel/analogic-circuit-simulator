#define GL_SILENCE_DEPRECATION
#include "imgui.h"
#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"
#include <GLFW/glfw3.h>
#include <algorithm>
#include <cmath>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <vector>
#include <functional>
#include <chrono>

#include "../solver/circuit.hpp"
#include "../solver/component.hpp"
#include "../solver/solver.hpp"

static float snap(float v) { return roundf(v / solver::COMP_GRID) * solver::COMP_GRID; }
static ImVec2 snap2(ImVec2 v) { return {snap(v.x), snap(v.y)}; }
static float dist(ImVec2 a, ImVec2 b) {
  float dx = a.x - b.x, dy = a.y - b.y;
  return sqrtf(dx * dx + dy * dy);
}

static float distToSegment(ImVec2 p, ImVec2 a, ImVec2 b) {
  float dx = b.x - a.x, dy = b.y - a.y;
  float len2 = dx * dx + dy * dy;
  if (len2 < 1e-6f) return dist(p, a);
  float t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2;
  t = std::max(0.f, std::min(1.f, t));
  return dist(p, {a.x + t * dx, a.y + t * dy});
}

static float distToWire(ImVec2 p, ImVec2 a, ImVec2 b, bool flipped) {
  ImVec2 elbow = flipped ? ImVec2(a.x, b.y) : ImVec2(b.x, a.y);
  return std::min(distToSegment(p, a, elbow), distToSegment(p, elbow, b));
}

struct Wire {
  int id, fromComp, fromPin, toComp, toPin;
  bool selected = false;
  bool flipped = false;
};

struct State {
  std::vector<std::shared_ptr<solver::Component>> comps;
  std::vector<Wire> wires;
  int nextId = 1;

  bool drawing = false;
  int drawFrom = -1, drawFromPin = -1;

  int selComp = -1, selWire = -1;

  int solver_method = 3;
  double last_sim_time_ms = 0.0;

  bool simulated = false;
  std::map<std::string, double> sim_v;
  std::map<std::string, double> sim_i;
  std::map<int, std::string> pin_net_names;
};

static bool saveCircuit(const State &st, const char *path) {
  std::ofstream f(path);
  if (!f) return false;
  f << "nextId " << st.nextId << "\n";
  for (const auto &c : st.comps) {
    c->serialize(f);
    f << "\n";
  }
  for (const auto &w : st.wires) {
    f << "WIRE " << w.id << " " << w.fromComp << " " << w.fromPin << " "
      << w.toComp << " " << w.toPin << " " << (w.flipped ? 1 : 0) << "\n";
  }
  return true;
}

static bool loadCircuit(State &st, const char *path) {
  std::ifstream f(path);
  if (!f) return false;

  State tmp;
  std::string line;
  while (std::getline(f, line)) {
    if (line.empty()) continue;
    std::istringstream ss(line);
    std::string tok;
    ss >> tok;
    if (tok == "nextId") {
      ss >> tmp.nextId;
    } else if (tok == "COMP") {
      auto c = solver::Component::deserialize_line(line);
      if (c) tmp.comps.push_back(c);
    } else if (tok == "WIRE") {
      Wire w;
      int flip;
      ss >> w.id >> w.fromComp >> w.fromPin >> w.toComp >> w.toPin >> flip;
      w.flipped = (flip != 0);
      tmp.wires.push_back(w);
    }
  }

  tmp.simulated = false;
  st = std::move(tmp);
  return true;
}

static void drawLabelBox(ImDrawList *dl, ImVec2 pos, const char *text,
                         ImU32 textCol, ImU32 bgCol, ImU32 borderCol) {
  ImVec2 sz = ImGui::CalcTextSize(text);
  float pad = 3.f;
  ImVec2 tl = {pos.x - pad, pos.y - pad};
  ImVec2 br = {pos.x + sz.x + pad, pos.y + sz.y + pad};
  dl->AddRectFilled(tl, br, bgCol, 4.f);
  dl->AddRect(tl, br, borderCol, 4.f, 0, 1.2f);
  dl->AddText(pos, textCol, text);
}

static void renderWire(ImDrawList *dl, const Wire &w,
                       const std::vector<std::shared_ptr<solver::Component>> &comps) {
  std::shared_ptr<solver::Component> fc = nullptr, tc = nullptr;
  for (auto &c : comps) {
    if (c->id == w.fromComp) fc = c;
    if (c->id == w.toComp) tc = c;
  }
  if (!fc || !tc) return;

  ImVec2 a = fc->get_pin_world_pos(w.fromPin);
  ImVec2 b = tc->get_pin_world_pos(w.toPin);
  ImU32 col = w.selected ? IM_COL32(0, 160, 40, 255) : IM_COL32(30, 30, 30, 255);

  ImVec2 elbow = w.flipped ? ImVec2(a.x, b.y) : ImVec2(b.x, a.y);
  dl->AddLine(a, elbow, col, 1.5f);
  dl->AddLine(elbow, b, col, 1.5f);
}

static void simulateCircuit(State &st) {
  solver::Circuit circuit;

  for (auto &c : st.comps) {
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

  for (auto &c : st.comps)
    for (std::size_t i = 0; i < c->pin_count(); i++)
      find(c->id * 10 + i);

  for (auto &w : st.wires)
    merge(w.fromComp * 10 + w.fromPin, w.toComp * 10 + w.toPin);

  std::map<int, std::vector<int>> nets;
  for (auto &c : st.comps)
    for (std::size_t i = 0; i < c->pin_count(); i++)
      nets[find(c->id * 10 + i)].push_back(c->id * 10 + i);

  int netIdx = 1;
  st.pin_net_names.clear();

  for (auto &net : nets) {
    bool isGnd = false;
    std::vector<solver::Pin *> dpins;
    for (int p : net.second) {
      int cid = p / 10;
      int pidx = p % 10;
      auto it = std::find_if(st.comps.begin(), st.comps.end(),
                             [&](const std::shared_ptr<solver::Component> &x) { return x->id == cid; });
      if (it != st.comps.end()) {
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
      for (int p : net.second)
        st.pin_net_names[p] = nname;
    }
  }

  std::unique_ptr<solver::Solver> solver;
  switch(st.solver_method) {
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
      solver = std::make_unique<solver::NewtonRaphson>();
      break;
    default:
      solver = std::make_unique<solver::NewtonRaphson>();
      break;
  }

  auto start_time = std::chrono::high_resolution_clock::now();
  circuit.solve(*solver);
  auto end_time = std::chrono::high_resolution_clock::now();
  std::chrono::duration<double, std::milli> elapsed = end_time - start_time;
  st.last_sim_time_ms = elapsed.count();
  st.simulated = true;
  st.sim_v.clear();
  st.sim_i.clear();
  solver::Snapshot snapshot = circuit.snapshot(0.0f);
  for (auto &[label, val] : snapshot.voltages) st.sim_v[label] = val;
  for (auto &[label, val] : snapshot.currents) st.sim_i[label] = val;
}

static void runEditor(State &st) {
  ImGuiIO &io = ImGui::GetIO();
  ImVec2 mpos = io.MousePos;

  static char fileBuf[256] = "circuit.cir";
  static bool openSaveModal = false, openLoadModal = false;
  static char statusMsg[128] = "";
  static float statusTimer = 0.f;

  float menuBarH = 0.f;
  if (ImGui::BeginMainMenuBar()) {
    menuBarH = ImGui::GetWindowSize().y;
    if (ImGui::BeginMenu("Fichier")) {
      if (ImGui::MenuItem("Sauvegarder...", "Ctrl+S")) openSaveModal = true;
      if (ImGui::MenuItem("Charger...", "Ctrl+O")) openLoadModal = true;
      ImGui::Separator();
      if (ImGui::MenuItem("Nouveau circuit")) {
        st = State{};
        snprintf(statusMsg, sizeof(statusMsg), "Nouveau circuit créé.");
        statusTimer = 3.f;
      }
      ImGui::EndMenu();
    }

    if (io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_S)) openSaveModal = true;
    if (io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_O)) openLoadModal = true;

    if (statusTimer > 0.f) {
      statusTimer -= io.DeltaTime;
      float alpha = std::min(1.f, statusTimer);
      ImGui::SameLine(ImGui::GetContentRegionAvail().x - ImGui::CalcTextSize(statusMsg).x - 8.f);
      ImGui::TextColored({0.1f, 0.6f, 0.1f, alpha}, "%s", statusMsg);
    }
    ImGui::EndMainMenuBar();
  }

  if (openSaveModal) { ImGui::OpenPopup("Sauvegarder le circuit"); openSaveModal = false; }
  if (ImGui::BeginPopupModal("Sauvegarder le circuit", nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
    ImGui::Text("Chemin du fichier :");
    ImGui::SetNextItemWidth(320.f);
    ImGui::InputText("##savepath", fileBuf, sizeof(fileBuf));
    ImGui::Spacing();
    if (ImGui::Button("Sauvegarder", {120, 0})) {
      if (saveCircuit(st, fileBuf)) snprintf(statusMsg, sizeof(statusMsg), "Sauvegardé : %s", fileBuf);
      else snprintf(statusMsg, sizeof(statusMsg), "Erreur : impossible d'écrire %s", fileBuf);
      statusTimer = 4.f;
      ImGui::CloseCurrentPopup();
    }
    ImGui::SameLine();
    if (ImGui::Button("Annuler", {80, 0})) ImGui::CloseCurrentPopup();
    ImGui::EndPopup();
  }

  if (openLoadModal) { ImGui::OpenPopup("Charger un circuit"); openLoadModal = false; }
  if (ImGui::BeginPopupModal("Charger un circuit", nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
    ImGui::Text("Chemin du fichier :");
    ImGui::SetNextItemWidth(320.f);
    ImGui::InputText("##loadpath", fileBuf, sizeof(fileBuf));
    ImGui::Spacing();
    if (ImGui::Button("Charger", {120, 0})) {
      if (loadCircuit(st, fileBuf)) snprintf(statusMsg, sizeof(statusMsg), "Chargé : %s", fileBuf);
      else snprintf(statusMsg, sizeof(statusMsg), "Erreur : fichier introuvable ou invalide.");
      statusTimer = 4.f;
      ImGui::CloseCurrentPopup();
    }
    ImGui::SameLine();
    if (ImGui::Button("Annuler", {80, 0})) ImGui::CloseCurrentPopup();
    ImGui::EndPopup();
  }

  ImGui::SetNextWindowPos({0, menuBarH}, ImGuiCond_Always);
  ImGui::SetNextWindowSize({220, io.DisplaySize.y - menuBarH}, ImGuiCond_Always);
  ImGui::Begin("##panel", nullptr,
               ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove |
               ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoScrollbar |
               ImGuiWindowFlags_NoBringToFrontOnFocus);

  ImGui::Text("Ajouter Composant");
  ImGui::Separator();
  auto addBtn = [&](const char *label, std::function<std::shared_ptr<solver::Component>()> factory) {
    if (ImGui::Button(label, {-1, 0})) {
      auto c = factory();
      c->id = st.nextId++;
      c->label += std::to_string(c->id);
      c->pos = {snap(400.f), snap(200.f)};
      st.comps.push_back(c);
      st.simulated = false;
    }
  };

  addBtn("Résistance", [&](){ return std::make_shared<solver::Resistor>(1.0, "R"); });
  addBtn("Source Tension", [&](){ return std::make_shared<solver::VoltageSource>(5.0, "V"); });
  addBtn("Condensateur", [&](){ return std::make_shared<solver::Capacitor>(100e-6, 0.005, "C"); });
  addBtn("Bobine", [&](){ return std::make_shared<solver::Coil>(1e-3, 0.005, "L"); });
  addBtn("Diode", [&](){ return std::make_shared<solver::Diode>(1e-12, 1.0, 0.02585, "D"); });
  addBtn("Transistor (NPN)", [&](){ return std::make_shared<solver::Transistor>(1e-14, 100.0, 5.0, 0.02585, "Q"); });
  addBtn("Interrupteur", [&](){ return std::make_shared<solver::Switch>(false, "SW"); });
  addBtn("Masse", [&](){ return std::make_shared<solver::Ground>("GND"); });

  ImGui::Spacing();
  ImGui::Separator();
  ImGui::Spacing();

  const char* methods[] = { "Naïf", "Gradient numérique", "Gradient analytique", "Newton-Raphson" };
  ImGui::Text("Solveur :");
  if (ImGui::Combo("##solver_method", &st.solver_method, methods, IM_ARRAYSIZE(methods))) {
      st.simulated = false;
  }

  ImGui::Spacing();

  if (ImGui::Button("Simuler", {-1, 0})) simulateCircuit(st);

  if (ImGui::Button("Effacer", {-1, 0})) {
    st.simulated = false;
    st.sim_v.clear();
    st.sim_i.clear();
    st.pin_net_names.clear();
  }

  if (st.drawing) {
    ImGui::Spacing();
    ImGui::TextColored({0.2f, 0.7f, 0.2f, 1.f}, "Dessin de fil...");
    ImGui::Text("Cliquez sur un autre pin");
    ImGui::Text("Shift pour changer l'orient.");
    ImGui::Text("Echap pour annuler");
  }

  for (auto &c : st.comps) {
    if (c->selected) {
      ImGui::Spacing();
      ImGui::Separator();
      ImGui::Text("Sélection : %s", c->label.c_str());

      if (ImGui::Button("Tourner 90°", {-1, 0})) {
        c->rotation = (c->rotation + 1) % 4;
        st.simulated = false;
      }

      char buf[32];
      strncpy(buf, c->label.c_str(), 31);
      if (ImGui::InputText("Nom##n", buf, 32)) {
        c->label = buf;
        st.simulated = false;
      }

      if (c->render_properties()) {
          st.simulated = false;
      }

      if (ImGui::Button("Supprimer##c", {-1, 0})) {
        int id = c->id;
        st.wires.erase(std::remove_if(st.wires.begin(), st.wires.end(),
                                      [id](const Wire &w) { return w.fromComp == id || w.toComp == id; }),
                       st.wires.end());
        st.comps.erase(std::remove_if(st.comps.begin(), st.comps.end(),
                                      [id](const std::shared_ptr<solver::Component> &x) { return x->id == id; }),
                       st.comps.end());
        st.selComp = -1;
        st.simulated = false;
        break;
      }
    }
  }

  if (st.selWire >= 0) {
    Wire *selW = nullptr;
    for (auto &w : st.wires) if (w.id == st.selWire) { selW = &w; break; }
    if (selW) {
      ImGui::Spacing();
      ImGui::Separator();
      ImGui::Text("Fil sélectionné");
      bool flipped = selW->flipped;
      if (ImGui::Checkbox("Flip", &flipped)) {
        selW->flipped = flipped;
        st.simulated = false;
      }
      if (ImGui::Button("Supprimer##w", {-1, 0})) {
        int wid = st.selWire;
        st.wires.erase(std::remove_if(st.wires.begin(), st.wires.end(), [wid](const Wire &w) { return w.id == wid; }), st.wires.end());
        st.selWire = -1;
        st.simulated = false;
      }
    } else {
      st.selWire = -1;
    }
  }

  if (st.simulated) {
      ImGui::Spacing();
      ImGui::Separator();
      ImGui::TextDisabled("Temps de résolution :");
      ImGui::TextColored({0.4f, 0.4f, 0.4f, 1.0f}, "%.3f ms", st.last_sim_time_ms);
  }

  ImGui::End();

  float cx = 220.f;
  ImGui::SetNextWindowPos({cx, menuBarH}, ImGuiCond_Always);
  ImGui::SetNextWindowSize({io.DisplaySize.x - cx, io.DisplaySize.y - menuBarH}, ImGuiCond_Always);
  ImGui::Begin("##cv", nullptr,
               ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
               ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoScrollbar |
               ImGuiWindowFlags_NoBringToFrontOnFocus | ImGuiWindowFlags_NoScrollWithMouse);

  ImDrawList *dl = ImGui::GetWindowDrawList();
  ImVec2 csize = ImGui::GetWindowSize();

  for (float x = cx; x < cx + csize.x; x += solver::COMP_GRID)
    dl->AddLine({x, 0}, {x, csize.y}, IM_COL32(220, 222, 228, 255), 0.5f);
  for (float y = 0; y < csize.y; y += solver::COMP_GRID)
    dl->AddLine({cx, y}, {cx + csize.x, y}, IM_COL32(220, 222, 228, 255), 0.5f);

  for (auto &w : st.wires) renderWire(dl, w, st.comps);

  if (st.drawing) {
    for (auto &c : st.comps)
      if (c->id == st.drawFrom) {
        ImVec2 a = c->get_pin_world_pos(st.drawFromPin);
        bool currentFlip = ImGui::GetIO().KeyShift;
        ImVec2 elbow = currentFlip ? ImVec2(a.x, mpos.y) : ImVec2(mpos.x, a.y);
        dl->AddLine(a, elbow, IM_COL32(10, 140, 10, 120), 2.f);
        dl->AddLine(elbow, mpos, IM_COL32(10, 140, 10, 120), 2.f);
      }
  }

  for (auto &c : st.comps) {
    ImU32 col = c->selected ? IM_COL32(30, 120, 220, 255) : IM_COL32(30, 30, 30, 255);
    c->draw(dl, col);

    for (std::size_t i = 0; i < c->pin_count(); i++) {
      dl->AddCircleFilled(c->get_pin_world_pos(i), 4.f, IM_COL32(50, 100, 220, 200));
    }
    dl->AddText({c->pos.x + solver::COMP_GRID * 1.6f, c->pos.y - solver::COMP_GRID * 1.4f}, IM_COL32(60, 60, 60, 255), c->label.c_str());
  }

  if (st.simulated) {
    for (auto &c : st.comps) {
      if (st.sim_i.count(c->label)) {
        char buf[64];
        snprintf(buf, 64, "%.2f A", st.sim_i[c->label]);
        ImVec2 sz = ImGui::CalcTextSize(buf);
        ImVec2 pos = (c->rotation % 2 == 1)
                         ? ImVec2{c->pos.x + solver::COMP_GRID * 2.5f, c->pos.y - sz.y * 0.5f}
                         : ImVec2{c->pos.x - sz.x * 0.5f, c->pos.y + solver::COMP_GRID * 1.6f};
        drawLabelBox(dl, pos, buf, IM_COL32(160, 20, 20, 255), IM_COL32(255, 220, 220, 230), IM_COL32(200, 60, 60, 255));
      }
      for (std::size_t i = 0; i < c->pin_count(); i++) {
        int pid = c->id * 10 + i;
        if (st.pin_net_names.count(pid)) {
          std::string nname = st.pin_net_names[pid];
          if (st.sim_v.count(nname)) {
            char buf[64];
            snprintf(buf, 64, "%.2f V", st.sim_v[nname]);
            ImVec2 pp = c->get_pin_world_pos(i);
            ImVec2 sz = ImGui::CalcTextSize(buf);
            ImVec2 dir = {pp.x - c->pos.x, pp.y - c->pos.y};
            float len = sqrtf(dir.x * dir.x + dir.y * dir.y);
            if (len > 0.f) { dir.x /= len; dir.y /= len; }
            ImVec2 pos = {pp.x + dir.x * solver::COMP_GRID * 0.8f - sz.x * 0.5f,
                          pp.y + dir.y * solver::COMP_GRID * 0.8f - sz.y * 0.5f};
            drawLabelBox(dl, pos, buf, IM_COL32(10, 100, 10, 255), IM_COL32(210, 245, 210, 230), IM_COL32(60, 160, 60, 255));
          }
        }
      }
    }
  }

  ImGui::InvisibleButton("##inp", csize);
  bool hov = ImGui::IsItemHovered();

  if (st.drawing && ImGui::IsKeyPressed(ImGuiKey_Escape)) {
    st.drawing = false;
    st.drawFrom = -1;
  }

  if (ImGui::IsKeyPressed(ImGuiKey_Delete) || ImGui::IsKeyPressed(ImGuiKey_Backspace)) {
    if (st.selWire >= 0) {
      int wid = st.selWire;
      st.wires.erase(std::remove_if(st.wires.begin(), st.wires.end(), [wid](const Wire &w) { return w.id == wid; }), st.wires.end());
      st.selWire = -1;
      st.simulated = false;
    }
  }

  if (hov && ImGui::IsMouseClicked(ImGuiMouseButton_Left)) {
    int hitComp = -1, hitPin = -1;
    for (auto &c : st.comps)
      for (std::size_t i = 0; i < c->pin_count(); i++)
        if (dist(mpos, c->get_pin_world_pos(i)) < solver::COMP_GRID * 0.8f) {
          hitComp = c->id;
          hitPin = i;
        }

    if (st.drawing) {
      if (hitComp >= 0 && (hitComp != st.drawFrom || hitPin != st.drawFromPin)) {
        Wire w; w.id = st.nextId++; w.fromComp = st.drawFrom; w.fromPin = st.drawFromPin;
        w.toComp = hitComp; w.toPin = hitPin; w.flipped = ImGui::GetIO().KeyShift;
        st.wires.push_back(w);
        st.drawing = false; st.drawFrom = -1; st.simulated = false;
      }
    } else if (hitComp >= 0) {
      st.drawing = true; st.drawFrom = hitComp; st.drawFromPin = hitPin;
      for (auto &w : st.wires) w.selected = false; st.selWire = -1;
      for (auto &c : st.comps) c->selected = false; st.selComp = -1;
    } else {
      int found = -1;
      for (auto &c : st.comps)
        if (fabsf(mpos.x - c->pos.x) < 2 * solver::COMP_GRID && fabsf(mpos.y - c->pos.y) < 2 * solver::COMP_GRID)
          found = c->id;
      for (auto &c : st.comps) c->selected = (c->id == found);
      st.selComp = found;

      if (found < 0) {
        int foundWire = -1;
        float bestDist = 6.f;
        for (auto &w : st.wires) {
          std::shared_ptr<solver::Component> fc = nullptr, tc = nullptr;
          for (auto &c : st.comps) {
            if (c->id == w.fromComp) fc = c;
            if (c->id == w.toComp) tc = c;
          }
          if (!fc || !tc) continue;
          ImVec2 a = fc->get_pin_world_pos(w.fromPin);
          ImVec2 b = tc->get_pin_world_pos(w.toPin);
          float d = distToWire(mpos, a, b, w.flipped);
          if (d < bestDist) { bestDist = d; foundWire = w.id; }
        }
        for (auto &w : st.wires) w.selected = (w.id == foundWire);
        st.selWire = foundWire;
      } else {
        for (auto &w : st.wires) w.selected = false;
        st.selWire = -1;
      }
    }
  }

  if (!st.drawing && ImGui::IsMouseDragging(ImGuiMouseButton_Left)) {
    for (auto &c : st.comps)
      if (c->selected) { c->pos = snap2({mpos.x, mpos.y}); st.simulated = false; }
  }

  ImGui::End();
}

int main() {
  glfwInit();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  GLFWwindow *win = glfwCreateWindow(1100, 700, "Éditeur de Circuits", nullptr, nullptr);
  glfwMakeContextCurrent(win);
  glfwSwapInterval(1);

  IMGUI_CHECKVERSION();
  ImGui::CreateContext();
  ImGui::StyleColorsLight();
  ImGui_ImplGlfw_InitForOpenGL(win, true);
  ImGui_ImplOpenGL3_Init("#version 330");

  State state;

  while (!glfwWindowShouldClose(win)) {
    glfwPollEvents();
    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();
    runEditor(state);
    ImGui::Render();
    int W, H;
    glfwGetFramebufferSize(win, &W, &H);
    glViewport(0, 0, W, H);
    glClearColor(1, 1, 1, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
    glfwSwapBuffers(win);
  }

  ImGui_ImplOpenGL3_Shutdown();
  ImGui_ImplGlfw_Shutdown();
  ImGui::DestroyContext();
  glfwDestroyWindow(win);
  glfwTerminate();
}