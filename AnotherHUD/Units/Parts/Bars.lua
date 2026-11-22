local ADDON, ns = ...

-- The unit frame bars: health and power StatusBars (texture plus a background
-- in the bar color at Theme.sizes.unit.barBgAlpha), the 1 px divider between
-- them in the skin's Lines pick, and the name / health / power texts. Values
-- and texts may be secret: they are only passed on to widget calls. Plain
-- frames and textures, nothing secure.
ns.Units = ns.Units or {}
ns.Units.Parts = ns.Units.Parts or {}

local unpack = unpack or rawget(table, "unpack")

local Bars = {}
Bars.__index = Bars

local function statusBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(bar)
  return bar
end

local function font(parent)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  -- A font from the start, so texts set before the first layout show.
  fs:SetFont(ns.Theme.fonts.file, ns.Theme.sizes.unit.textFont, "OUTLINE")
  fs:SetWordWrap(false)
  return fs
end

local function line(parent)
  return parent:CreateTexture(nil, "OVERLAY")
end

-- Frame levels, bottom up: the Groove light line (on `frame` itself, under
-- the bars, which cover it as in the mockup), the bars, then the divider and
-- the texts (on `top`).
function Bars.create(parent)
  local base = parent:GetFrameLevel() or 0
  local levels = { groove = base + 1, power = base + 2, divider = base + 3 }
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)
  frame:SetFrameLevel(levels.groove)
  local self = setmetatable({ frame = frame, parent = parent, levels = levels }, Bars)
  self.health = statusBar(frame)
  self.power = statusBar(frame)
  self.health:SetFrameLevel(levels.power)
  self.power:SetFrameLevel(levels.power)
  self.groove = line(frame)
  local top = CreateFrame("Frame", nil, frame)
  top:SetAllPoints(frame)
  top:SetFrameLevel(levels.divider)
  self.top = top
  self.divider = line(top)
  self.name = font(top)
  self.healthText = font(top)
  self.powerText = font(top)
  self.healthRGB = ns.Theme.unitColors.healthDefault
  return self
end

-- Places `region` from x1 to x2 (frame pixels) at y, `height` high.
local function span(region, frame, L, x1, x2, y, height)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", frame, "TOPLEFT", x1, -y)
  region:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(L.w - x2), -y)
  region:SetHeight(height)
end

local function paintBar(bar, rgb, texture)
  local T = ns.Theme
  local r, g, b = T.barColor(rgb, texture)
  bar:SetStatusBarColor(r, g, b)
  bar.bg:SetVertexColor(r, g, b, T.sizes.unit.barBgAlpha)
end

function Bars:paint()
  local tex = self.texture or "Smooth"
  paintBar(self.health, self.healthRGB, tex)
  if self.powerRGB then paintBar(self.power, self.powerRGB, tex) end
end

-- The divider in the skin's Lines pick (docs/mockups/kit.js `rule`): Gold
-- and Dotted at the divider alpha, Groove a dark line (alpha 1) with a light
-- one under it (grooveLightAlpha), Plain greyed toward the panel (alpha 1).
local function styleDivider(self, lines)
  local T = ns.Theme
  local main, second = T.lineColors(lines, T.colors.goldLine, T.colors.panelTint)
  local alpha = 1
  if lines ~= "groove" and lines ~= "plain" then alpha = T.colors.divider[4] end
  local d = self.divider
  local dotted = false
  if lines == "dotted" then
    dotted = d:SetTexture(T.textures.skinDotted, "REPEAT", "CLAMP") ~= false
  end
  if not dotted then d:SetTexture(T.textures.line) end
  d:SetHorizTile(dotted)
  d:SetVertexColor(main[1], main[2], main[3], alpha)
  if second then
    self.groove:SetTexture(T.textures.line)
    self.groove:SetVertexColor(second[1], second[2], second[3], T.skinScales.grooveLightAlpha)
  end
  return second ~= nil
end

local function setFont(fs, size)
  fs:SetFont(ns.Theme.fonts.file, size, "OUTLINE")
end

