"""Draws the unit frame textures of AnotherHUD (Theme.textures.disc / spark /
shield, Theme.barTextures).

Writes into AnotherHUD/Media/Units/ (uncompressed 32-bit TGA, bottom-left
origin):

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
  RoleTank / RoleHealer / RoleDamage.tga  32 x 32  colored role glyphs
  Crown.tga       32 x 24   gold leader crown
  Glow.tga        32 x 32   white frame: 2 px line, 8 px glow outside, cut-out middle
  Calendar.tga    32 x 32   white calendar page (minimap calendar badge)

The bar files are normalized to their brightest stop: the game multiplies the
file by the bar color, so Theme.barColor multiplies the color by that stop
(Theme.barTextures[name].tint) to bring the middle back to the color.

Source: docs/mockups/kit.js (TEX) and kit.css (.shield). Plain Python 3, no
libraries. Run from the repo root: python tools/render_units.py
"""
import math
import os
import re


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


def parse_path(d):
    """SVG path (M L H V Q Z, absolute) -> list of (points, closed). Quadratic
    segments are flattened to 8 lines each."""
    toks = re.findall(r"[A-Za-z]|-?\d+\.?\d*", d)
    subs, pts, closed = [], [], False
    cur = (0.0, 0.0)
    i = 0
    cmd = None

    def num():
        return float(toks[i])

    while i < len(toks):
        if toks[i].isalpha():
            cmd = toks[i]
            i += 1
            if cmd == "Z":
                subs.append((pts, True))
                pts = []
            continue
        if cmd == "M":
            if pts:
                subs.append((pts, False))
            cur = (num(), float(toks[i + 1]))
            i += 2
            pts = [cur]
            cmd = "L"
        elif cmd == "L":
            cur = (num(), float(toks[i + 1]))
            i += 2
            pts.append(cur)
        elif cmd == "H":
            cur = (num(), cur[1])
            i += 1
            pts.append(cur)
        elif cmd == "V":
            cur = (cur[0], num())
            i += 1
            pts.append(cur)
        elif cmd == "Q":
            cx, cy = num(), float(toks[i + 1])
            ex, ey = float(toks[i + 2]), float(toks[i + 3])
            i += 4
            x0, y0 = cur
            for k in range(1, 9):
                t = k / 8.0
                u = 1.0 - t
                pts.append((u * u * x0 + 2 * u * t * cx + t * t * ex,
                            u * u * y0 + 2 * u * t * cy + t * t * ey))
            cur = (ex, ey)
        else:
            raise ValueError("path command " + str(cmd))
    if pts:
        subs.append((pts, False))
    return subs


