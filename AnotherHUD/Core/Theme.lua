local ADDON, ns = ...

-- All look-and-feel values live here so the art can be swapped in one place.
-- Ported from AnotherLedger; the ledger-only parts (coins, rows, tabs, window
-- sizes, color presets) are left out.
local Theme = {}

Theme.textures = {
  -- No certain retail leather path; a flat tile tinted with colors.panelTint.
  parchment = "Interface\\Buttons\\WHITE8X8",
  -- Rounded window edge (tinted with colors.panelBorder); the fill sits inside
  -- its curve (sizes.backdropInset), so the corners read round.
  frameBorder = "Interface\\Tooltips\\UI-Tooltip-Border",
  resizeGrip = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
  -- Bronze buttons: a thin 1 px edge (tinted per state) and the icon glyphs.
  buttonEdge = "Interface\\Buttons\\WHITE8X8",
  iconGear = "Interface\\Icons\\Trade_Engineering",
  iconClose = "Interface\\Buttons\\UI-StopButton",
  buttonHighlight = "Interface\\Buttons\\ButtonHilight-Square",
  -- A plain white triangle pointing right (turned by the widgets, tinted).
  arrow = "Interface\\ChatFrame\\ChatFrameExpandArrow",
  -- Unit frames (tools/render_units.py): a white anti-aliased disc (ring
  -- lines, portrait and badge masks), a soft vertical glow and a shield.
  disc = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\Disc",
  spark = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\Spark",
  shield = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\Shield",
  -- Group frames: role glyphs (colored, 32 x 32), the leader crown (32 x 24)
  -- and a white 9-slice glow frame (slice margin Theme.sizes.unit.glowSlice).
  role = {
    TANK = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\RoleTank",
    HEALER = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\RoleHealer",
    DAMAGER = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\RoleDamage",
  },
  crown = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\Crown",
  -- Minimap calendar badge: a white calendar page (tinted gold in code).
  calendar = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\Calendar",
  glow = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\Glow",
  -- A plain white tile for 1 px lines (unit frame edges and dividers).
  line = "Interface\\Buttons\\WHITE8X8",
  -- The placeholder icon of Edit Mode samples (cast bar, auras).
  sampleIcon = "Interface\\Icons\\INV_Misc_QuestionMark",
}

