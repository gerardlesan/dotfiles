#!/usr/bin/env python3
"""Animated ASCII logos for fastfetch, rendered programmatically.

    art.py render SCENE CELL_W CELL_H     bake frames for one cell size into the cache
    art.py apng SCENE CELL_W CELL_H       pack baked frames into one animated PNG (native kitty animation)
    art.py text SCENE                     print one still frame as truecolor text (SSH)
    art.py preview SCENE                  play the scene as text in this terminal (Ctrl-C)

Each scene is a function of time t in [0, 1) that returns a light field: an
(H, W, 3) array of linear-ish RGB sampled at SX x SY points per terminal cell.
Every scene is exactly periodic in t, so the frames loop with no seam.

The field becomes ASCII by SHAPE, not just density: each cell's samples are
pooled into a REG_X x REG_Y grid of regions and compared against the same
grid measured off the real JetBrains Mono glyphs, so a planet's limb picks
`/` `(` `_` where a plain density ramp would pick `:` everywhere. The chosen
glyphs are then drawn in the field's own colour and given a glow, as an RGBA
image whose alpha is the light itself, so it composites onto any dark
background without a baked-in bg colour.

Frames are drawn at the terminal's MEASURED cell size (fetch.py reads it from
TIOCGWINSZ), never an estimated one, and the scene geometry is laid out in
physical pixels, so a planet is round at any cell aspect.
"""
import os, sys
import numpy as np
from PIL import Image, ImageFont, ImageDraw, ImageFilter

COLS, ROWS = 36, 19
SX, SY = 6, 10            # field samples per cell
REG_X, REG_Y = 3, 5       # shape-matching regions per cell (SX, SY must divide)
FPS = 12
FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "fastfetch-art")
# Curated: shapes and a few round letters. Glyphs that read as WORDS or digits
# (S G E 5 7 j F ...) were measured as good shape matches but make the art look
# like line noise, so they are not offered.
GLYPHS = " .,:;'`\"^-_~=+*<>/\\|()[]{}!?ilrcvxzuoaenmwqpdbh#%@&$0OQ8MWB"

RAMP = " .:-=+*#%@"       # density ramp for flat cells, light to dark
TAU = 2 * np.pi
RNG = lambda seed: np.random.default_rng(seed)


def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float) / 255


def ramp(x, stops):
    """Piecewise-linear colour ramp; x in [0,1] (any shape) -> (..., 3)."""
    cols = np.array([hexrgb(s) for s in stops])
    p = np.clip(x, 0, 1) * (len(stops) - 1)
    i = np.minimum(p.astype(int), len(stops) - 2)
    f = (p - i)[..., None]
    return cols[i] * (1 - f) + cols[i + 1] * f


# ── Adrian palette (sampled from the render in this repo) ────────────────────
GREENS = ["#030802", "#0e2a0a", "#1d4b0c", "#306e02", "#579f02", "#8fd404", "#c4ef3a", "#eaffa0"]
RUST = ["#2d1a0c", "#573a1b", "#935814", "#d9822b"]
ACID = hexrgb("#c4ec2a")


# ── Noise ────────────────────────────────────────────────────────────────────
_P = np.tile(RNG(11).permutation(256), 2)
_G = np.array([[1, 1, 0], [-1, 1, 0], [1, -1, 0], [-1, -1, 0], [1, 0, 1], [-1, 0, 1],
               [1, 0, -1], [-1, 0, -1], [0, 1, 1], [0, -1, 1], [0, 1, -1], [0, -1, -1]], float)


def perlin(x, y, z):
    xi, yi, zi = (np.floor(v).astype(int) & 255 for v in (x, y, z))
    xf, yf, zf = x - np.floor(x), y - np.floor(y), z - np.floor(z)
    fade = lambda t: t * t * t * (t * (t * 6 - 15) + 10)
    u, v, w = fade(xf), fade(yf), fade(zf)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                h = _P[_P[_P[xi + dx] + yi + dy] + zi + dz] % 12
                g = _G[h]
                d = g[..., 0] * (xf - dx) + g[..., 1] * (yf - dy) + g[..., 2] * (zf - dz)
                wgt = (u if dx else 1 - u) * (v if dy else 1 - v) * (w if dz else 1 - w)
                out = out + wgt * d
    return out