def seg_dist(px, py, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def hexc(s):
    return tuple(int(s[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


def glyph(layers, w, h, box_w, box_h):
    """layers, bottom to top: ("fill", path, rgb) or ("stroke", path, rgb,
    width), in a box_w x box_h box scaled to the w x h file. 4 x 4
    supersampling; stroke = distance to a segment <= width / 2."""
    ss = 4
    sx, sy = w / float(box_w), h / float(box_h)
    prepared = []
    for layer in layers:
        subs = parse_path(layer[1])
        if layer[0] == "fill":
            prepared.append(("fill", subs, layer[2], 0.0))
        else:
            segs = []
            for pts, closed in subs:
                for a, b in zip(pts, pts[1:]):
                    segs.append((a, b))
                if closed:
                    segs.append((pts[-1], pts[0]))
            prepared.append(("stroke", segs, layer[2], layer[3] / 2.0))
    rows = []
    for y in range(h):
        row = []
        for x in range(w):
            ar = ag = ab = aa = 0.0
            for j in range(ss):
                for i in range(ss):
                    px = (x + (i + 0.5) / ss) / sx
                    py = (y + (j + 0.5) / ss) / sy
                    hit = None
                    for kind, data, rgb, hw in prepared:
                        if kind == "fill":
                            if any(inside(px, py, p) for p, _ in data):
                                hit = rgb
                        elif any(seg_dist(px, py, a, b) <= hw for a, b in data):
                            hit = rgb
                    if hit:
                        ar += hit[0]
                        ag += hit[1]
                        ab += hit[2]
                        aa += 1.0
            if aa == 0:
                row.append((0, 0, 0, 0))
            else:
                row.append((byte(ar / aa), byte(ag / aa), byte(ab / aa),
                            byte(aa / (ss * ss))))
        rows.append(row)
    return rows, w, h


# Glyph shapes from docs/mockups/3-party-boss.html (24 x 24 box).
def role_tank():
    return glyph([
        ("fill", "M12 2 L20 5 L19 13 Q17 19 12 22 Q7 19 5 13 L4 5 Z", hexc("#4aa3ff")),
        ("stroke", "M12 2 L20 5 L19 13 Q17 19 12 22 Q7 19 5 13 L4 5 Z", hexc("#0b1a2e"), 1.5),
        ("stroke", "M12 5 V19", hexc("#cfe6ff"), 1.5),
    ], 32, 32, 24, 24)


def role_healer():
    p = "M9 3 H15 V9 H21 V15 H15 V21 H9 V15 H3 V9 H9 Z"
    return glyph([("fill", p, hexc("#46d65a")), ("stroke", p, hexc("#0b2410"), 1.5)],
                 32, 32, 24, 24)


def role_damage():
    p = "M18 3 L21 3 L21 6 L10 17 L7 14 Z"
    return glyph([
        ("fill", p, hexc("#e8e8ee")),
        ("stroke", p, hexc("#2a1010"), 1.2),
        ("stroke", "M5 13 L11 19", hexc("#d24a3a"), 2.4),
        ("stroke", "M4 20 L7 17", hexc("#d24a3a"), 2.4),
    ], 32, 32, 24, 24)


def crown():
    p = "M2 16 L3 4 L8 9 L12 2 L16 9 L21 4 L22 16 Z"
    gold = (1.0, 0.82, 0.0)  # Theme.colors.gold
    return glyph([("fill", p, gold), ("stroke", p, hexc("#3a2600"), 1.5)], 32, 24, 24, 18)


def calendar():
    """White 32 x 32 calendar page (mockup 7's calendar badge symbol, tinted
    gold in code): a 2 px page outline with two binder rings, a filled top
    band and two rows of three day squares."""
    white = (1.0, 1.0, 1.0)
    return glyph([
        ("stroke", "M4 6 H20 V20 H4 Z", white, 2.0),
        ("fill", "M4 6 H20 V10 H4 Z", white),
        ("stroke", "M8 3 V7", white, 2.0),
        ("stroke", "M16 3 V7", white, 2.0),
        ("fill", "M6 12 H9 V14 H6 Z", white),
        ("fill", "M10.5 12 H13.5 V14 H10.5 Z", white),
        ("fill", "M15 12 H18 V14 H15 Z", white),
        ("fill", "M6 16 H9 V18 H6 Z", white),
        ("fill", "M10.5 16 H13.5 V18 H10.5 Z", white),
        ("fill", "M15 16 H18 V18 H15 Z", white),
    ], 32, 32, 24, 24)


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def glow():
    """White 32 x 32 frame: a 2 px line from 8 to 10 px in from the edge (the
    frame edge), alpha 0.75 falling to 0 over the 8 px outside it, nothing
    inside (the middle is cut out)."""
    s = 32
    rows = []
    for y in range(s):
        row = []
        for x in range(s):
            # distance in px (pixel centers) outside the rectangle [8, 24]
            fx, fy = x + 0.5, y + 0.5
            ox = max(8.0 - fx, fx - 24.0, 0.0)
            oy = max(8.0 - fy, fy - 24.0, 0.0)
            if ox == 0.0 and oy == 0.0:
                # inside the rectangle: the 2 px line is the outer ring of it
                d = min(fx - 8.0, 24.0 - fx, fy - 8.0, 24.0 - fy)
                a = 1.0 if d < 2.0 else 0.0
            else:
                d = math.hypot(ox, oy)
                a = 0.75 * (1.0 - smoothstep(d / 8.0))
            row.append((255, 255, 255, byte(a)))
        rows.append(row)
    return rows, s, s


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "AnotherHUD", "Media", "Units")
    os.makedirs(out, exist_ok=True)
    images = {"Disc": disc(), "BarSmooth": bar_smooth(), "BarGloss": bar_gloss(),
              "Spark": spark(), "Shield": shield(), "RoleTank": role_tank(),
              "RoleHealer": role_healer(), "RoleDamage": role_damage(),
              "Crown": crown(), "Glow": glow(), "Calendar": calendar()}
    for name, (rows, w, h) in images.items():
        save_tga(rows, w, h, os.path.join(out, name + ".tga"))
        print("wrote %s.tga %dx%d" % (name, w, h))


if __name__ == "__main__":
    main()
