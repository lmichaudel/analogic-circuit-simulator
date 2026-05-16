#include "solver.hpp"
#include "circuit.hpp"
#include <cmath>
#include <vector>
#include <algorithm>
#include <unordered_map>

using namespace solver;

// -- Utilitaires --------------------------------------------------------------

static double norme(const std::vector<double>& v) {
    double somme = 0.0;
    for (double x : v) somme += x * x;
    return std::sqrt(somme);
}

static double erreur_kcl_totale(Circuit& circuit,
                                const std::vector<std::shared_ptr<Wire>>& fils_libres) {
    double somme = 0.0;
    for (auto& fil : fils_libres) {
        double e = circuit.kcl_error(fil);
        somme += e * e;
    }
    return somme;
}

// -- Assemblage de la jacobienne globale --------------------------------------
// J_global[i][j] = d(erreur_KCL_i) / d(V_fil_libre_j)
// On parcourt chaque composant, on recupere sa jacobienne locale,
// et on accumule ses contributions dans la jacobienne globale
// via la correspondance pin -> indice de fil libre.

static std::vector<std::vector<double>> assembler_jacobienne(
        Circuit& circuit,
        const std::vector<std::shared_ptr<Wire>>& fils_libres)
{
    int n = static_cast<int>(fils_libres.size());
    std::vector<std::vector<double>> J(n, std::vector<double>(n, 0.0));

    std::unordered_map<Wire*, int> indice_fil;
    indice_fil.reserve(n);
    for (int i = 0; i < n; ++i)
        indice_fil[fils_libres[i].get()] = i;

    for (auto& comp : circuit.get_components()) {
        auto J_local = comp->jacobian();
        int nb_pins = static_cast<int>(comp->pin_count());
        for (int k = 0; k < nb_pins; ++k) {
            Wire* fil_k = comp->get_pin(k).wire.get();
            auto it_k = indice_fil.find(fil_k);
            if (it_k == indice_fil.end()) continue;
            int i = it_k->second;
            for (int l = 0; l < nb_pins; ++l) {
                Wire* fil_l = comp->get_pin(l).wire.get();
                auto it_l = indice_fil.find(fil_l);
                if (it_l == indice_fil.end()) continue;
                int j = it_l->second;
                J[i][j] += J_local[k][l];
            }
        }
    }
    return J;
}

// -- Resolution du systeme lineaire A*x = b (elimination de Gauss-Jordan) ----

static std::vector<double> gauss(
        std::vector<std::vector<double>> A,
        std::vector<double> b) {
    int n = static_cast<int>(b.size());
    for (int col = 0; col < n; ++col) {
        // recherche du pivot le plus grand en valeur absolue
        int pivot = col;
        for (int ligne = col + 1; ligne < n; ++ligne)
            if (std::abs(A[ligne][col]) > std::abs(A[pivot][col])) pivot = ligne;
        std::swap(A[col], A[pivot]);
        std::swap(b[col], b[pivot]);

        double diag = A[col][col];
        if (std::abs(diag) < 1e-14) continue;

        for (int j = col; j < n; ++j) A[col][j] /= diag;
        b[col] /= diag;

        for (int ligne = 0; ligne < n; ++ligne) {
            if (ligne == col) continue;
            double facteur = A[ligne][col];
            for (int j = col; j < n; ++j) A[ligne][j] -= facteur * A[col][j];
            b[ligne] -= facteur * b[col];
        }
    }
    return b;
}

// -- Newton-Raphson -----------------------------------------------------------

NewtonRaphson::NewtonRaphson(double epsilon, int max_iter, double v_max_step, double V_init)
    : epsilon(epsilon), max_iter(max_iter), v_max_step(v_max_step), V_init(V_init) {}

void NewtonRaphson::solve(Circuit& circuit) {
    circuit.init_potentials(V_init);
    iter_count_ = 0;
    if (recording_) history_.clear();

    auto fils = circuit.free_wires();
    int n = static_cast<int>(fils.size());

    if (n == 0) {
        circuit.compute_currents();
        return;
    }

    for (int iter = 0; iter < max_iter; ++iter) {
        circuit.compute_currents();

        std::vector<double> F(n);
        for (int i = 0; i < n; ++i)
            F[i] = circuit.kcl_error(fils[i]);

        double E = 0.0;
        for (int i = 0; i < n; ++i) E += F[i] * F[i];

        if (recording_) {
            IterStep s;
            for (auto& w : fils) s.potentials.push_back(w->potential);
            s.error = E;
            history_.push_back(s);
        }

        ++iter_count_;
        if (norme(F) < epsilon) break;

        auto J = assembler_jacobienne(circuit, fils);

        // on resout J * delta_V = -F
        std::vector<double> moins_F(n);
        for (int i = 0; i < n; ++i) moins_F[i] = -F[i];
        std::vector<double> delta = gauss(J, moins_F);

        // on limite la correction pour eviter les divergences sur les diodes/transistors
        for (int j = 0; j < n; ++j)
            delta[j] = std::max(-v_max_step, std::min(v_max_step, delta[j]));

        for (int j = 0; j < n; ++j)
            fils[j]->potential += delta[j];

        if (norme(delta) < 1e-12) break;
    }

    circuit.compute_currents();
}

// -- SimpleResolver -----------------------------------------------------------

SimpleResolver::SimpleResolver(double step, double epsilon, int max_iter, double V_init)
    : step(step), epsilon(epsilon), max_iter(max_iter), V_init(V_init) {}