def fbm(x, y, z, octaves=5):
    s, a = 0, 0.5
    for _ in range(octaves):
        s = s + a * perlin(x, y, z)
        x, y, z, a = x * 2.03, y * 2.03, z * 2.03, a * 0.5
    return s


# ── Scene helpers ────────────────────────────────────────────────────────────
def grid(cw, ch):
    """Physical sample coordinates, normalised so the canvas height spans [-1, 1]."""
    W, H = COLS * SX, ROWS * SY
    px = (np.arange(W) + 0.5) * cw / SX
    py = (np.arange(H) + 0.5) * ch / SY
    half = ROWS * ch / 2
    X, Y = np.meshgrid((px - COLS * cw / 2) / half, (py - half) / half)
    return X, -Y                      # y up


def stars(t, seed, sky, n=26):
    """Stars as GLYPHS, not light: a dim star in the field lands across cell edges
    and gets matched to `-` or `=`. Placed per cell instead, and drawn as . + *
    by brightness. Each twinkles a whole number of times per loop (periodic).
    `sky` is a (ROWS, COLS) mask of cells where nothing is in front of them.
    Returns (row, col, glyph, brightness) tuples."""
    r = RNG(seed)
    ci, cj = r.integers(3, COLS - 3, n), r.integers(2, ROWS - 2, n)   # clear of the edge fade
    k, ph, mag = r.integers(1, 3, n), r.uniform(0, 1, n), r.uniform(0.3, 1.0, n)
    out = []
    for x, y, kk, p, m in zip(ci, cj, k, ph, mag):
        b = m * (0.6 + 0.4 * np.sin(TAU * (kk * t + p)))
        if sky[y, x]:
            out.append((y, x, "." if b < 0.45 else "+" if b < 0.75 else "*", b))
    return out


def sky_cells(mask):
    """(H, W) bool sample mask -> (ROWS, COLS) cells that are entirely sky."""
    return mask.reshape(ROWS, SY, COLS, SX).all((1, 3))


def rot(axis, a):
    c, s = np.cos(a), np.sin(a)
    return {"x": np.array([[1, 0, 0], [0, c, -s], [0, s, c]]),
            "y": np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]]),
            "z": np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])}[axis]


# ── Scene A: Adrian ──────────────────────────────────────────────────────────
# A turbulent green world in one full rotation per loop. The surface is a
# domain-warped fbm (warp of a warp, Quilez-style) evaluated ON THE SPHERE in
# 3D, so it has no seam at the date line, and stretched along latitude so the
# swirls shear into bands the way the render's do. Rust patches come from a
# second, slower noise.
_TEX = {}


def adrian_texture():
    if "a" in _TEX:
        return _TEX["a"]
    lon = np.linspace(0, TAU, 720, endpoint=False)
    lat = np.linspace(-np.pi / 2, np.pi / 2, 360)
    LON, LAT = np.meshgrid(lon, lat)
    x, y, z = np.cos(LAT) * np.cos(LON), np.sin(LAT), np.cos(LAT) * np.sin(LON)
    x, y, z = x * 0.95, y * 2.1, z * 0.95           # latitude stretch -> banded swirls
    q = [fbm(x + o, y + o * 1.7, z - o, 4) for o in (0.0, 5.2, 9.1)]
    r = [fbm(x + 3 * q[0] + o, y + 3 * q[1], z + 3 * q[2] - o, 4) for o in (1.7, 8.3, 2.8)]
    f = fbm(x + 3.2 * r[0], y + 3.2 * r[1], z + 3.2 * r[2], 5)
    f = (f - f.min()) / np.ptp(f)
    f = np.clip((f - 0.5) * 1.7 + 0.5, 0, 1)   # contrast: dark lanes between the swirls
    rust = fbm(x * 0.55 + 20, y * 0.4, z * 0.55 - 7, 3)
    rust = np.clip((rust - 0.05) * 5, 0, 1) * (0.4 + 0.6 * f)
    col = ramp(f, GREENS[1:])
    col = col * (1 - rust[..., None]) + ramp(f * 0.8 + 0.25, RUST) * rust[..., None]
    _TEX["a"] = col
    return col


