#!/usr/bin/env python3
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

# ── Lecture ───────────────────────────────────────────────────────────────────

def read_2d(name):
    rows = list(csv.reader(io.StringIO(land[f"{name}_2d"])))
    v0_sol = float(rows[1][3])
    v1_sol = float(rows[1][4])
    data = [(float(r[0]), float(r[1]), float(r[2])) for r in rows[2:]]
    V0 = sorted(set(r[0] for r in data))
    V1 = sorted(set(r[1] for r in data))
    E  = np.zeros((len(V0), len(V1)))
    idx0 = {v: i for i, v in enumerate(V0)}
    idx1 = {v: i for i, v in enumerate(V1)}
    for v0, v1, e in data:
        E[idx0[v0], idx1[v1]] = e
    return np.array(V0), np.array(V1), E, v0_sol, v1_sol

def read_trajectory(circuit, solver):
    rows = list(csv.DictReader(io.StringIO(conv[f"{circuit}_{solver}"])))
    V0  = np.array([float(r["V0"])    for r in rows])
    V1  = np.array([float(r["V1"])    for r in rows])
    Err = np.array([float(r["error"]) for r in rows])
    return V0, V1, Err

def subsample_traj(V0, V1, Err, n):
    if len(V0) <= n: return V0, V1, Err
    idx = np.round(np.linspace(0, len(V0) - 1, n)).astype(int)
    return V0[idx], V1[idx], Err[idx]

def prepare_surface(name, log_scale, clip_pct, swap_axes):
    V0, V1, E, v0_sol, v1_sol = read_2d(name)
    V0g, V1g = np.meshgrid(V0, V1, indexing="ij")
    if swap_axes:
        V0g, V1g = V1g, V0g
        v0_sol, v1_sol = v1_sol, v0_sol
    if log_scale:
        E_vis = np.log10(np.clip(E, 1e-20, None))
        z_sol = np.log10(1e-20)
        zlabel = "log10(E)"
    else:
        E_vis = np.clip(E, 0, np.percentile(E, clip_pct))
        z_sol = 0.0
        zlabel = "Erreur KCL"
    return V0g, V1g, E_vis, v0_sol, v1_sol, z_sol, zlabel

def prepare_traj(circuit, solver, n_frames, log_scale, swap_axes):
    tv0, tv1, terr = read_trajectory(circuit, solver)
    tv0, tv1, terr = subsample_traj(tv0, tv1, terr, n_frames)
    if swap_axes:
        tv0, tv1 = tv1, tv0
    te = np.log10(np.clip(terr, 1e-20, None)) if log_scale else terr
    return tv0, tv1, te

# ── GIF chemin double (Newton + gradient) ─────────────────────────────────────

