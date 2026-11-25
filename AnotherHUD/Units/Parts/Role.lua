local ADDON, ns = ...

-- Group frames: the role badge (a small disc stack in the skin's line shades
-- with the panel fill and a colored glyph at 72% of the badge, at the ring's
-- lower left) and the leader crown on top of the ring. The role and leader
-- flags can be secret in restricted contexts: they are read only when
-- readable, a secret one hides the badge / crown. Plain frames and textures.
ns.Units = ns.Units or {}
ns.Units.Parts = ns.Units.Parts or {}

local Role = {}
Role.__index = Role

local GLYPH_SHARE = 0.72
local CROWN_RATIO = 0.75 -- the crown file is 32 x 24

local function tint(tex, c)
  tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

function Role.create(parent)
  local T = ns.Theme
  local Ring = ns.Units.Parts.Ring
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)
  frame:SetFrameLevel((parent:GetFrameLevel() or 0) + 6)
  local self = setmetatable({ frame = frame, parent = parent, lines = {}, shades = {},
    color = T.colors.panelBorder }, Role)
  self.badge = CreateFrame("Frame", nil, frame)
  self.badge:SetAllPoints(frame)
  self.fill = Ring.disc(self.badge, "ARTWORK", 0)
  self.glyph = self.badge:CreateTexture(nil, "OVERLAY")
  self.crown = frame:CreateTexture(nil, "OVERLAY")
  self.crown:SetTexture(T.textures.crown)
  self.crown:Hide()
  self.badge:Hide()
  return self
end

-- opts = { skin } (a Theme.skins entry; Classic when missing).
function Role:layout(L, opts)
  local T = ns.Theme
  local Ring = ns.Units.Parts.Ring
  local border = ((opts and opts.skin) or T.skins.classic).border
  local list = Ring.shadesOf(border)
  local n = #list
  self.shades = list
  self.L = L
  local b = L.role
  if b then
    for i = 1, n do
      self.lines[i] = self.lines[i] or Ring.disc(self.badge, "BORDER", math.min(7, i - 1))
      self.lines[i]:Show()
      Ring.place(self.lines[i], self.badge, b.cx, b.cy, b.size - 2 * (i - 1))
      tint(self.lines[i], T.scaleColor(self.color, list[i]))
    end
    for i = n + 1, #self.lines do self.lines[i]:Hide() end
    Ring.place(self.fill, self.badge, b.cx, b.cy, b.size - 2 * n)
    tint(self.fill, T.colors.panelTint)
    local g = b.size * GLYPH_SHARE
    self.glyph:ClearAllPoints()
    self.glyph:SetPoint("CENTER", self.badge, "TOPLEFT", b.cx, -b.cy)
    self.glyph:SetSize(g, g)
  end
  local c = L.crown
  if c then
    self.crown:ClearAllPoints()
    self.crown:SetPoint("TOP", self.frame, "TOPLEFT", c.cx, -c.top)
    self.crown:SetSize(c.size, c.size * CROWN_RATIO)
  end
  self:refresh()
end

-- The badge and crown follow the last role / leader set, and L.
function Role:refresh()
  local L = self.L
  if L and L.role and self.glyphFile then
    self.glyph:SetTexture(self.glyphFile)
    self.badge:Show()
  else
    self.badge:Hide()
  end
  if L and L.crown and self.leader then self.crown:Show() else self.crown:Hide() end
end

-- "TANK" | "HEALER" | "DAMAGER" shows that glyph; anything else (NONE, nil,
-- a secret value) hides the badge.
function Role:setRole(r)
  self.glyphFile = nil
  if not ns.Util.isSecret(r) and type(r) == "string" then
    self.glyphFile = ns.Theme.textures.role[r]
  end
  self:refresh()
end

-- Only a plain true shows the crown.
function Role:setLeader(b)
  self.leader = not ns.Util.isSecret(b) and b == true
  self:refresh()
end

function Role:setUnit(unit)
  self.unit = unit
  if not unit then
    self:setRole(nil)
    self:setLeader(false)
    return
  end
  -- UNVERIFIED (check in client): UnitGroupRolesAssigned / UnitIsGroupLeader
  -- exist on Forever; a missing one hides the badge / crown.
  -- The answers may be secret: passed on untested (setRole / setLeader read
  -- them only when plain).
  local roleOf, leaderOf = _G.UnitGroupRolesAssigned, _G.UnitIsGroupLeader
  if type(roleOf) == "function" then self:setRole(roleOf(unit)) else self:setRole(nil) end
  if type(leaderOf) == "function" then self:setLeader(leaderOf(unit)) else self:setLeader(false) end
end

ns.Units.Parts.Role = Role
