local ADDON, ns = ...

-- The portrait ring: the skin's border lines bent into a circle as a stack of
-- tinted discs (disc i, 0-based, has diameter dia - 2*i; each smaller disc
-- leaves a 1 px line of the one under it), the round portrait on top, Gilded
-- studs, and the level badge (a small disc stack with the panel fill and a
-- gold number). Plain frames and textures, nothing secure.
ns.Units = ns.Units or {}
ns.Units.Parts = ns.Units.Parts or {}

local unpack = unpack or rawget(table, "unpack")

local Ring = {}
Ring.__index = Ring

local STUD_ANGLES = { 45, 135, 225, 315 }

local function tint(tex, c)
  tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

-- The ring line shades (outside in) of a border.
local function shades(border)
  local T = ns.Theme
  if border == "round" then return T.ringRoundShades end
  local list = {}
  for i, r in ipairs(T.edgeRects(border)) do list[i] = r.shade end
  return list
end

local function disc(frame, layer, sub)
  local t = frame:CreateTexture(nil, layer, nil, sub)
  t:SetTexture(ns.Theme.textures.disc)
  return t
end

-- Centers `tex` (size dia) on (x, y) frame pixels of `frame`.
local function place(tex, frame, x, y, dia)
  tex:ClearAllPoints()
  tex:SetPoint("CENTER", frame, "TOPLEFT", x, -y)
  tex:SetSize(dia, dia)
end

function Ring.create(parent)
  local T = ns.Theme
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)
  frame:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)
  local self = setmetatable({ frame = frame, parent = parent, lines = {}, studs = {}, badgeLines = {},
    ringColor = T.colors.panelBorder, badgeColor = T.colors.panelBorder, shades = {} }, Ring)

  self.shadow = disc(frame, "BACKGROUND", 0)
  self.portrait = frame:CreateTexture(nil, "ARTWORK")
  -- UNVERIFIED (check in client): a MaskTexture with the disc file clips the
  -- square portrait to a circle.
  self.mask = frame:CreateMaskTexture()
  self.mask:SetTexture(T.textures.disc, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  self.mask:SetAllPoints(self.portrait)
  self.portrait:AddMaskTexture(self.mask)
  for i = 1, 4 do
    local s = frame:CreateTexture(nil, "OVERLAY")
    s.loaded = s:SetTexture(T.textures.skinStud) ~= false
    s:Hide()
    self.studs[i] = s
  end

  local badge = CreateFrame("Frame", nil, frame)
  badge:SetAllPoints(frame)
  badge:SetFrameLevel((frame:GetFrameLevel() or 0) + 1)
  self.badge = badge
  self.badgeFill = disc(badge, "ARTWORK", 0)
  self.level = badge:CreateFontString(nil, "OVERLAY")
  self.level:SetFont(T.fonts.file, T.sizes.unit.badgeFont, "OUTLINE")
  self.level:SetJustifyH("CENTER")
  return self
end

-- Shows `n` discs of `list` (made on demand on `frame`), hides the rest.
local function stack(list, frame, n)
  for i = 1, n do
    list[i] = list[i] or disc(frame, "BORDER", math.min(7, i - 1))
    list[i]:Show()
  end
  for i = n + 1, #list do list[i]:Hide() end
end

function Ring:paint()
  local T = ns.Theme
  for i, k in ipairs(self.shades) do
    tint(self.lines[i], T.scaleColor(self.ringColor, k))
    tint(self.badgeLines[i], T.scaleColor(self.badgeColor, k))
  end
  for _, s in ipairs(self.studs) do tint(s, self.ringColor) end
  tint(self.shadow, T.unitColors.ringShadow)
  tint(self.badgeFill, T.colors.panelTint)
  local g = T.colors.gold
  self.level:SetTextColor(g[1], g[2], g[3], g[4] or 1)
end

-- opts = { skin } (a Theme.skins entry).
function Ring:layout(L, opts)
  local T = ns.Theme
  local frame, r = self.frame, L.ring
  local border = opts.skin.border
  local list = shades(border)
  local n = #list
  self.shades = list

  place(self.shadow, frame, r.cx, r.cy, r.dia + 2)
  stack(self.lines, frame, n)
  for i = 1, n do place(self.lines[i], frame, r.cx, r.cy, r.dia - 2 * (i - 1)) end
  -- The portrait fills the innermost disc's inside; its soft edge blends
  -- into the innermost line.
  place(self.portrait, frame, r.cx, r.cy, r.dia - 2 * n)

  local showStuds = T.edgeStuds(border) and L.ringStuds
  local rr = r.dia / 2 - n / 2
  for i, s in ipairs(self.studs) do
    local a = STUD_ANGLES[i] * math.pi / 180
    place(s, frame, r.cx + rr * math.cos(a), r.cy + rr * math.sin(a), T.sizes.unit.ringStud)
    if showStuds and s.loaded then s:Show() else s:Hide() end
  end

  stack(self.badgeLines, self.badge, n)
  local b = L.badge
  if b then
    for i = 1, n do place(self.badgeLines[i], self.badge, b.cx, b.cy, b.size - 2 * (i - 1)) end
    place(self.badgeFill, self.badge, b.cx, b.cy, b.size - 2 * n)
    self.level:ClearAllPoints()
    self.level:SetPoint("CENTER", self.badge, "TOPLEFT", b.cx, -b.cy)
    self.badge:Show()
  else
    self.badge:Hide()
  end
  self:paint()
end

-- ringColor, badgeColor: color tables (Core/UnitColor.lua UnitColor.ring).
function Ring:setColors(ringColor, badgeColor)
  self.ringColor = ringColor or ns.Theme.colors.panelBorder
  self.badgeColor = badgeColor or self.ringColor
  self:paint()
end

-- UNVERIFIED (check in client): SetPortraitTexture(tex, unit, true) for a
-- unit whose identity is secret (instances) draws without a Lua error.
function Ring:setUnit(unit)
  self.unit = unit
  if unit then SetPortraitTexture(self.portrait, unit, true) end
end

-- fmt, args from UnitText.level; the level may be secret and only travels on.
-- UNVERIFIED (check in client): SetFormattedText with a secret "%d" argument.
function Ring:setLevel(fmt, args)
  if not fmt or fmt == "" then
    self.level:SetText("")
  else
    self.level:SetFormattedText(fmt, unpack(args or {}))
  end
end

ns.Units.Parts.Ring = Ring
