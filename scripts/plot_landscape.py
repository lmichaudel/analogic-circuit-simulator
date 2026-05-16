#!/usr/bin/env python3
import io, csv, subprocess
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401
from pathlib import Path

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

secs = run(Path("build") / "landscape.o")

# ── Lecture ───────────────────────────────────────────────────────────────────

def read_1d(name):
    rows = list(csv.reader(io.StringIO(secs[f"{name}_1d"])))
    v_sol = float(rows[1][3])
    V, E  = [], []
    for row in rows[2:]:
        V.append(float(row[0]))
        E.append(float(row[1]))
    return np.array(V), np.array(E), v_sol

def read_2d(name):
    rows = list(csv.reader(io.StringIO(secs[f"{name}_2d"])))
    v0_sol = float(rows[1][3])
    v1_sol = float(rows[1][4])
    data = []
    for row in rows[2:]:
        data.append((float(row[0]), float(row[1]), float(row[2])))
    V0 = sorted(set(r[0] for r in data))
    V1 = sorted(set(r[1] for r in data))
    E  = np.zeros((len(V0), len(V1)))
    idx0 = {v: i for i, v in enumerate(V0)}
    idx1 = {v: i for i, v in enumerate(V1)}
    for v0, v1, e in data:
        E[idx0[v0], idx1[v1]] = e
    return np.array(V0), np.array(V1), E, v0_sol, v1_sol

# ── Plots 1D ──────────────────────────────────────────────────────────────────

cases_1d = [
    ("chained",       "Paysage KCL — Resistances en serie",  "V_w2 (V)",  False),
    ("diode_forward", "Paysage KCL — Diode passante",         "V_w2 (V)",  True),
    ("diode_clamp",   "Paysage KCL — Diode eclateur",         "V_w2 (V)",  True),
]

for name, title, xlabel, log_scale in cases_1d:
    V, E, v_sol = read_1d(name)
    fig, ax = plt.subplots(figsize=(7, 5))
    ax.set_title(title, fontsize=12, fontweight="bold")
    if log_scale:
        ax.semilogy(V, np.clip(E, 1e-25, None), color="black", linewidth=2)
        ax.set_ylabel("Erreur KCL  E(V)  [log]", fontsize=10)
    else:
        ax.plot(V, E, color="black", linewidth=2)
        ax.set_ylabel("Erreur KCL  E(V)", fontsize=10)
    ax.axvline(v_sol, color="red", linestyle="--", linewidth=1.5,
               label=f"solution : {v_sol:.3f} V")
    ax.set_xlabel(xlabel, fontsize=10)
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3, which="both" if log_scale else "major")
    plt.tight_layout()
    out = PLOT_DIR / f"landscape_1d_{name}.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  → {out}")

# ── Plots 2D ──────────────────────────────────────────────────────────────────

cases_2d = [
    ("wheatstone", "Paysage KCL — Pont de Wheatstone",  "V_D (V)", "V_B (V)", False, 92,  True),
    ("bjt",        "Paysage KCL — Transistor BJT",       "V_col (V)", "V_base (V)", True, 85, False),
]

for name, title, xlabel, ylabel, log_scale, clip_pct, invert_y in cases_2d:
    V0, V1, E, v0_sol, v1_sol = read_2d(name)
    V0g, V1g = np.meshgrid(V0, V1, indexing="ij")
    V0g, V1g   = V1g, V0g
    v0_sol, v1_sol = v1_sol, v0_sol
    if log_scale:
        E_vis  = np.log10(np.clip(E, 1e-20, None))
        zlabel = "log10(E)"
        z_sol  = np.log10(1e-20)
    else:
        E_vis  = np.clip(E, 0, np.percentile(E, clip_pct))
        zlabel = "Erreur KCL"
        z_sol  = 0.0
    fig = plt.figure(figsize=(8, 6))
    ax  = fig.add_subplot(111, projection="3d")
    ax.set_title(title, fontsize=12, fontweight="bold")
    ax.plot_surface(V0g, V1g, E_vis, cmap="viridis",
                    alpha=0.85, rcount=60, ccount=60, linewidth=0)
    ax.scatter([v0_sol], [v1_sol], [z_sol], color="red", s=60, zorder=10, label="solution")
    ax.set_xlabel(xlabel, fontsize=9)
    ax.set_ylabel(ylabel, fontsize=9)
    ax.set_zlabel(zlabel, fontsize=9)
    ax.legend(fontsize=9)
    ax.tick_params(labelsize=7)
    if invert_y:
        ax.invert_yaxis()
    plt.tight_layout()
    out = PLOT_DIR / f"landscape_2d_{name}.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  → {out}")

print("Termine.")
