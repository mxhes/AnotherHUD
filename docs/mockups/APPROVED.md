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

## 2. Target, Focus, Target of Target, Pet (`2-target.html`)

- Variant: **A, Target mirrored** (portrait on the right). Its cast bar sits
  under it (8 px gap, icon left as on the Player), debuffs under the cast bar
  growing away from the portrait side, Target of Target under the debuffs on
  the portrait side.
- Target 200 x 60, power 15, cast bar 200 x 18 (same rules as the Player).
- Debuff icons 22 px, 2 px gap; 2 px edge in the game's debuff type color
  (magic 0.2/0.6/1, curse 0.6/0/1, poison 0/0.6/0, disease 0.6/0.4/0, none
  0.8/0/0); buffs 1 px `panelBorder` edge; other players' auras desaturated;
  time centered at the bottom, stacks top right (about 42% of the icon size).
- Classification on the ring tint: normal `panelBorder`; elite `gold`
  (1, 0.82, 0); rare silver (0.78, 0.78, 0.81); rare elite silver ring with
  a gold-ringed level badge.
- Health: NPCs in reaction colors (hostile 0.85/0.2/0.15, neutral
  0.95/0.82/0.2, friendly 0.25/0.75/0.25), players in class color.
- Focus 160 x 40, power 8, 14 px level badge, 10 pt name + health %.
- Target of Target 120 x 26, no power bar, name only (10 pt), ring without
  level badge; Gilded studs only on rings of 40 px and up.
- Pet 120 x 34, power 6, name + health % (10 pt), no level badge.

## 3. Party and Boss frames (`3-party-boss.html`)

- Party variant: **A, small rings**. Vertical, 5 frames (player included),
  8 px gap; frame 160 x 40, power 5; ring = the Player rule at 92% Portrait
  Scale (46 px); no level badge.
- Role icon: our own glyphs (tank: blue shield, healer: green cross, damage:
  silver sword with red hilt) on a 15 px round badge (ring lines, panel fill)
  at the ring's lower left. Leader: gold crown (12 px) on top of the ring.
- Auras: 20 px icons, 2 px gap, 6 px right of the frame, vertically centered;
  debuffs first, then my buffs (same icon rules as mockup 2).
- States: out of range = whole frame at 55% opacity; dead = grey bar
  (0.35, 0.35, 0.35), "Dead" in grey text, empty power; offline = grey bar
  (0.3, 0.3, 0.3), "Offline"; dispellable debuff = 2 px edge plus 8 px glow
  around the frame in the debuff type color.
- Boss: 180 x 42, power 6, mirrored like the Target, gold (elite) ring,
  14 px "??" level badge, 74 px apart, cast bar 180 x 16 under each (icon
  left), my debuffs 22 px to the left of the frame growing leftward.

## 4. Action buttons and proc glow (`4-buttons.html`)

- Edge variant: **A, skin border**: the frames' border lines around the icon
  (Classic soft round 3 px with 4 px corner radius, Forge bevel 5 px, Slate
  2 px, Gilded 6 px plus 7 px corner studs), `panelTint` behind. Icon cropped
  to fill the inside.
- Buttons pick shading inside the edge: Bronze = 1 px dark line
  (`panelBorder` x 0.3) plus a faint warm top light; Raised = 1 px light
  top / left (`panelBorder` x 1.9) and dark bottom / right (x 0.25); Flat =
  nothing.
- States: hover = edge lines in `goldLine` plus a 16% warm overlay; pressed =
  icon at 70% brightness; active / toggled = 2 px `gold` inner edge with a
  soft gold inner glow; empty slot = panel at 75% with a dark inner shadow.
- Tints: out of range red (0.8, 0.1, 0.1) multiplied on the icon and the
  hotkey in red; no mana blue (0.5, 0.5, 1); unusable grey (desaturated,
  ~55% brightness). Cooldown: 72% black swipe, time centered in `gold` 15 pt.
- Texts (at 40 px): hotkey top right 10 pt white; count / charges bottom
  right 12 pt; macro name bottom center 9 pt cream (0.93, 0.87, 0.72).
- Proc glow: **1, Gold pulse**: a halo 5 px outside the button (2 px
  `goldLine` line, 10 px outer glow at 75%, 8 px inner glow at 60%) that
  breathes between 55% and 100% opacity and 100-106% size, 1.1 s per cycle.

## 5. Class resources and totem bar (`5-resources.html`)

- Resource variant: **B, segmented bar** (the player's choice; Claude had
  suggested round gems). One panel in the skin border, split into equal
  segments by 1 px dividers in the skin's Lines pick; each segment a Smooth
  bar in the resource color, background the color at 18%.
- Attached under the Player frame: 4 px under it, starting right of the
  portrait ring and as wide as the health / power column (136 x 18 at the
  default Player size); the Player cast bar moves down below it. Detached
  default: 200 x 20.
- Partial points (recharging runes, shard fragments, regenerating essence)
  fill left to right at 55% of the color, with the seconds left (9 pt)
  centered on the segment.
- Colors: combo points (0.95, 0.35, 0.2), holy power (1, 0.82, 0.25), runes
  (0.85, 0.2, 0.25; frost / unholy specs may use 0.3/0.7/1 and 0.4/0.85/0.3),
  soul shards (0.62, 0.35, 0.95), chi (0.45, 0.95, 0.75), arcane charges
  (0.45, 0.55, 1), essence (0.35, 0.85, 0.8).
- Totem bar: **as shown**. Four 32 px slots, 4 px apart, in the approved
  action button look (skin border); time left in `gold` 11 pt at the bottom of
  the icon; a 3 px `goldLine` bar under each slot that drains with the time
  left; an empty slot is a faint panel (50%) with a dim 1 px edge.