def make_combined_gif(circuit, title, xlabel, ylabel, outname,
                      log_scale=True, clip_pct=85, swap_axes=True,
                      n_frames=90, fps=10, n_hold=15, azim=-60, elev=28):

    V0g, V1g, E_vis, v0_sol, v1_sol, z_sol, zlabel = prepare_surface(
        circuit, log_scale, clip_pct, swap_axes)

    nv0, nv1, ne = prepare_traj(circuit, "newton",   20, log_scale, swap_axes)
    gv0, gv1, ge = prepare_traj(circuit, "numerical", n_frames, log_scale, swap_axes)

    total = n_frames + n_hold

    fig = plt.figure(figsize=(8, 6))
    ax  = fig.add_subplot(111, projection="3d")
    fig.suptitle(title, fontsize=11, fontweight="bold")

    ax.plot_surface(V0g, V1g, E_vis, cmap="viridis",
                    alpha=0.65, rcount=50, ccount=50, linewidth=0)
    ax.scatter([v0_sol], [v1_sol], [z_sol], color="red",
               s=70, zorder=10, label="solution")
    ax.set_xlabel(xlabel, fontsize=8)
    ax.set_ylabel(ylabel, fontsize=8)
    ax.set_zlabel(zlabel, fontsize=8)
    ax.tick_params(labelsize=7)
    ax.view_init(elev=elev, azim=azim)
    if swap_axes and circuit == "wheatstone":
        ax.invert_yaxis()

    newton_trail,   = ax.plot([], [], [], color="#64B5F6", linewidth=2.0, alpha=0.9, label="Newton-Raphson")
    gradient_trail, = ax.plot([], [], [], color="#FFB300", linewidth=1.5, alpha=0.9, label="Gradient numerique")
    newton_pt  = ax.scatter([], [], [], color="#1565C0", s=90, depthshade=False, zorder=10)
    gradient_pt= ax.scatter([], [], [], color="#E65100", s=90, depthshade=False, zorder=10)
    info_text  = ax.text2D(0.02, 0.95, "", transform=ax.transAxes, fontsize=8)
    ax.legend(fontsize=7, loc="upper right")

    def update(frame):
        kn = min(frame, len(nv0) - 1)
        kg = min(frame, len(gv0) - 1)
        newton_trail.set_data(nv0[:kn+1], nv1[:kn+1])
        newton_trail.set_3d_properties(ne[:kn+1])
        newton_pt._offsets3d = ([nv0[kn]], [nv1[kn]], [ne[kn]])
        gradient_trail.set_data(gv0[:kg+1], gv1[:kg+1])
        gradient_trail.set_3d_properties(ge[:kg+1])
        gradient_pt._offsets3d = ([gv0[kg]], [gv1[kg]], [ge[kg]])
        info_text.set_text(f"gradient iter {kg}  |  newton iter {kn}")
        return newton_trail, gradient_trail, newton_pt, gradient_pt, info_text

    ani = FuncAnimation(fig, update, frames=total, interval=1000 // fps, blit=False)
    out = PLOT_DIR / outname
    ani.save(out, writer=PillowWriter(fps=fps))
    plt.close(fig)
    print(f"  → {out}  ({total} frames, {fps} fps)")

# ── GIF rotatif ───────────────────────────────────────────────────────────────

def make_rotating_gif(name, title, xlabel, ylabel, log_scale, clip_pct, outname,
                      n_frames=120, fps=24, elev=28, swap_axes=False, invert_y=False):
    V0g, V1g, E_vis, v0_sol, v1_sol, z_sol, zlabel = prepare_surface(
        name, log_scale, clip_pct, swap_axes)

    fig = plt.figure(figsize=(7, 6))
    ax  = fig.add_subplot(111, projection="3d")
    fig.suptitle(title, fontsize=11, fontweight="bold")
    ax.plot_surface(V0g, V1g, E_vis, cmap="viridis",
                    alpha=0.85, rcount=60, ccount=60, linewidth=0)
    ax.scatter([v0_sol], [v1_sol], [z_sol], color="red", s=60, zorder=10, label="solution")
    ax.set_xlabel(xlabel, fontsize=8)
    ax.set_ylabel(ylabel, fontsize=8)
    ax.set_zlabel(zlabel, fontsize=8)
    ax.legend(fontsize=8)
    ax.tick_params(labelsize=7)
    if invert_y:
        ax.invert_yaxis()

    def update(frame):
        ax.view_init(elev=elev, azim=frame * 360 / n_frames)
        return fig,

    ani = FuncAnimation(fig, update, frames=n_frames, interval=1000 // fps, blit=False)
    out = PLOT_DIR / outname
    ani.save(out, writer=PillowWriter(fps=fps))
    plt.close(fig)
    print(f"  → {out}  ({n_frames} frames, {fps} fps)")

# ── Appels ────────────────────────────────────────────────────────────────────

make_combined_gif(
    circuit="wheatstone",
    title="Newton-Raphson vs Gradient — Pont de Wheatstone",
    xlabel="V_D (V)", ylabel="V_B (V)",
    outname="combined_wheatstone.gif",
    log_scale=False, clip_pct=92, swap_axes=True,
    n_frames=25, fps=1, n_hold=8,
)

make_combined_gif(
    circuit="bjt",
    title="Newton-Raphson vs Gradient — BJT",
    xlabel="V_col (V)", ylabel="V_base (V)",
    outname="combined_bjt.gif",
    log_scale=True, clip_pct=85, swap_axes=True,
    n_frames=90, fps=10, n_hold=15, azim=-40,
)

make_rotating_gif(
    name="wheatstone", title="Pont de Wheatstone — rotation",
    xlabel="V_D (V)", ylabel="V_B (V)",
    log_scale=False, clip_pct=92,
    outname="rotate_wheatstone.gif",
    swap_axes=True, invert_y=True,
    n_frames=120, fps=12,
)

make_rotating_gif(
    name="bjt", title="Transistor BJT — rotation",
    xlabel="V_col (V)", ylabel="V_base (V)",
    log_scale=True, clip_pct=85,
    outname="rotate_bjt.gif",
    swap_axes=True,
    n_frames=120, fps=12,
)

print("Termine.")