-- Puts `fs` with its `side` ("LEFT" / "RIGHT") at x (frame pixels), centered
-- on y.
local function anchorText(fs, frame, side, x, y)
  fs:ClearAllPoints()
  fs:SetPoint(side, frame, "TOPLEFT", x, -y)
  fs:SetJustifyH(side)
end

-- opts = { texture (Theme.barTextures name), fontSize, showName, mirror, skin }
function Bars:layout(L, opts)
  local T = ns.Theme
  local frame, bars = self.frame, L.bars
  local file = (T.barTextures[opts.texture] or T.barTextures.Smooth).file
  self.texture = opts.texture
  for _, bar in ipairs({ self.health, self.power }) do
    bar:SetStatusBarTexture(file)
    bar.bg:SetTexture(file)
  end

  local hs = L.health
  span(self.health, frame, L, bars.left, bars.right, hs.top, hs.bottom - hs.top)

  local p = L.power
  if p then
    span(self.power, frame, L, bars.left, bars.right, p.top, p.bottom - p.top)
    span(self.divider, frame, L, bars.left, bars.right, p.top - 1, 1)
    local skin = opts.skin or T.skins.classic -- Classic when missing, like Panel / Ring
    local groove = styleDivider(self, skin.lines)
    span(self.groove, frame, L, bars.left, bars.right, p.top, 1)
    self.power:Show()
    self.divider:Show()
    if groove then self.groove:Show() else self.groove:Hide() end
  else
    self.power:Hide()
    self.divider:Hide()
    self.groove:Hide()
  end

  -- Texts (units.js): the name next to the ring, the values at the far end,
  -- 4 px inside the bar, centered on their bar.
  local hh = hs.bottom - hs.top
  local size = opts.fontSize or math.max(9, math.min(11, math.floor(hh * 0.28 + 0.5)))
  local midH = hs.top + hh / 2
  local near, far = bars.left + 4, bars.right - 4
  local nearSide, farSide = "LEFT", "RIGHT"
  if opts.mirror then
    near, far = bars.right - 4, bars.left + 4
    nearSide, farSide = "RIGHT", "LEFT"
  end
  setFont(self.name, size)
  setFont(self.healthText, size)
  anchorText(self.name, frame, nearSide, near, midH)
  anchorText(self.healthText, frame, farSide, far, midH)
  -- The name takes nameShare of the bar, the value the rest (4 px insets).
  local bw, share = bars.right - bars.left, T.sizes.unit.nameShare
  self.name:SetWidth(bw * share - 4)
  self.healthText:SetWidth(bw * (1 - share) - 4)
  if opts.showName == false then self.name:Hide() else self.name:Show() end

  if p and L.powerText then
    setFont(self.powerText, L.powerText.size)
    anchorText(self.powerText, frame, farSide, far, p.top + (p.bottom - p.top) / 2)
    self.powerText:Show()
  else
    self.powerText:Hide()
  end
  self:paint()
end

-- healthRGB, powerRGB: { r, g, b } (powerRGB nil keeps the last one).
function Bars:setColors(healthRGB, powerRGB)
  if healthRGB then self.healthRGB = healthRGB end
  if powerRGB then self.powerRGB = powerRGB end
  self:paint()
end

-- cur / max may be secret: straight to the widget.
function Bars:setHealth(cur, max)
  self.health:SetMinMaxValues(0, max)
  self.health:SetValue(cur)
end

function Bars:setPower(cur, max)
  self.power:SetMinMaxValues(0, max)
  self.power:SetValue(cur)
end

local function formatted(fs, fmt, args)
  if not fmt or fmt == "" then
    fs:SetText("")
  else
    -- UNVERIFIED (check in client): SetFormattedText with secret arguments.
    fs:SetFormattedText(fmt, unpack(args or {}))
  end
end

-- name may be secret; fmt / args from UnitText.bar.
function Bars:setTexts(name, healthFmt, healthArgs, powerFmt, powerArgs)
  self.name:SetText(name)
  formatted(self.healthText, healthFmt, healthArgs)
  formatted(self.powerText, powerFmt, powerArgs)
end

ns.Units.Parts.Bars = Bars
