local ADDON, ns = ...

-- The segmented bar widget behind the class resource bar: one panel in the
-- skin border, the inner area split into equal slots by 1 px dividers in the
-- skin's Lines pick. Per slot: a background in the resource color at
-- Theme.sizes.unit.barBgAlpha, a `partial` StatusBar (55% of the color) and a
-- `full` StatusBar (the color) above it, and the seconds left on top. Values
-- may be secret: they are only passed on to widget calls. Plain frames and
-- textures, nothing secure.
ns.Bars = ns.Bars or {}

local Segments = {}
Segments.__index = Segments

local function statusBar(parent, level)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetFrameLevel(level)
  return bar
end

-- Slot `i`, created on demand (hidden until a layout shows it).
local function slot(self, i)
  local s = self.slots[i]
  if s then return s end
  s = {}
  s.bg = self.frame:CreateTexture(nil, "BACKGROUND")
  s.partial = statusBar(self.frame, self.levels.partial)
  s.full = statusBar(self.frame, self.levels.full)
  s.full:SetMinMaxValues(i - 1, i)
  s.partial:SetMinMaxValues(0, 1)
  s.partial:SetValue(0)
  s.text = self.top:CreateFontString(nil, "OVERLAY")
  s.text:SetFont(ns.Theme.fonts.file, ns.Theme.sizes.resource.timerFont, "OUTLINE")
  s.text:SetWordWrap(false)
  s.text:SetText("")
  s.bg:Hide()
  s.partial:Hide()
  s.full:Hide()
  s.text:Hide()
  self.slots[i] = s
  return s
end

-- Frame levels, bottom up: the panel, the slots' backgrounds (on `frame`),
-- the partial bars, the full bars, then the dividers and texts (on `top`).
function Segments.create(parent)
  local base = parent:GetFrameLevel() or 0
  local levels = { panel = base + 1, frame = base + 2, partial = base + 3, full = base + 4, top = base + 5 }
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)
  frame:SetFrameLevel(levels.frame)
  local self = setmetatable({ frame = frame, parent = parent, levels = levels,
    slots = {}, dividers = {}, grooves = {}, count = 0 }, Segments)
  self.panel = ns.Units.Parts.Panel.create(parent)
  self.panel.frame:SetFrameLevel(levels.panel)
  local top = CreateFrame("Frame", nil, frame)
  top:SetAllPoints(frame)
  top:SetFrameLevel(levels.top)
  self.top = top
  return self
end

-- Paints divider texture `d` (and `groove`, the second line) in the skin's
-- Lines pick `lines`, as in Units/Parts/Bars.lua: Gold and Dotted at the
-- divider alpha, Groove a dark line (alpha 1) with a light one next to it,
-- Plain greyed toward the panel (alpha 1). Returns true when the skin has a
-- second line (the caller places and shows `groove`, else hides it). Shared
-- with the XP / Reputation bar (Bars/Tracking.lua).
function Segments.paintDivider(d, groove, lines)
  local T = ns.Theme
  local main, second = T.lineColors(lines, T.colors.goldLine, T.colors.panelTint)
  local alpha = 1
  if lines ~= "groove" and lines ~= "plain" then alpha = T.colors.divider[4] end
  local dotted = false
  if lines == "dotted" then
    dotted = d:SetTexture(T.textures.skinDotted, "REPEAT", "CLAMP") ~= false
  end
  if not dotted then d:SetTexture(T.textures.line) end
  d:SetHorizTile(dotted)
  d:SetVertexColor(main[1], main[2], main[3], alpha)
  if second then
    groove:SetTexture(T.textures.line)
    groove:SetVertexColor(second[1], second[2], second[3], T.skinScales.grooveLightAlpha)
  end
  return second ~= nil
end

-- Divider `i` (made on demand) painted for `lines`; returns it and the
-- groove texture when the skin has a second line.
local function divider(self, i, lines)
  local d = self.dividers[i]
  if not d then
    d = self.top:CreateTexture(nil, "OVERLAY")
    self.dividers[i] = d
    self.grooves[i] = self.top:CreateTexture(nil, "OVERLAY")
  end
  local groove = self.grooves[i]
  local second = Segments.paintDivider(d, groove, lines)
  return d, second and groove or nil
