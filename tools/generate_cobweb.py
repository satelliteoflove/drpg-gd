"""Generate a cobweb alpha texture for dungeon corner webs.

A classic radial spider web: jittered radial spokes plus concentric sagging
rings, with a few broken/dangling strands for an old, abandoned look. White
threads on a transparent background; alpha fades toward the rim so the web
melts into the dark instead of ending on a hard square edge.

License-clean: fully procedural, no external assets.

Run:  uv run --with pillow python tools/generate_cobweb.py
Output: textures/props/cobweb.png  (512x512 RGBA)
"""

import math
import os
import random

from PIL import Image, ImageDraw

SS = 2  # supersample factor for cheap anti-aliasing
SIZE = 512
W = SIZE * SS
CX, CY = W // 2, W // 2
MAXR = W * 0.48
SPOKES = 12
RINGS = 8
THREAD = (235, 235, 240)

random.seed(7)


def alpha_for(r_frac: float) -> int:
    # strong near the hub, fading toward the rim (but still readable out there)
    return int(max(0.0, 255 * (1.0 - 0.55 * r_frac)))


def main() -> None:
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # spoke angles with a little jitter so it isn't mechanically perfect
    angles = []
    for i in range(SPOKES):
        a = (i / SPOKES) * math.tau + random.uniform(-0.05, 0.05)
        angles.append(a)

    # radial spokes
    spoke_pts = []  # spoke_pts[i] = list of (x,y) at each ring radius
    for a in angles:
        pts = []
        for ring in range(RINGS + 1):
            rr = MAXR * (ring / RINGS) ** 1.05
            pts.append((CX + math.cos(a) * rr, CY + math.sin(a) * rr))
        spoke_pts.append(pts)
        d.line([pts[0], pts[-1]], fill=THREAD + (alpha_for(0.4),), width=SS + 2)

    # concentric sagging rings connecting adjacent spokes
    for ring in range(1, RINGS + 1):
        r_frac = ring / RINGS
        a8 = alpha_for(r_frac)
        if a8 <= 4:
            continue
        for i in range(SPOKES):
            a_pt = spoke_pts[i][ring]
            b_pt = spoke_pts[(i + 1) % SPOKES][ring]
            mid = ((a_pt[0] + b_pt[0]) / 2, (a_pt[1] + b_pt[1]) / 2)
            # pull the midpoint inward toward the hub for the classic sag
            sag = 0.80 + random.uniform(-0.04, 0.04)
            ms = (CX + (mid[0] - CX) * sag, CY + (mid[1] - CY) * sag)
            d.line([a_pt, ms, b_pt], fill=THREAD + (a8,), width=SS + 1)

    # a few broken/dangling strands for an abandoned feel
    for _ in range(5):
        i = random.randrange(SPOKES)
        start_ring = random.randint(3, RINGS - 1)
        p = spoke_pts[i][start_ring]
        drop = random.uniform(20, 70) * SS
        end = (p[0] + random.uniform(-10, 10) * SS, p[1] + drop)
        d.line([p, end], fill=THREAD + (90,), width=1)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    out_dir = os.path.join(os.path.dirname(__file__), "..", "textures", "props")
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "cobweb.png")
    img.save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
