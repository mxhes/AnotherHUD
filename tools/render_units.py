"""Draws the unit frame textures of AnotherHUD (Theme.textures.disc / spark /
shield, Theme.barTextures).

Writes into AnotherHUD/Media/Units/ (uncompressed 32-bit TGA, bottom-left
origin, like Media/Skins):

  Disc.tga       256 x 256  white disc, anti-aliased edge (ring lines, portrait
                            and badge masks are stacked discs)
  BarSmooth.tga    4 x 64   grey vertical gradient, stops 1.25 / 1.0 / 0.72 of
                            the bar color at 0 / 45 / 100 %, divided by 1.25
  BarGloss.tga     4 x 64   grey vertical gradient, stops white mix / 1.05 /
                            0.82 / 0.62 at 0 / 38 / 52 / 100 %, baked at c = 0.5,
                            normalized by the top stop
  Spark.tga       16 x 64   soft white vertical glow, brightest on the center
                            column (tinted in code)
  Shield.tga      32 x 32   the mockup's shield outline, grey gradient, alpha .75

The bar files are normalized to their brightest stop: the game multiplies the
file by the bar color, so Theme.barColor multiplies the color by that stop
(Theme.barTextures[name].tint) to bring the middle back to the color.

Source: docs/mockups/kit.js (TEX) and kit.css (.shield). Plain Python 3, no
libraries. Run from the repo root: python tools/render_units.py
"""
import math
import os


def save_tga(pixels, w, h, path):
    """pixels: rows top to bottom, each a list of (r, g, b, a) bytes.
    Uncompressed 32-bit, bottom-left origin (descriptor 0x08)."""
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    w & 255, w >> 8, h & 255, h >> 8, 32, 8])
    out = bytearray(header)
    for row in reversed(pixels):
        for r, g, b, a in row:
            out += bytes((b, g, r, a))  # TGA stores BGRA
    with open(path, "wb") as f:
        f.write(bytes(out))


def byte(v):
    return max(0, min(255, int(round(v * 255))))


def stops_at(stops, t):
    """Linear interpolation of [(position 0..1, value), ...] at t."""
    if t <= stops[0][0]:
        return stops[0][1]
    for (p0, v0), (p1, v1) in zip(stops, stops[1:]):
        if t <= p1:
            return v0 + (v1 - v0) * (t - p0) / (p1 - p0)
    return stops[-1][1]


def disc():
    s = 256
    c, r = s / 2.0, s / 2.0
    rows = []
    for y in range(s):
        row = []
        for x in range(s):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
            cov = max(0.0, min(1.0, r - d + 0.5))  # one pixel of alpha edge
            row.append((255, 255, 255, byte(cov)))
        rows.append(row)
    return rows, s, s


def gradient(stops, w=4, h=64):
    rows = []
    for y in range(h):
        g = byte(stops_at(stops, (y + 0.5) / h))
        rows.append([(g, g, g, 255)] * w)
    return rows, w, h


def bar_smooth():
    k = 1.25
    return gradient([(0.0, 1.25 / k), (0.45, 1.0 / k), (1.0, 0.72 / k)])


def bar_gloss():
    # The mockup's stops are mix(c, white, .45), 1.05 c, .82 c, .62 c. A grey
    # file is multiplied by the bar color, so the ratios are baked at a mid
    # color c = 0.5 and normalized by the top stop: exact at c = 0.5, the
    # highlight is weaker on dark colors and clamped on bright ones.
    c = 0.5
    top = c + (1.0 - c) * 0.45
    return gradient([(0.0, 1.0), (0.38, 1.05 * c / top), (0.52, 0.82 * c / top),
                     (1.0, 0.62 * c / top)])


def spark():
    w, h = 16, 64
    rows = []
    for y in range(h):
        # Fade out over the outer 12 rows so the glow has no hard end.
        v = min(1.0, min(y + 0.5, h - y - 0.5) / 12.0)
        row = []
        for x in range(w):
            dx = abs(x + 0.5 - w / 2.0) / (w / 2.0)  # 0 center .. 1 edge
            # mockup: .95 at the center column, 0 by 70 % of the radius
            a = max(0.0, 1.0 - dx / 0.7) ** 1.5 * 0.95 * v
            row.append((255, 255, 255, byte(a)))
        rows.append(row)
    return rows, w, h


# kit.css .shield: polygon 50% 0, 100% 18%, 92% 70%, 50% 100%, 8% 70%, 0 18%
SHIELD = [(0.5, 0.0), (1.0, 0.18), (0.92, 0.70), (0.5, 1.0), (0.08, 0.70), (0.0, 0.18)]


def inside(px, py, poly):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def shield():
    s, ss = 32, 8
    rows = []
    for y in range(s):
        row = []
        for x in range(s):
            n = 0
            for sy in range(ss):
                for sx in range(ss):
                    if inside((x + (sx + 0.5) / ss) / s, (y + (sy + 0.5) / ss) / s, SHIELD):
                        n += 1
            cov = n / float(ss * ss)
            # 135deg gradient: top left light 0.86, bottom right 0.47
            t = ((x + 0.5) + (y + 0.5)) / (2.0 * s)
            g = byte(0.86 + (0.47 - 0.86) * t)
            row.append((g, g, g, byte(cov * 0.75)))
        rows.append(row)
    return rows, s, s


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "AnotherHUD", "Media", "Units")
    os.makedirs(out, exist_ok=True)
    images = {"Disc": disc(), "BarSmooth": bar_smooth(), "BarGloss": bar_gloss(),
              "Spark": spark(), "Shield": shield()}
    for name, (rows, w, h) in images.items():
        save_tga(rows, w, h, os.path.join(out, name + ".tga"))
        print("wrote %s.tga %dx%d" % (name, w, h))


if __name__ == "__main__":
    main()
