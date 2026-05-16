#!/usr/bin/env python3
import io, csv, subprocess
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
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

secs = run(Path("build") / "rc_transient.o")
rows = list(csv.DictReader(io.StringIO(secs["rc_transient"])))

# ── données ───────────────────────────────────────────────────────────────────

time_ms = np.array([float(r["time_us"]) / 1000 for r in rows])
cols = {k: np.array([float(r[k]) for r in rows])
        for k in rows[0] if k != "time_us"}

TAU_MS = 1.0
VS     = 5.0

SOLVERS = [
    ("analytical", dict(color="black",   lw=2.5, ls="--",  label="Analytique  VS·(1−e^{−t/τ})", zorder=5)),
    ("newton",     dict(color="#1565C0", lw=2.0, ls="-",   label="Newton-Raphson",               zorder=4)),
    ("gradient",   dict(color="#FFB300", lw=1.8, ls="-",   label="Gradient analytique",          zorder=3)),
    ("numerical",  dict(color="#E53935", lw=1.5, ls=":",   label="Gradient numérique",           zorder=3)),
    ("simple",     dict(color="#43A047", lw=1.5, ls="-.",  label="Simple Resolver",              zorder=3)),
]
ITER_COLORS = {
    "iter_newton":    "#1565C0",
    "iter_gradient":  "#FFB300",
    "iter_numerical": "#E53935",
    "iter_simple":    "#43A047",
}
ITER_LABELS = {
    "iter_newton":    "Newton-Raphson",
    "iter_gradient":  "Gradient analytique",
    "iter_numerical": "Gradient numérique",
    "iter_simple":    "Simple Resolver",
}

# ── figure ────────────────────────────────────────────────────────────────────

fig, ax1 = plt.subplots(figsize=(10, 5))
fig.suptitle("Réponse transitoire RC\nVS = 5 V   R = 1 kΩ   C = 1 µF   τ = 1 ms",
             fontsize=13, fontweight="bold")

for key, style in SOLVERS:
    ax1.plot(time_ms, cols[key], **style)

ax1.axvline(TAU_MS,     color="gray", ls=":", lw=1.2, alpha=0.7)
ax1.axvline(5 * TAU_MS, color="gray", ls=":", lw=1.0, alpha=0.4)
ax1.axhline(VS * (1 - 1/np.e), color="gray", ls=":", lw=1.0, alpha=0.5)
ax1.annotate("τ",    xy=(TAU_MS, 0.15),     color="gray", fontsize=10)
ax1.annotate("5τ",   xy=(5*TAU_MS - 0.15, 0.15), color="gray", fontsize=10, ha="right")
ax1.annotate(f"VS·(1−1/e) ≈ {VS*(1-1/np.e):.2f} V",
             xy=(TAU_MS + 0.06, VS * (1 - 1/np.e) + 0.1), color="gray", fontsize=9)
ax1.set_xlabel("t  (ms)", fontsize=11)
ax1.set_ylabel("V_mid  (V)", fontsize=11)
ax1.set_xlim(0, time_ms[-1])
ax1.set_ylim(-0.15, VS * 1.08)
ax1.legend(fontsize=9, loc="lower right")
ax1.grid(True, alpha=0.3)

fig.tight_layout()
out = PLOT_DIR / "rc_transient.png"
fig.savefig(out, dpi=150, bbox_inches="tight")
plt.close(fig)
print(f"  → {out}")
print("Terminé.")