def adrian_disc(X, Y, t, cx, cy, R, sun, halo_k=26):
    """Adrian as a lit sphere, turning once per loop. Shared by both scenes it
    appears in. Returns light, the disc mask, the radius field (in planet radii)
    and the glyph guides (edges, density)."""
    dx, dy = (X - cx) / R, (Y - cy) / R
    d2 = dx * dx + dy * dy
    inside = d2 < 1
    dz = np.sqrt(np.clip(1 - d2, 0, 1))
    n = np.stack([dx, dy, dz], -1)                          # view-space normal
    p = n @ (rot("z", 0.32) @ rot("x", 0.22))               # planet frame (axial tilt)
    lon = (np.arctan2(p[..., 2], p[..., 0]) + TAU * t) % TAU
    lat = np.arcsin(np.clip(p[..., 1], -1, 1))
    tex = adrian_texture()
    th, tw = tex.shape[:2]
    col = tex[np.clip(((lat / np.pi + 0.5) * (th - 1)).astype(int), 0, th - 1),
              (lon / TAU * tw).astype(int) % tw]
    sun = np.asarray(sun, float) / np.linalg.norm(sun)
    lam = np.clip((n @ sun + 0.18) / 1.18, 0, 1) ** 1.35     # wrapped, soft terminator
    limb = (1 - dz) ** 3
    shade = col * (0.16 + 0.95 * lam[..., None]) + ACID * (limb * lam * 0.9)[..., None]
    light = np.where(inside[..., None], shade, 0)
    # atmosphere: a thin acid halo hugging the lit limb
    r = np.sqrt(d2)
    halo = np.exp(-np.clip(r - 1, 0, None) * halo_k) * (r >= 1)
    sunside = np.clip((dx * sun[0] + dy * sun[1]) / np.maximum(r, 1e-6) + 0.35, 0, 1)
    light = light + (halo * sunside * 0.85)[..., None] * ACID
    # Edges are found on the LIGHTING alone; the swirls only set density. The
    # swirls are finer than a glyph, and letting them drive shape matching turned
    # the disc into quotes and underscores.
    texl = col.max(-1)
    edges = np.where(inside, 0.06 + 0.7 * lam, 0) + halo * sunside * 0.8
    density = np.where(inside, (0.06 + 0.75 * lam) * (0.25 + 0.95 * texl), 0) + halo * sunside * 0.8
    return light, inside, r, (edges, density)


def scene_adrian(t, cw, ch):
    X, Y = grid(cw, ch)
    # Radius from the canvas half-width, not a constant: the half-width depends on
    # the cell aspect, and a fixed radius ran the disc and its halo off the edge.
    R = 0.74 * min(X.max(), 1.0)
    light, inside, r, guide = adrian_disc(X, Y, t, 0.0, -0.02, R, [-0.62, 0.55, 0.56])
    return light, ~inside & (r > 1.15), guide


# ── Scene B: The Wheel ───────────────────────────────────────────────────────
# The host is `dragonspine`; this is the Wheel of Time. A seven-spoked wheel,
# ray-marched as a real 3D SDF (rim torus, hub, capsule spokes), tilted toward
# the viewer and turning clockwise. Seven-fold symmetry means one loop only has
# to turn it 1/7 of a revolution to come back to frame 0, so the loop is short
# and seamless. (A gold and an emerald spoke were tried — the Ages — and taken
# back out; they also forced the loop to a full turn, 7x the frames.)


