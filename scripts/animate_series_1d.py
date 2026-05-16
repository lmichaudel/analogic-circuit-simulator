#!/usr/bin/env python3
"""
Animation 1D — descente de gradient sur E(V)
Circuit : résistances en série  VS=5V  R1=R2=1Ω  (nœud libre V_w2)
Output  : plots/gradient_series_1d.gif
"""

import io, csv, subprocess
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
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

land = run(Path("build") / "landscape.o")
conv = run(Path("build") / "benchmark.o")

# ── données ────────────────────────────────────────────────────────────────────

rows_1d = list(csv.reader(io.StringIO(land["chained_1d"])))
v_sol   = float(rows_1d[1][3])
V_land  = np.array([float(r[0]) for r in rows_1d[2:]])
E_land  = np.array([float(r[1]) for r in rows_1d[2:]])
dEdV    = np.gradient(E_land, V_land)

rows_gd = list(csv.DictReader(io.StringIO(conv["chained_gradient"])))
gv      = np.array([float(r["V0"])    for r in rows_gd])
gerr    = np.array([float(r["error"]) for r in rows_gd])

N_ITER = len(gv)
N_SUB  = 12
N_HOLD = 18
FPS    = 15
total  = 2 * N_HOLD + N_ITER * N_SUB

# ── figure ─────────────────────────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(9, 6))
fig.subplots_adjust(left=0.1, right=0.97, top=0.88, bottom=0.11)
ax.set_title("Paysage KCL — Résistances en série\ndescente de gradient animée",
             fontsize=13, fontweight="bold")
ax.plot(V_land, E_land, color="black", linewidth=2.5, zorder=2, label="E(V)")
ax.axvline(v_sol, color="red", linestyle="--", linewidth=1.5,
           label=f"solution : {v_sol:.3f} V", zorder=3)
ax.set_xlabel("V_w2  (V)", fontsize=12)
ax.set_ylabel("Erreur KCL  E(V)", fontsize=12)
ax.set_xlim(V_land[0], V_land[-1])
ax.set_ylim(-0.8, E_land.max() * 1.06)
ax.grid(True, alpha=0.3)
ax.legend(fontsize=10, loc="upper right")

TANG_W = 0.45

point,   = ax.plot([], [], "o",  color="#FF6D00", markersize=11, zorder=10)
vline,   = ax.plot([], [], ":",  color="#FF6D00", linewidth=1.5, alpha=0.55, zorder=5)
tangent, = ax.plot([], [], "-",  color="#1565C0", linewidth=2.2, alpha=0.9,  zorder=8)
tang_lbl  = ax.text(0, 0, "", color="#1565C0", fontsize=9, ha="left", zorder=12)
info      = ax.text(0.02, 0.97, "", transform=ax.transAxes, fontsize=10,
                    va="top", bbox=dict(boxstyle="round,pad=0.4",
                                        facecolor="lightyellow", alpha=0.85))
arrows = []

def make_arrow(x0, y0, x1, y1, color, alpha=1.0):
    return ax.annotate(
        "", xy=(x1, y1), xytext=(x0, y0),
        arrowprops=dict(arrowstyle="-|>", color=color, lw=2.5,
                        mutation_scale=18, alpha=alpha),
        zorder=11,
    )

def update(frame):
    for a in arrows:
        a.remove()
    arrows.clear()

    f = frame - N_HOLD
    if f < 0:
        k, t = 0, 0.0
    elif f >= N_ITER * N_SUB:
        k, t = N_ITER - 1, 1.0
    else:
        k = f // N_SUB
        t = (f % N_SUB) / N_SUB

    v_end = gv[k + 1] if k < N_ITER - 1 else gv[k]
    v_cur = gv[k] + t * (v_end - gv[k])
    e_cur = float(np.interp(v_cur, V_land, E_land))
    slope = float(np.interp(v_cur, V_land, dEdV))

    point.set_data([v_cur], [e_cur])
    vline.set_data([v_cur, v_cur], [0, e_cur])

    tang_alpha = 1.0 - t * 0.9
    tv = np.array([v_cur - TANG_W, v_cur + TANG_W])
    te = e_cur + slope * (tv - v_cur)
    tangent.set_data(tv, te)
    tangent.set_alpha(tang_alpha)

    lbl_x = v_cur + TANG_W * np.sign(slope) * 0.6
    lbl_y = e_cur + slope * TANG_W * np.sign(slope) * 0.6 + 0.4
    tang_lbl.set_position((lbl_x, lbl_y))
    tang_lbl.set_text("∇E" if tang_alpha > 0.3 else "")
    tang_lbl.set_alpha(tang_alpha)

    if k < N_ITER - 1 and t < 0.95:
        step_alpha = 1.0 - t
        v_step_end = v_cur + (1 - t) * (v_end - gv[k])
        arrows.append(make_arrow(v_cur, e_cur, v_step_end, e_cur,
                                 color="#E53935", alpha=step_alpha))
        if t < 0.35:
            mid = (v_cur + v_step_end) / 2
            arrows.append(ax.text(mid, e_cur + 0.5, "−α∇E",
                                  color="#E53935", fontsize=9, ha="center",
                                  zorder=12, alpha=step_alpha))

    info.set_text(
        f"itération : {k}\n"
        f"V = {v_cur:.4f} V\n"
        f"dE/dV = {slope:+.3f}"
    )
    return point, vline, tangent, tang_lbl, info

ani = FuncAnimation(fig, update, frames=total, interval=1000 // FPS, blit=False)
out = PLOT_DIR / "gradient_series_1d.gif"
ani.save(out, writer=PillowWriter(fps=FPS))
plt.close(fig)
print(f"  → {out}  ({total} frames, {FPS} fps)")
print("Terminé.")