void SimpleResolver::solve(Circuit& circuit) {
    circuit.init_potentials(V_init);
    iter_count_ = 0;
    if (recording_) history_.clear();

    auto fils = circuit.free_wires();
    int n = static_cast<int>(fils.size());

    if (n == 0) {
        circuit.compute_currents();
        return;
    }

    for (int iter = 0; iter < max_iter; ++iter) {
        circuit.compute_currents();

        double erreur_base = erreur_kcl_totale(circuit, fils);

        if (recording_) {
            IterStep s;
            for (auto& w : fils) s.potentials.push_back(w->potential);
            s.error = erreur_base;
            history_.push_back(s);
        }

        ++iter_count_;
        if (erreur_base < epsilon) break;

        for (int j = 0; j < n; ++j) {
            circuit.compute_currents();
            double erreur_avant = erreur_kcl_totale(circuit, fils);

            fils[j]->potential += step;
            circuit.compute_currents();
            if (erreur_kcl_totale(circuit, fils) < erreur_avant) continue;

            fils[j]->potential -= 2.0 * step;
            circuit.compute_currents();
            if (erreur_kcl_totale(circuit, fils) < erreur_avant) continue;

            fils[j]->potential += step;  // restitution du potentiel initial
        }
    }

    circuit.compute_currents();
}

// -- GradientDescent (gradient analytique) ------------------------------------
// Le gradient de E = somme(F_i^2) s'obtient par la regle des derivees en chaine :
// dE/dV_j = 2 * somme_i( F_i * J[i][j] )
// Le pas est adaptatif : si le deplacement augmente l'erreur, on le divise par 2
// jusqu'a trouver un pas qui fait vraiment descendre E (backtracking).

GradientDescent::GradientDescent(double step, double epsilon, int max_iter, double V_init)
    : step(step), epsilon(epsilon), max_iter(max_iter), V_init(V_init) {}

void GradientDescent::solve(Circuit& circuit) {
    circuit.init_potentials(V_init);
    iter_count_ = 0;

    auto fils = circuit.free_wires();
    int n = static_cast<int>(fils.size());

    if (n == 0) {
        circuit.compute_currents();
        return;
    }

    for (int iter = 0; iter < max_iter; ++iter) {
        circuit.compute_currents();

        std::vector<double> F(n);
        for (int i = 0; i < n; ++i)
            F[i] = circuit.kcl_error(fils[i]);

        double E = 0.0;
        for (int i = 0; i < n; ++i) E += F[i] * F[i];

        if (recording_) {
            IterStep s;
            for (auto& w : fils) s.potentials.push_back(w->potential);
            s.error = E;
            history_.push_back(s);
        }

        ++iter_count_;
        if (E < epsilon) break;

        auto J = assembler_jacobienne(circuit, fils);

        std::vector<double> gradient(n, 0.0);
        for (int j = 0; j < n; ++j)
            for (int i = 0; i < n; ++i)
                gradient[j] += 2.0 * F[i] * J[i][j];

        // backtracking : on divise le pas par 2 tant que l'erreur n'a pas diminue
        std::vector<double> V0(n);
        for (int j = 0; j < n; ++j) V0[j] = fils[j]->potential;

        double pas = step;
        for (int k = 0; k < 50; ++k) {
            for (int j = 0; j < n; ++j)
                fils[j]->potential = V0[j] - pas * gradient[j];
            circuit.compute_currents();
            double E_nouveau = erreur_kcl_totale(circuit, fils);
            if (E_nouveau < E) break;
            pas *= 0.5;
        }
    }

    circuit.compute_currents();
}

// -- NumericalGradientDescent (gradient numerique par differences finies) -----
// On estime chaque composante du gradient en perturbant le potentiel d'un fil :
// dE/dV_j ~ (E(V_j + dx) - E(V)) / dx
// Tous les gradients sont calcules depuis le meme etat de reference (batch),
// puis tous les potentiels sont mis a jour en une seule fois.

NumericalGradientDescent::NumericalGradientDescent(
        double step, double epsilon, int max_iter, double dx, double V_init)
    : step(step), epsilon(epsilon), max_iter(max_iter), dx(dx), V_init(V_init) {}

void NumericalGradientDescent::solve(Circuit& circuit) {
    circuit.init_potentials(V_init);
    iter_count_ = 0;

    auto fils = circuit.free_wires();
    int n = static_cast<int>(fils.size());

    if (n == 0) {
        circuit.compute_currents();
        return;
    }

    for (int iter = 0; iter < max_iter; ++iter) {
        circuit.compute_currents();

        double E = erreur_kcl_totale(circuit, fils);

        if (recording_) {
            IterStep s;
            for (auto& w : fils) s.potentials.push_back(w->potential);
            s.error = E;
            history_.push_back(s);
        }

        ++iter_count_;
        if (E < epsilon) break;

        // sauvegarde de l'etat de reference avant toute perturbation
        std::vector<double> V0(n), gradient(n);
        for (int j = 0; j < n; ++j) V0[j] = fils[j]->potential;

        for (int j = 0; j < n; ++j) {
            fils[j]->potential = V0[j] + dx;
            circuit.compute_currents();
            gradient[j] = (erreur_kcl_totale(circuit, fils) - E) / dx;
            fils[j]->potential = V0[j];  // restauration avant le fil suivant
        }

        // backtracking : on divise le pas par 2 tant que l'erreur n'a pas diminue
        double pas = step;
        for (int k = 0; k < 50; ++k) {
            for (int j = 0; j < n; ++j)
                fils[j]->potential = V0[j] - pas * gradient[j];
            circuit.compute_currents();
            double E_nouveau = erreur_kcl_totale(circuit, fils);
            if (E_nouveau < E) break;
            pas *= 0.5;
        }
    }

    circuit.compute_currents();
}
