# Approved mockups

The art the player approved, per mockup page in this folder. Open a page via a
local web server from this folder (for example `python -m http.server`), as
the pages load `kit.js`, `kit.css` and `units.js`. Colors and skin rules come
from AnotherLedger's `Theme.lua` (`Theme.colors`, `Theme.edgeRects`,
`Theme.skinScales`); every part is drawn in all four skins (Classic, Forge,
Slate, Gilded) and tinted with the theme colors.

Shared rules (all mockups):

- **Panel**: `panelTint` (0.15, 0.10, 0.06) fill; border = the skin's
  `edgeRects` lines in `panelBorder` (0.55, 0.42, 0.24) shades (Classic: the
  soft round tooltip edge, ~4 px; Forge bevel 5 px; Slate thin 2 px; Gilded
  6 px plus 10 px corner studs).
- **Ring** (portrait and round badges): the same border lines bent into a
  circle, outside in; Gilded adds four 9 px studs at 45 / 135 / 225 / 315 deg.
- **Dividers** (between health and power, beside a cast icon): the skin's
  Lines pick in `goldLine` (gold / groove / plain / dotted).
- **Texts**: game font (FRIZQT) with outline; level numbers in `gold`.

## 1. Player frame (`1-player.html`)

- Variant: **B, overhanging ring**.
- Frame 200 x 60, power bar 15 high, 1 px divider line between health and
  power; bars inset by the skin's border width + 1 px.
- Portrait ring: diameter 125% of the frame height (75 px at 60) times
  Portrait Scale, centered on the frame's left part (center x = 32% of the
  diameter); bars start 2 px right of the ring. Gilded: frame studs only on
  the corners the ring doesn't cover.
- Level on an 18 px round badge (ring lines, panel fill, gold 10 pt number)
  at the ring's lower right.
- Texts: name left and health value right on the health bar (about 11 pt at
  60 high), power value right on the power bar (10 pt).
- Cast bar: 200 x 18, 8 px under the frame (14 px under the ring); spell icon as its own
  18 x 18 square left of the bar (2 px border-colored edge), bar panel to the
  right with spell name left, time right, a bright spark at the fill end.
  Colors: cast (1, 0.74, 0.12), channel (0.35, 0.75, 0.35), interrupted
  (0.85, 0.2, 0.15) full bar with "Interrupted", uninterruptible grey
  (0.6, 0.6, 0.62) with a shield over the icon.
- Bar texture default: **Smooth** (top 125% lighter, mid the color, bottom
  72%); Flat and Gloss stay choosable. Bar background: the bar color at 18%.
- Health: class color (option on); off = green (0.16, 0.62, 0.22).