def sd_wheel(p, spin):
    q = p @ rot("z", spin).T
    x, y, z = q[..., 0], q[..., 1], q[..., 2]
    rr = np.sqrt(x * x + y * y)
    rim = np.sqrt((rr - 0.8) ** 2 + z * z) - 0.1
    hub = np.sqrt(x * x + y * y + (z * 1.6) ** 2) - 0.2
    a = np.arctan2(y, x)
    sector = TAU / 7
    a = (a + sector / 2) % sector - sector / 2                   # fold into one spoke
    sx, sy = rr * np.cos(a), rr * np.sin(a)
    sxc = np.clip(sx, 0.1, 0.76)
    taper = 0.075 - 0.025 * (sxc - 0.1) / 0.66
    spoke = np.sqrt((sx - sxc) ** 2 + sy ** 2 + z * z) - taper
    k = 0.05                                                     # smooth union: joints read as forged
    d = rim
    for s in (spoke, hub):
        h = np.clip(0.5 + 0.5 * (s - d) / k, 0, 1)
        d = s * (1 - h) + d * h - k * h * (1 - h)
    return d


def scene_wheel(t, cw, ch):
    X, Y = grid(cw, ch)
    spin = TAU / 7 * t          # positive = clockwise on screen (q = R(spin) p, see sd_wheel)
    tilt = rot("x", -0.55) @ rot("y", 0.3)
    zoom = 1.18 / min(X.max(), 1.0)          # rim stays ~0.75 of the half-width in from the edge
    ro = np.stack([X * zoom, Y * zoom, np.full_like(X, 3.0)], -1)
    rd = np.array([0, 0, -1.0])
    ro, rdl = ro @ tilt, rd @ tilt                               # into wheel space
    dist = np.full(X.shape, 2.0)
    hit = np.zeros(X.shape, bool)
    for _ in range(64):
        p = ro + rdl * dist[..., None]
        d = sd_wheel(p, spin)
        hit |= d < 0.002
        dist = np.where(hit, dist, dist + d * 0.9)
    p = ro + rdl * dist[..., None]
    e = 0.003
    n = np.stack([sd_wheel(p + np.array(v) * e, spin) - sd_wheel(p - np.array(v) * e, spin)
                  for v in ([1, 0, 0], [0, 1, 0], [0, 0, 1])], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True) + 1e-9
    key = np.array([-0.5, 0.8, 0.6]) @ tilt; key /= np.linalg.norm(key)
    v = -rdl
    lam = np.clip(n @ key, 0, 1)
    hv = key + v; hv /= np.linalg.norm(hv)
    spec = np.clip(n @ hv, 0, 1) ** 40
    fres = (1 - np.clip(n @ v, 0, 1)) ** 2.5
    base = ramp(0.25 + 0.6 * lam, GREENS[2:])
    col = base * (0.08 + 0.95 * lam[..., None]) + spec[..., None] * hexrgb("#f2ffc8") * 0.9 \
        + fres[..., None] * ACID * 0.55
    light = np.where(hit[..., None], col, 0)
    # a faint ring of light just outside the rim: the Pattern
    r = np.sqrt(X * X + Y * Y) / min(X.max(), 1.0)
    aura = np.exp(-((r - 0.84) ** 2) / 0.004) * (0.10 + 0.06 * np.sin(TAU * (t * 7 + np.arctan2(Y, X) * 7 / TAU)))
    light = light + (~hit)[..., None] * aura[..., None] * hexrgb("#4f8f1c")
    return light, ~hit & (np.abs(r - 0.84) > 0.12), None


