#pragma once
#include <vector>

namespace solver {
    class Circuit;

    struct IterStep {
        std::vector<double> potentials;  // potentiels des fils libres a cette iteration
        double error;                    // erreur KCL totale
    };

    class Solver {
    public:
        virtual void solve(Circuit& circuit) = 0;
        virtual ~Solver() = default;

        virtual void set_recording(bool) {}
        virtual const std::vector<IterStep>& get_history() const {
            static const std::vector<IterStep> empty;
            return empty;
        }
        // nombre d'iterations reellement effectuees lors du dernier solve()
        virtual int get_iter_count() const { return 0; }
    };

    class SimpleResolver : public Solver {
        double step;
        double epsilon;
        int    max_iter;
        double V_init;
        std::vector<IterStep> history_;
        bool   recording_ = false;
        int    iter_count_ = 0;
    public:
        SimpleResolver(
            double step     = 0.01,
            double epsilon  = 1e-6,
            int    max_iter = 100000,
            double V_init   = 0.0);

        void solve(Circuit& circuit) override;
        void set_recording(bool r) override { recording_ = r; if (r) history_.clear(); }
        const std::vector<IterStep>& get_history() const override { return history_; }
        int get_iter_count() const override { return iter_count_; }
    };

    // Utilise les jacobiennes analytiques de chaque composant.
    class NewtonRaphson : public Solver {
        double epsilon;
        int    max_iter;
        double v_max_step;
        double V_init;
        std::vector<IterStep> history_;
        bool   recording_ = false;
        int    iter_count_ = 0;
    public:
        NewtonRaphson(
            double epsilon    = 1e-8,
            int    max_iter   = 100,
            double v_max_step = 0.1, // le baisser pour des transistors!
            double V_init     = 0.0);

        void solve(Circuit& circuit) override;
        void set_recording(bool r) override { recording_ = r; if (r) history_.clear(); }
        const std::vector<IterStep>& get_history() const override { return history_; }
        int get_iter_count() const override { return iter_count_; }
    };

    // Gradient calcule analytiquement via les jacobiennes des composants.
    class GradientDescent : public Solver {
        double step;
        double epsilon;
        int    max_iter;
        double V_init;
        std::vector<IterStep> history_;
        bool recording_ = false;
        int  iter_count_ = 0;
    public:
        GradientDescent(
            double step     = 10.0,
            double epsilon  = 1e-8,
            int    max_iter = 100000,
            double V_init   = 0.0);

        void solve(Circuit& circuit) override;
        void set_recording(bool r) override { recording_ = r; if (r) history_.clear(); }
        const std::vector<IterStep>& get_history() const override { return history_; }
        int get_iter_count() const override { return iter_count_; }
    };

    // Gradient estime par differences finies : (E(V+dx) - E(V)) / dx.
    class NumericalGradientDescent : public Solver {
        double step;
        double epsilon;
        int    max_iter;
        double dx;
        double V_init;
        std::vector<IterStep> history_;
        bool recording_ = false;
        int  iter_count_ = 0;
    public:
        NumericalGradientDescent(
            double step     = 10.0,
            double epsilon  = 1e-8,
            int    max_iter = 100000,
            double dx       = 1e-6,
            double V_init   = 0.0);

        void solve(Circuit& circuit) override;
        void set_recording(bool r) override { recording_ = r; if (r) history_.clear(); }
        const std::vector<IterStep>& get_history() const override { return history_; }
        int get_iter_count() const override { return iter_count_; }
    };
}
