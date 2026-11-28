local ADDON, ns = ...

-- A small round minimap button in the level badge look (approved mockup 7):
-- the skin's border lines as a stack of tinted discs, the panel fill inside
-- them and a gold icon in the middle; an optional gold glow behind it (the
-- calendar's pending invites). Plain frames and textures, nothing secure.
ns.Map = ns.Map or {}

local Badge = {}
Badge.__index = Badge

local function tint(tex, c, alpha)
  tex:SetVertexColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

function Badge.create(parent)
  local T = ns.Theme
  local Ring = ns.Units.Parts.Ring
  local button = CreateFrame("Button", nil, parent)
  local self = setmetatable({ button = button, lines = {} }, Badge)
  self.glow = button:CreateTexture(nil, "BACKGROUND")
  self.glow:SetTexture(T.textures.glow)
  -- UNVERIFIED (check in client): SetTextureSliceMargins on a texture.
  local s = T.sizes.unit.glowSlice
  pcall(self.glow.SetTextureSliceMargins, self.glow, s, s, s, s)
  self.glow:Hide()
  self.fill = Ring.disc(button, "ARTWORK", 0)
  self.icon = button:CreateTexture(nil, "OVERLAY")
  return self
end

-- size: the badge diameter; skin: a Theme.skins entry.
function Badge:layout(size, skin)
  local T = ns.Theme
  local Ring = ns.Units.Parts.Ring
  local button = self.button
  local c = size / 2
  button:SetSize(size, size)
  local shades = Ring.shadesOf((skin or T.skins.classic).border)
  local n = #shades
  for i = 1, n do
    self.lines[i] = self.lines[i] or Ring.disc(button, "BORDER", math.min(7, i - 1))
    Ring.place(self.lines[i], button, c, c, size - 2 * (i - 1))
    tint(self.lines[i], T.scaleColor(T.colors.panelBorder, shades[i]))
    self.lines[i]:Show()
  end
  for i = n + 1, #self.lines do self.lines[i]:Hide() end
  Ring.place(self.fill, button, c, c, size - 2 * n)
  tint(self.fill, T.colors.panelTint)
  local icon = size * T.sizes.minimap.badgeIcon
  self.icon:ClearAllPoints()
  self.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  self.icon:SetSize(icon, icon)
  tint(self.icon, T.colors.gold)
  local g = size + 2 * T.sizes.minimap.glow
  self.glow:ClearAllPoints()
  self.glow:SetPoint("CENTER", button, "CENTER", 0, 0)
  self.glow:SetSize(g, g)
  tint(self.glow, T.colors.gold)
end

function Badge:setIcon(file)
  self.icon:SetTexture(file)
end

function Badge:setGlow(on)
  if on then self.glow:Show() else self.glow:Hide() end
end

ns.Map.Badge = Badge