# ── Scene C: Petrova line ────────────────────────────────────────────────────
# Adrian in the foreground, centred and huge, only its curved tip rising from
# the bottom edge; a small far sun centred above it; and between them the
# Petrova line, the red trail of Astrophage flowing BOTH ways — out to the sun to
# feed, back to Adrian to breed. The line is laid out in depth: it narrows,
# dims and slows toward the sun, so it seems to vanish into a horizon space does
# not have. Red appears ONLY in the line: the one warm thing on a green screen.
def scene_petrova(t, cw, ch):
    X, Y = grid(cw, ch)
    ar = min(X.max(), 1.0)
    # Only the tip shows: a planet far wider than the frame, its centre well below
    # it, so the lit limb is one shallow arc across the bottom third. The edge
    # fade dissolves it where it runs out of frame.
    R = 1.9
    cy = -0.58 - R
    light, inside, r, (edges, density) = adrian_disc(X, Y, t, 0.0, cy, R, [0.0, 0.62, -0.78], halo_k=16)   # lit from behind: night face, burning limb
    # the far sun
    sx, sy = 0.0, 0.66
    rs = np.hypot(X - sx, Y - sy)
    ang = np.arctan2(Y - sy, X - sx)
    flick = 1 + 0.10 * np.sin(TAU * 2 * t + ang * 5) + 0.06 * np.sin(TAU * 3 * t - ang * 9)
    sun = np.exp(-(rs / 0.022) ** 2) * 1.4 + np.exp(-rs / (0.04 * flick)) * 0.45
    light = light + sun[..., None] * hexrgb("#f4ffe0")
    # the line: u runs sun (0) -> Adrian's top (1) in DEPTH; perspective maps it
    # to the screen, so equal steps in u crowd together near the sun
    top = cy + R
    z = lambda u: 9.0 * (1 - u) + 1.0 * u
    persp = lambda u: (1 / z(u) - 1 / 9.0) / (1 - 1 / 9.0)
    g = RNG(21)
    n = 1600
    u0, k = g.uniform(0, 1, n), g.choice([1, 2], n)
    back = g.uniform(0, 1, n) < 0.45                           # the return leg
    u = np.where(back, (u0 - k * t) % 1, (u0 + k * t) % 1)
    s = persp(u)
    px = sx + 0.16 * np.sin(np.pi * s) * (1 - s) + 0.06 * np.sin(TAU * s)   # a gentle S
    py = sy + (top + 0.02 - sy) * s
    w = 0.004 + 0.05 * s + 0.07 * s ** 8                       # ~1/depth, flaring where it meets the air
    px = px + g.normal(0, 1, n) * w
    py = py + g.normal(0, 1, n) * w * 0.5
    # dim per particle (they stack), and gone well before the sun so the sun
    # itself stays the brightest point up there
    br = g.uniform(0.25, 0.85, n) * s ** 0.6 * np.clip((s - 0.03) * 4, 0, 1) * np.clip((1 - s) * 25, 0, 1)
    reds = np.where(back[:, None], ramp(g.uniform(0, 1, n), ["#3a0508", "#8a0f17", "#c4141f"]),
                    ramp(g.uniform(0, 1, n), ["#7a0c12", "#d81e22", "#ff4a33", "#ff9a6a"]))
    sig = 0.005 + 0.01 * s
    acc = np.zeros(X.shape + (3,))
    xs, ys = X[0], Y[:, 0]
    for qx, qy, b, c, sg in zip(px, py, br, reds, sig):
        i0, i1 = np.searchsorted(xs, [qx - 4 * sg, qx + 4 * sg])
        j1, j0 = np.searchsorted(-ys, [-(qy - 4 * sg), -(qy + 4 * sg)])
        if i1 <= i0 or j1 <= j0:
            continue
        sub = np.exp(-((X[j0:j1, i0:i1] - qx) ** 2 + (Y[j0:j1, i0:i1] - qy) ** 2) / (2 * sg * sg))
        acc[j0:j1, i0:i1] += (sub * b)[..., None] * c
    light = light + acc
    # where the stream meets Adrian, Astrophage bleeds into the atmosphere: a
    # red haze spread along the limb, strongest at the contact point
    # (the S-curve ends back on x = sx). Centred just ABOVE the limb: on the limb
    # itself the green atmosphere outweighs it and the haze read as green.
    haze = np.exp(-((X - sx) / 0.45) ** 2 - ((Y - top - 0.07) / 0.1) ** 2) * (0.45 + 0.06 * np.sin(TAU * t * 2))
    light = light + haze[..., None] * hexrgb("#c41a20")
    acc = acc + haze[..., None] * hexrgb("#c41a20")
    la = acc.max(-1)
    edges, density = edges + la, density + la
    sky = ~inside & (r > 1.2) & (rs > 0.2) & (la < 0.02)
    # The sun is a placed `*`, like the stars: its disc is smaller than a cell,
    # and shape-matching it gave quote marks. Its glow still comes from `light`.
    half = ROWS * ch / 2
    col, row = int((sx * half + COLS * cw / 2) // cw), int((half - sy * half) // ch)
    return light, sky, (edges, density), [(row, col, "*", hexrgb("#f4ffe0"), 1.0)]


# scene: (function, frames per loop, star seed, star count)
SCENES = {"adrian": (scene_adrian, 144, 3, 26), "wheel": (scene_wheel, 40, 5, 18),
          "petrova": (scene_petrova, 144, 9, 24)}
STAR = hexrgb("#c8e6b4")


# ── Field -> glyphs ──────────────────────────────────────────────────────────
class Glyphs:
    """The glyph set rasterised at one cell size, plus each glyph's region shape."""

    def __init__(self, cw, ch):
        self.cw, self.ch = cw, ch
        font = ImageFont.truetype(FONT, cw / 0.6)            # advance is 0.6 em
        asc, desc = font.getmetrics()
        y0 = (ch - asc - desc) / 2
        masks = []
        for g in GLYPHS:
            im = Image.new("L", (cw, ch), 0)
            ImageDraw.Draw(im).text((0, y0), g, font=font, fill=255)
            masks.append(np.asarray(im, float) / 255)
        self.masks = np.array(masks)                          # (G, ch, cw)
        # shape vectors: coverage per region, measured on a high-res raster
        big = ImageFont.truetype(FONT, 120)
        basc, bdesc = big.getmetrics()
        bw, bh = 72, basc + bdesc
        vecs = []
        for g in GLYPHS:
            im = Image.new("L", (bw, bh), 0)
            ImageDraw.Draw(im).text((0, 0), g, font=big, fill=255)
            a = np.asarray(im.resize((REG_X * 8, REG_Y * 8), Image.BOX), float) / 255
            vecs.append(a.reshape(REG_Y, 8, REG_X, 8).mean((1, 3)).ravel())
        v = np.array(vecs)
        self.vecs = v / v.max()

    def pick(self, field, edges=None, density=None):
        """field (H, W, 3) -> glyph index (ROWS, COLS), colour (ROWS, COLS, 3), level (ROWS, COLS).

        Two kinds of cell. An EDGE cell (its regions disagree: a silhouette, a
        spoke) is shape-matched against the glyph vectors, so it gets `/`, `(`,
        `_`. A FLAT cell gets a classic density-ramp glyph — shape matching inside
        a flat-ish area only amplifies noise into quotes and underscores.
        `edges` / `density` optionally override the luminance used for each
        decision; colour always comes from `field`."""
        lum = field.max(-1)
        sel = lum if edges is None else edges
        dens = sel if density is None else density
        reg = sel.reshape(ROWS, REG_Y, SY // REG_Y, COLS, REG_X, SX // REG_X).mean((2, 5))
        reg = reg.transpose(0, 2, 1, 3).reshape(ROWS, COLS, -1)
        reg = np.clip(reg, 0, 1) ** 1.7               # mid-tones -> lighter glyphs than @
        # contrast: push each cell's regions apart relative to its own peak,
        # so edges become `/`-like strokes instead of mushy mid-density glyphs
        mean = reg.mean(-1, keepdims=True)
        reg = mean + (reg - mean) * 0.75               # damp sub-cell texture
        peak = reg.max(-1, keepdims=True)
        reg = peak * (reg / np.maximum(peak, 1e-6)) ** 1.3
        d = ((reg[:, :, None, :] - self.vecs[None, None]) ** 2).sum(-1)
        idx = d.argmin(-1)
        flat = (reg.max(-1) - reg.min(-1)) < 0.16
        dm = dens.reshape(ROWS, SY, COLS, SX).mean((1, 3))
        dm = np.clip((dm - 0.07) / 0.75, 0, 1) ** 0.9        # floor: faint haze stays blank, not a field of dots
        ramp_idx = np.array([GLYPHS.index(g) for g in RAMP])
        idx = np.where(flat, ramp_idx[np.minimum((dm * len(RAMP)).astype(int), len(RAMP) - 1)], idx)
        w = lum[..., None]
        cell = lambda a: a.reshape(ROWS, SY, COLS, SX, -1).sum((1, 3))
        col = cell(field * w) / np.maximum(cell(w), 1e-6)
        col = col / np.maximum(col.max(-1, keepdims=True), 1e-6)   # hue only
        level = lum.reshape(ROWS, SY, COLS, SX).mean((1, 3))
        return idx, col, level

    def draw(self, idx, col, level, field):
        m = self.masks[idx]                                   # (ROWS, COLS, ch, cw)
        gain = (0.12 + 1.05 * np.clip(level, 0, 1) ** 0.75)[..., None]
        c = col * gain                                        # (ROWS, COLS, 3)
        img = m[..., None] * c[:, :, None, None, :]
        img = img.transpose(0, 2, 1, 3, 4).reshape(ROWS * self.ch, COLS * self.cw, 3)
        # glow: the glyphs bloomed, plus a faint wash of the field itself so the
        # scene still reads as a shape between the strokes
        glow = blur(img, self.cw * 0.9) * 0.9
        wash = np.asarray(Image.fromarray((np.clip(field, 0, 1) * 255).astype(np.uint8))
                          .resize(img.shape[1::-1], Image.BILINEAR), float) / 255
        wash = blur(wash, self.cw * 1.2) * 0.16
        out = np.clip(img + glow + wash, 0, 1)
        # Nothing may be CUT at the border, glow least of all: everything fades to
        # exactly zero over the outer 2.5 columns / 1.2 rows (smoothstep on the
        # distance to each edge; per axis, because a row is twice a column's
        # size and one margin in pixels left the bottom row half lit). Scenes are laid out to sit inside it; this is the
        # guarantee for whatever still reaches it, like Petrova's planet, which
        # sinks below the bottom edge on purpose and dissolves instead of clipping.
        h, w = out.shape[:2]
        ys, xs = np.arange(h), np.arange(w)
        fy = np.clip(np.minimum(ys, h - 1 - ys) / (1.2 * self.ch), 0, 1)
        fx = np.clip(np.minimum(xs, w - 1 - xs) / (2.5 * self.cw), 0, 1)
        f = np.minimum(fy[:, None], fx[None, :])
        out = out * (f * f * (3 - 2 * f))[..., None]
        a = out.max(-1)
        rgb = out / np.maximum(a, 1e-6)[..., None]
        return Image.fromarray((np.dstack([rgb, a]) * 255 + 0.5).astype(np.uint8), "RGBA")


def cells(scene, t, gl):
    """Everything up to the glyph grid: (field, idx, colour, level)."""
    fn, _, seed, n = SCENES[scene]
    field, sky, guide, *marks = fn(t, gl.cw, gl.ch)
    idx, col, level = gl.pick(field, *(guide or ()))
    for y, x, g, b in stars(t, seed, sky_cells(sky), n):
        idx[y, x], col[y, x], level[y, x] = GLYPHS.index(g), STAR, b * 0.55
    for y, x, g, c, b in (marks[0] if marks else ()):         # glyphs a scene places itself
        idx[y, x], col[y, x], level[y, x] = GLYPHS.index(g), c, b
    return field, idx, col, level


def blur(img, radius):
    chans = [np.asarray(Image.fromarray((np.clip(img[..., i], 0, 1) * 255).astype(np.uint8))
                        .filter(ImageFilter.GaussianBlur(radius)), float) / 255 for i in range(3)]
    return np.dstack(chans)


def frame_dir(scene, cw, ch):
    return os.path.join(CACHE, scene, f"{cw}x{ch}")


def render(scene, cw, ch):
    n = SCENES[scene][1]
    out = frame_dir(scene, cw, ch)
    tmp = out + ".tmp"
    os.makedirs(tmp, exist_ok=True)
    gl = Glyphs(cw, ch)
    frames = []
    for i in range(n):
        f, idx, col, level = cells(scene, i / n, gl)
        im = gl.draw(idx, col, level, f)
        # Lossless, max compression: ~260 KB a frame. A 256-colour palette was
        # 40 KB but banded the glow into visible contour rings.
        im.save(os.path.join(tmp, f"{i:03d}.png"), compress_level=9)
    with open(os.path.join(tmp, "meta"), "w") as f:
        f.write(f"{COLS} {ROWS} {FPS} {n}\n")              # read by fetch.py, which must not import numpy
    if os.path.exists(out):
        import shutil
        shutil.rmtree(out)
    os.replace(tmp, out)
    try:                                    # the SSH still is cut from the same scene
        os.unlink(os.path.join(CACHE, scene, "text"))
    except OSError:
        pass
    return out


def apng(scene, cw, ch):
    """All frames as one animated PNG, for terminals that play kitty animations
    themselves. Built on demand only: Ghostty holds every frame decoded, so this
    costs COLS*cw * ROWS*ch * 4 bytes PER FRAME of terminal memory."""
    d = frame_dir(scene, cw, ch)
    n = SCENES[scene][1]
    frames = [Image.open(os.path.join(d, f"{i:03d}.png")) for i in range(n)]
    frames[0].save(os.path.join(d, "anim.png"), save_all=True, append_images=frames[1:],
                   duration=round(1000 / FPS), loop=0, disposal=1, blend=0)


def text_frame(scene, t=0.0, cw=10, ch=22):
    """One frame as truecolor ANSI text (the SSH path). cw/ch only set the aspect."""
    gl = Glyphs(cw, ch)
    _, idx, col, level = cells(scene, t, gl)
    gain = (0.12 + 1.05 * np.clip(level, 0, 1) ** 0.75)[..., None]
    rgb = (np.clip(col * gain, 0, 1) * 255).astype(int)
    lines = []
    for y in range(ROWS):
        s = ""
        for x in range(COLS):
            g = GLYPHS[idx[y, x]]
            s += g if g == " " else "\x1b[38;2;%d;%d;%dm%s" % (*rgb[y, x], g)
        lines.append(s + "\x1b[0m")
    return "\n".join(lines)


if __name__ == "__main__":
    cmd, scene = sys.argv[1], sys.argv[2]
    if cmd == "render":
        print(render(scene, int(sys.argv[3]), int(sys.argv[4])))
    elif cmd == "apng":
        apng(scene, int(sys.argv[3]), int(sys.argv[4]))
    elif cmd == "text":
        print(text_frame(scene))
    elif cmd == "preview":
        import time
        n = SCENES[scene][1]
        frames = [text_frame(scene, i / n) for i in range(n)]
        sys.stdout.write("\x1b[?25l")
        try:
            i = 0
            while True:
                sys.stdout.write(frames[i % n] + f"\x1b[{ROWS - 1}A\r")
                sys.stdout.flush(); time.sleep(1 / FPS); i += 1
        except KeyboardInterrupt:
            sys.stdout.write(f"\x1b[{ROWS}B\x1b[?25h\n")
