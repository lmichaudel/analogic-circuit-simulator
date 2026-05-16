#!/usr/bin/env python3
import io, csv, subprocess
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from collections import defaultdict

PLOT_DIR = Path("plots")
PLOT_DIR.mkdir(exist_ok=True)

# ── pipeline ──────────────────────────────────────────────────────────────────

def run(binary):
    r = subprocess.run([str(binary)], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr)
    sections = {}
    cur, lines = None, []
    for line in r.stdout.splitlines():
        if line.startswith("---BEGIN "):
            cur, lines = line[9:], []
        elif line == "---END":
            if cur is not None:
                sections[cur] = "\n".join(lines)
            cur = None
        elif cur is not None:
            lines.append(line)
    return sections

secs = run(Path("build") / "benchmark.o")

# ── lecture ───────────────────────────────────────────────────────────────────

SOLVERS  = ["newton", "simple", "gradient", "numerical"]
CIRCUITS = ["chained", "wheatstone", "diode_forward", "diode_clamp", "bjt"]

CIRCUIT_LABELS = {
    "chained":       "Resistances\nen serie",
    "wheatstone":    "Pont de\nWheatstone",
    "diode_forward": "Diode\npassante",
    "diode_clamp":   "Diode\neclateur",
    "bjt":           "Transistor\nBJT",
}
SOLVER_COLORS = {
    "newton":    "#1565C0",
    "simple":    "#2E7D32",
    "gradient":  "#F57F17",
    "numerical": "#AD1457",
}
SOLVER_STYLES = {
    "newton":    "-",
    "simple":    "-",
    "gradient":  "--",
    "numerical": "-",
}

data = defaultdict(dict)
for row in csv.DictReader(io.StringIO(secs["metrics"])):
    data[row["circuit"]][row["solver"]] = {
        "iter":  int(row["iterations"]),
        "time":  float(row["time_us"]),
        "error": float(row["final_error"]),
        "conv":  row["converged"] == "true",
    }

def read_conv(circuit, solver):
    key = f"{circuit}_{solver}"
    if key not in secs:
        return None, None
    steps, errors = [], []
    for row in csv.DictReader(io.StringIO(secs[key])):
        steps.append(int(row["step"]))
        errors.append(float(row["error"]))
    return steps, errors

# ── barres groupées ───────────────────────────────────────────────────────────

x       = np.arange(len(CIRCUITS))
w       = 0.2
offsets = np.array([-1.5, -0.5, 0.5, 1.5]) * w

bar_metrics = [
    ("iter",  "perf_iterations.png", "Nombre d'iterations", "Iterations (/// = non converge)"),
    ("time",  "perf_time.png",       "Temps de calcul (µs)", "Temps de calcul"),
    ("error", "perf_error.png",      "Erreur KCL finale",    "Erreur KCL finale"),
]

for key, fname, ylabel, title in bar_metrics:
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.set_title(title, fontsize=12, fontweight="bold")
    for i, solver in enumerate(SOLVERS):
        vals, hatches = [], []
        for circ in CIRCUITS:
            d = data[circ].get(solver)
            v = d[key] if d else 0
            if v <= 0: v = 1e-20
            vals.append(v)
            hatches.append("" if (d and d["conv"]) else "///")
        bars = ax.bar(x + offsets[i], vals, width=w,
                      label=solver, color=SOLVER_COLORS[solver], alpha=0.85)
        for bar, h in zip(bars, hatches):
            if h:
                bar.set_hatch(h)
                bar.set_edgecolor("black")
    ax.set_yscale("log")
    ax.set_xticks(x)
    ax.set_xticklabels([CIRCUIT_LABELS[c] for c in CIRCUITS], fontsize=9)
    ax.set_ylabel(ylabel, fontsize=10)
    ax.grid(True, axis="y", alpha=0.3)
    ax.legend(fontsize=9)
    plt.tight_layout()
    out = PLOT_DIR / fname
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  → {out}")

# ── courbes de convergence ────────────────────────────────────────────────────

def subsample(steps, errors, n=2000):
    if len(steps) <= n: return steps, errors
    idx = [int(i * (len(steps) - 1) / (n - 1)) for i in range(n)]
    return [steps[i] for i in idx], [errors[i] for i in idx]

CIRCUIT_TITLES = {
    "chained":       "Convergence — Resistances en serie",
    "wheatstone":    "Convergence — Pont de Wheatstone",
    "diode_forward": "Convergence — Diode passante",
    "diode_clamp":   "Convergence — Diode eclateur",
    "bjt":           "Convergence — Transistor BJT",
}

for circ in CIRCUITS:
    fig, ax = plt.subplots(figsize=(7, 5))
    ax.set_title(CIRCUIT_TITLES[circ], fontsize=12, fontweight="bold")
    has_data = False
    for solver in ["newton", "simple", "numerical", "gradient"]:
        steps, errors = read_conv(circ, solver)
        if steps is None or len(steps) == 0: continue
        steps, errors = subsample(steps, errors)
        ax.plot(steps, errors,
                color=SOLVER_COLORS[solver],
                linestyle=SOLVER_STYLES[solver],
                linewidth=1.5, label=solver, alpha=0.9)
        has_data = True
    if has_data:
        ax.set_xscale("log")
        ax.set_yscale("log")
        ax.set_xlabel("Iteration", fontsize=10)
        ax.set_ylabel("Erreur KCL", fontsize=10)
        ax.legend(fontsize=9)
        ax.grid(True, alpha=0.3, which="both")
    plt.tight_layout()
    out = PLOT_DIR / f"convergence_{circ}.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  → {out}")

print("Termine.")