-- Bar fill textures. The files are grey-scale vertical gradients normalized to
-- their brightest stop; the bar color is multiplied by `tint` (Theme.barColor)
-- so the middle of the bar reads as the color.
Theme.barTextures = {
  Smooth = { file = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\BarSmooth", tint = 1.25 },
  Flat = { file = "Interface\\Buttons\\WHITE8X8", tint = 1 },
  Gloss = { file = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\BarGloss", tint = 1.45 },
}

Theme.fonts = {
  title = "GameFontNormal",
  body = "GameFontHighlight",
  number = "GameFontHighlight",
  small = "GameFontHighlightSmall",
  button = "GameFontHighlightSmall", -- white; the disabled state stays gray
  buttonHighlight = "GameFontHighlightSmall",
  buttonDisabled = "GameFontDisableSmall",
  file = "Fonts\\FRIZQT__.TTF",
}

-- Dark leather look: a dark warm brown panel with light text and bronze
-- buttons. tests/test_theme.lua pins the contrast.
Theme.colors = {
  ink = { 1, 1, 1, 1 },
  gold = { 1.00, 0.82, 0.00, 1 },
  -- Bright gold for lines (divider, edge); not for text.
  goldLine = { 1.00, 0.82, 0.20, 1 },
  divider = { 1.00, 0.82, 0.20, 0.85 },
  -- Dark warm leather brown, fully opaque (an opacity option scales the alpha).
  panelTint = { 0.15, 0.10, 0.06, 1 },
  -- A shade lighter and warmer than the panel so the frame reads.
  panelBorder = { 0.55, 0.42, 0.24, 1 },
  hint = { 0.68, 0.63, 0.55, 1 },
  -- Bronze dark buttons and input boxes.
  buttonFill = { 0.10, 0.07, 0.04, 0.95 },
  buttonEdge = { 0.55, 0.42, 0.24, 1 },
  buttonEdgeHover = { 1.00, 0.82, 0.20, 1 },
  buttonText = { 1, 1, 1, 1 },
  buttonTextDisabled = { 0.50, 0.46, 0.38, 1 },
  buttonWarnEdge = { 0.62, 0.24, 0.17, 1 },
  buttonWarnEdgeHover = { 0.90, 0.36, 0.26, 1 },
  buttonWarnText = { 1.00, 0.70, 0.62, 1 },
  inputFill = { 0.06, 0.04, 0.02, 0.95 },
  -- Tooltips: gold title, tan labels, white values, quiet notes, red
  -- warnings and green click hints, like the game's own tooltips.
  tipTitle = { 1.00, 0.82, 0.00, 1 },
  tipLabel = { 0.80, 0.74, 0.62, 1 },
  tipValue = { 1, 1, 1, 1 },
  tipNote = { 0.68, 0.63, 0.55, 1 },
  tipWarn = { 0.95, 0.38, 0.32, 1 },
  tipHint = { 0.25, 0.90, 0.25, 1 },
  -- Minimap coordinates (quiet grey, mockup 7).
  coords = { 0.85, 0.85, 0.85, 1 },
}

-- Unit frame colors (approved art). Elite uses colors.gold and normal uses
-- colors.panelBorder for the ring (see Core/UnitColor.lua).
Theme.unitColors = {
  healthDefault = { 0.16, 0.62, 0.22, 1 },
  hostile = { 0.85, 0.20, 0.15, 1 },
  neutral = { 0.95, 0.82, 0.20, 1 },
  friendly = { 0.25, 0.75, 0.25, 1 },
  rare = { 0.78, 0.78, 0.81, 1 },
  cast = { 1.00, 0.74, 0.12, 1 },
  channel = { 0.35, 0.75, 0.35, 1 },
  interrupted = { 0.85, 0.20, 0.15, 1 },
  uninterruptible = { 0.60, 0.60, 0.62, 1 },
  -- The dark 1 px halo behind the portrait ring.
  ringShadow = { 0, 0, 0, 0.6 },
  -- Group frames: bar colors of a dead / offline member and the grey of the
  -- "Dead" / "Offline" text (the mockup's #bbb).
  dead = { 0.35, 0.35, 0.35, 1 },
  offline = { 0.3, 0.3, 0.3, 1 },
  deadText = { 0.733, 0.733, 0.733, 1 },
  debuff = {
    Magic = { 0.20, 0.60, 1.00, 1 },
    Curse = { 0.60, 0.00, 1.00, 1 },
    Poison = { 0.00, 0.60, 0.00, 1 },
    Disease = { 0.60, 0.40, 0.00, 1 },
    none = { 0.80, 0.00, 0.00, 1 },
  },
}

Theme.sizes = {
  padding = 8,
  -- Bronze buttons: edge thickness, fill inset, glyph padding of icon buttons.
  buttonEdge = 1,
  buttonInset = 1,
  iconButtonPad = 3,
  buttonHeight = 20,
  gripSize = 16,
  gripInset = 4,
  -- Window edge: the game tooltip's proportions (16 px edge, fill inset 5 px),
  -- so the square fill stays hidden behind the rounded corners.
  backdropTile = 16,
  backdropEdge = 16,
  backdropInset = 5,
  -- Skins: how far a sunken list box reaches past its list.
  listBoxPad = 3,
  -- How close (px) an edge or the center of a dragged AnotherHUD frame has
  -- to be to a screen line or another AnotherHUD frame to snap onto it.
  snapDistance = 8,
  -- Unit frames.
  unit = { badge = 18, focusBadge = 14, auraGap = 2, auraBelowCast = 6, castIcon = 18,
    castIconEdge = 2, auraTextShare = 0.42, barBgAlpha = 0.18,
    interruptHold = 0.6, badgeFont = 10, glowSlice = 12,
    -- Bar texts: the font size before a layout sets one, and the share of
    -- the health bar width the name may take (the value text keeps the rest).
    textFont = 11, nameShare = 0.6,
    -- The share of the cast bar width the spell name may take (the time
    -- keeps the rest).
    castNameShare = 0.8,
    -- Cast bar (docs/mockups/units.js cast): the spark's width and how far
    -- it reaches past the bar top and bottom, the texts' inset in the bar,
    -- the shield over the icon (offset and size as shares of the bar
    -- height).
    castSparkWidth = 4, castSparkOverhang = 2, castTextInset = 3,
    castShield = { x = 0.15, y = 0.1, w = 0.7, h = 0.8 },
    -- Spell and aura icons: the share cut off each side of the icon art (its
    -- baked-in frame).
    iconCrop = 0.08,
    -- Group frames: role badge and leader crown, how far the crown sits above
    -- the ring, out-of-range alpha and the range check interval, the gaps of
    -- the aura rows and the boss cast bar, the dispel glow and its edge.
    roleBadge = 15, crown = 12, crownLift = 7, rangeAlpha = 0.55, rangeTick = 0.5,
    partyAuraGap = 6, bossAuraGap = 4, bossCastGap = 4, glow = 8, glowEdge = 2 },
  -- Class resource bar: the attached bar's height and its gap to the Player
  -- frame, the detached size, the shade of a partial point, the seconds font,
  -- the most segments and the update interval (s).
  resource = { attachedHeight = 18, gap = 4, detachedWidth = 200, detachedHeight = 20,
    partialShade = 0.55, timerFont = 9, maxSegments = 10, tick = 0.1 },
  -- XP / Reputation bar: width and height of one bar, the gap between the two,
  -- the alpha of the rested XP band and the text font size.
  tracking = { width = 500, height = 10, gap = 1, restedAlpha = 0.4, textFont = 10 },
  -- Minimap (approved mockup 7): the default map size; the zone, clock and
  -- coordinate fonts; the gap of the zone / clock to the map; the clock's
  -- shift left of the middle; the calendar badge, its shift right and its
  -- drop below the map; the coordinates' drop; the icon share of a badge;
  -- the badge glow; the clock and coordinate update intervals (s).
  minimap = { size = 180, zoneFont = 12, clockFont = 11, coordFont = 10, textGap = 4, clockShift = 14,
    calendarBadge = 18, calendarShift = 20, calendarDrop = 11, coordDrop = 22, badgeIcon = 0.6, glow = 8,
    clockTick = 1, coordTick = 0.2 },
}

-- Minimap zone name colors by PvP type, {r, g, b} (the game's zone text
-- colors); `normal` for any other zone.
Theme.minimapZoneColors = {
  sanctuary = { 0.41, 0.80, 0.94 },
  friendly = { 0.10, 1.00, 0.10 },
  hostile = { 1.00, 0.10, 0.10 },
  arena = { 1.00, 0.10, 0.10 },
  combat = { 1.00, 0.10, 0.10 },
  contested = { 1.00, 0.70, 0.00 },
  normal = { 1.00, 0.82, 0.00 },
}

-- XP / Reputation bar colors, {r, g, b}: the game's usual XP purple and
-- rested blue, and the standard reputation colors by reaction (1 Hated .. 8
-- Exalted), the fallback when the client's FACTION_BAR_COLORS is missing.
Theme.trackingColors = {
  xp = { 0.58, 0, 0.55 },
  rested = { 0, 0.39, 0.88 },
  -- the approved honor row color (mockup 6)
  honor = { 1, 0.24, 0 },
  reaction = {
    [1] = { 0.8, 0.3, 0.22 }, [2] = { 0.8, 0.3, 0.22 }, [3] = { 0.75, 0.27, 0 },
    [4] = { 0.9, 0.7, 0 }, [5] = { 0, 0.6, 0.1 }, [6] = { 0, 0.6, 0.1 },
    [7] = { 0, 0.6, 0.1 }, [8] = { 0, 0.6, 0.1 },
  },
}

-- Class resource bar colors (approved art): one per resource, {r, g, b}.
Theme.resourceColors = {
  combo = { 0.95, 0.35, 0.2 },
  holy = { 1, 0.82, 0.25 },
  runes = { 0.85, 0.2, 0.25 },
  runesFrost = { 0.3, 0.7, 1 },
  runesUnholy = { 0.4, 0.85, 0.3 },
  shards = { 0.62, 0.35, 0.95 },
  chi = { 0.45, 0.95, 0.75 },
  arcane = { 0.45, 0.55, 1 },
  essence = { 0.35, 0.85, 0.8 },
}

-- The portrait ring's line shades (outside in) for the Round border, which
-- has no edge lines: the mockup's soft tooltip-like edge. The other borders
-- use the shades of Theme.edgeRects.
Theme.ringRoundShades = { 0.35, 1, 1, 0.45 }

-- Pure. The color to give a status bar with texture `textureName`: the color
-- times the texture's tint, each channel clamped to 1. An unknown name is
-- Smooth.
function Theme.barColor(color, textureName)
  local t = Theme.barTextures[textureName] or Theme.barTextures.Smooth
  local k = t.tint
  return math.min(1, color[1] * k), math.min(1, color[2] * k), math.min(1, color[3] * k)
end

-- Pure. A color with r, g, b multiplied by `k` (clamped to 0..1); alpha kept.
function Theme.scaleColor(c, k)
  if type(k) ~= "number" or k ~= k then k = 1 end
  local function ch(v) return math.min(1, math.max(0, (v or 0) * k)) end
  return { ch(c[1]), ch(c[2]), ch(c[3]), c[4] or 1 }
end

-- Pure. "rrggbb" (a leading "#" allowed, any case) -> r, g, b in 0..1; nil
-- for anything else.
function Theme.hexToRGB(hex)
  if type(hex) ~= "string" then return nil end
  local r, g, b = hex:match("^#?(%x%x)(%x%x)(%x%x)$")
  if not r then return nil end
  return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- Pure. A color {r, g, b[, a]} -> "rrggbb" (lower case; alpha left out).
function Theme.colorToHex(c)
  local function byte(v) return math.min(255, math.max(0, math.floor((v or 0) * 255 + 0.5))) end
  return string.format("%02x%02x%02x", byte(c[1]), byte(c[2]), byte(c[3]))
end

-- Sets the r, g, b of Theme.colors[key] from "rrggbb", in place (every UI part
-- holding the table sees the new color; alpha kept). Returns the table, or
-- nil for an unknown key or bad hex.
function Theme.setColor(key, hex)
  local c = Theme.colors[key]
  local r, g, b = Theme.hexToRGB(hex)
  if type(c) ~= "table" or not r then return nil end
  c[1], c[2], c[3] = r, g, b
  return c
end

-- ---------------------------------------------------------------------------
-- Skins: the shape of the window border, the buttons and the lines, and the
-- sunken list box. They never change colors: every style is tinted with
-- Theme.colors.

-- The choices of each part, in option order.
Theme.skinParts = {
  border = { "round", "bevel", "thin" },
  buttons = { "bronze", "raised", "flat" },
  lines = { "gold", "groove", "plain" },
}

-- Skins by id; Theme.skinOrder is the order of the choice list. Classic is
-- the default.
Theme.skins = {
  classic = { id = "classic", label = "Classic", border = "round", buttons = "bronze",
    lines = "gold", listBox = false },
  forge = { id = "forge", label = "Forge", border = "bevel", buttons = "raised",
    lines = "groove", listBox = true },
  slate = { id = "slate", label = "Slate", border = "thin", buttons = "flat",
    lines = "plain", listBox = false },
}
Theme.skinOrder = { "classic", "forge", "slate" }

-- How the styles shade the theme colors: the dark edge lines, the groove's
-- dark / light line, the raised buttons' light / dark edge, how far Plain
-- moves a line color toward grey and the panel, the sunken list fill.
Theme.skinScales = {
  edgeDark = 0.2, edgeLight = 1.7, grooveDark = 0.3, grooveLight = 2.0, grooveLightAlpha = 0.55,
  raisedLight = 3.5, raisedDark = 0.3, plainMix = 0.5, listBox = 0.5,
}

-- The active picks; the options write them with Theme.setStyle.
Theme.style = { border = "round", buttons = "bronze", lines = "gold", listBox = false }

function Theme.skin(id)
  return Theme.skins[id]
end

-- Stores one pick; false (nothing stored) for an unknown part or value.
function Theme.setStyle(part, value)
  if part == "listBox" then
    if type(value) ~= "boolean" then return false end
    Theme.style.listBox = value
    return true
  end
  local list = Theme.skinParts[part]
  if not list then return false end
  for _, v in ipairs(list) do
    if v == value then
      Theme.style[part] = value
      return true
    end
  end
  return false
end

-- The SetBackdrop table of a window: Round keeps the tooltip edge; the
-- other borders are drawn as lines (Theme.edgeRects), so the fill reaches
-- the frame's edge.
function Theme.backdropSpec(border)
  local S = Theme.sizes
  local bg, tileSize = Theme.textures.parchment, S.backdropTile
  if border == "round" then
    local inset = S.backdropInset
    return { bgFile = bg, edgeFile = Theme.textures.frameBorder, tile = true, tileSize = tileSize,
      edgeSize = S.backdropEdge, insets = { left = inset, right = inset, top = inset, bottom = inset } }
  end
  return { bgFile = bg, tile = true, tileSize = tileSize,
    insets = { left = 0, right = 0, top = 0, bottom = 0 } }
end

-- The line rectangles of a border: inset (px from the frame edge) and shade
-- (a factor on the border color). Round has none (the backdrop edge).
function Theme.edgeRects(border)
  local d, l = Theme.skinScales.edgeDark, Theme.skinScales.edgeLight
  if border == "thin" then return { { inset = 0, shade = d }, { inset = 1, shade = 1 } } end
  if border == "bevel" then
    return { { inset = 0, shade = d }, { inset = 1, shade = l }, { inset = 2, shade = 1 },
      { inset = 3, shade = 1 }, { inset = 4, shade = d } }
  end
  return {}
end

-- Pure. `a` moved toward `b` by t (0..1); alpha of `a`.
function Theme.mix(a, b, t)
  local function m(i) return a[i] + (b[i] - a[i]) * t end
  return { m(1), m(2), m(3), a[4] or 1 }
end

-- The colors of a styled line in `lines` style: the main line and, for
-- Groove, the light line under it. Plain takes the line color halfway to grey
-- (losing the gold) and then halfway to the panel. Alpha kept.
local GREY = { 0.5, 0.5, 0.5 }
function Theme.lineColors(lines, color, panel)
  local k = Theme.skinScales
  if lines == "groove" then
    return Theme.scaleColor(color, k.grooveDark), Theme.scaleColor(color, k.grooveLight)
  elseif lines == "plain" then
    return Theme.mix(Theme.mix(color, GREY, k.plainMix), panel, k.plainMix), nil
  end
  return color, nil
end

-- WCAG 2 contrast ratio (1..21) between two sRGB colors (components 0..1).
local function linear(c)
  if c <= 0.03928 then return c / 12.92 end
  return ((c + 0.055) / 1.055) ^ 2.4
end
local function luminance(r, g, b)
  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end
function Theme.contrast(r1, g1, b1, r2, g2, b2)
  local x, y = luminance(r1, g1, b1), luminance(r2, g2, b2)
  if x < y then x, y = y, x end
  return (x + 0.05) / (y + 0.05)
end

-- Text on a colored fill: `color` when it stands out enough
-- (Theme.MIN_TEXT_CONTRAST), else a near-black or white text, whichever
-- reads better on `fill`. `dim`: the dimmed variant (a disabled button).
Theme.MIN_TEXT_CONTRAST = 3
local DARK, LIGHT = { 0.08, 0.06, 0.04, 1 }, { 1, 1, 1, 1 }
local DARK_DIM, LIGHT_DIM = { 0.08, 0.06, 0.04, 0.55 }, { 1, 1, 1, 0.55 }
function Theme.readableOn(color, fill, dim)
  local r, g, b = fill[1], fill[2], fill[3]
  if Theme.contrast(color[1], color[2], color[3], r, g, b) >= Theme.MIN_TEXT_CONTRAST then return color end
  local dark = Theme.contrast(DARK[1], DARK[2], DARK[3], r, g, b) >= Theme.contrast(1, 1, 1, r, g, b)
  if dim then return dark and DARK_DIM or LIGHT_DIM end
  return dark and DARK or LIGHT
end

ns.Theme = Theme