end

-- o = { w, h, count, skin, texture (Theme.barTextures name), rgb }.
function Segments:layout(o)
  local T = ns.Theme
  local skin = o.skin or T.skins.classic
  local frame = self.frame
  self.panel:layout({ studCorners = {} }, { skin = skin })

  local e = ns.UnitLayout.edgeWidth(skin.border)
  local count = o.count
  local sw = (o.w - 2 * e - (count - 1)) / count
  local ih = o.h - 2 * e
  local file = (T.barTextures[o.texture] or T.barTextures.Smooth).file
  local r, g, b = T.barColor(o.rgb, o.texture)
  local pr, pg, pb = T.barColor(T.scaleColor(o.rgb, T.sizes.resource.partialShade), o.texture)
  for i = 1, count do
    local s = slot(self, i)
    local x = e + (i - 1) * (sw + 1)
    s.bg:ClearAllPoints()
    s.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -e)
    s.bg:SetSize(sw, ih)
    s.bg:SetTexture(file)
    s.bg:SetVertexColor(r, g, b, T.sizes.unit.barBgAlpha)
    for _, bar in ipairs({ s.partial, s.full }) do
      bar:ClearAllPoints()
      bar:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -e)
      bar:SetSize(sw, ih)
      bar:SetStatusBarTexture(file)
    end
    s.partial:SetStatusBarColor(pr, pg, pb)
    s.full:SetStatusBarColor(r, g, b)
    s.full:SetMinMaxValues(i - 1, i)
    s.text:ClearAllPoints()
    s.text:SetPoint("CENTER", s.bg, "CENTER", 0, 0)
    s.text:SetFont(T.fonts.file, T.sizes.resource.timerFont, "OUTLINE")
    s.bg:Show()
    s.partial:Show()
    s.full:Show()
    s.text:Show()
  end
  for i = count + 1, #self.slots do
    local s = self.slots[i]
    s.bg:Hide()
    s.partial:Hide()
    s.full:Hide()
    s.text:Hide()
  end

  for i = 1, count - 1 do
    local d, groove = divider(self, i, skin.lines)
    local x = e + i * sw + (i - 1)
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -e)
    d:SetSize(1, ih)
    d:Show()
    local gr = self.grooves[i]
    if groove then
      gr:ClearAllPoints()
      gr:SetPoint("TOPLEFT", frame, "TOPLEFT", x + 1, -e)
      gr:SetSize(1, ih)
      gr:Show()
    else
      gr:Hide()
    end
  end
  for i = math.max(count, 1), #self.dividers do
    self.dividers[i]:Hide()
    self.grooves[i]:Hide()
  end
  self.count = count
end

-- `value` may be secret: straight to every full bar.
function Segments:setPoints(value)
  for i = 1, self.count do
    self.slots[i].full:SetValue(value)
  end
end

-- `raw` may be secret; `mod` is a plain number (the fragments per point).
function Segments:setFragments(raw, mod)
  for i = 1, self.count do
    local p = self.slots[i].partial
    p:SetMinMaxValues((i - 1) * mod, i * mod)
    p:SetValue(raw)
  end
end

-- Plain numbers only: slot `i`'s partial filled to `fill` (0..1) with the
-- seconds left as its text; the full bar is left alone.
function Segments:setPartial(i, fill, left)
  local s = slot(self, i)
  s.partial:SetMinMaxValues(0, 1)
  s.partial:SetValue(fill)
  s.text:SetText(ns.Resource.timerText(left))
end

-- Plain numbers only, for runes: a ready slot is full, any other is empty
-- with its partial and timer.
function Segments:setSlot(i, fill, left)
  local s = slot(self, i)
  if fill >= 1 then
    s.full:SetValue(i)
    s.partial:SetMinMaxValues(0, 1)
    s.partial:SetValue(0)
    s.text:SetText("")
  else
    s.full:SetValue(i - 1)
    self:setPartial(i, fill, left)
  end
end

function Segments:clearPartials()
  for _, s in ipairs(self.slots) do
    s.partial:SetMinMaxValues(0, 1)
    s.partial:SetValue(0)
    s.text:SetText("")
  end
end

ns.Bars.Segments = Segments
