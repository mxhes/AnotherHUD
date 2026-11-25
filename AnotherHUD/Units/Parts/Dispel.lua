local ADDON, ns = ...

-- The dispellable-debuff glow around a group frame: a 9-slice glow texture
-- reaching Theme.sizes.unit.glow px outside the frame on every side. The live
-- glow is a client AuraContainer with one slot ("HARMFUL|RAID": debuffs I can
-- dispel) whose button covers the frame and carries our glow texture; the
-- client tints it by the debuff type (AddDispelTypeTexture). Edit Mode shows
-- our own tinted texture instead. Without the template / slot API nothing
-- shows and nothing errors (`available` false). Plain frames, nothing secure.
ns.Units = ns.Units or {}
ns.Units.Parts = ns.Units.Parts or {}

local Dispel = {}
Dispel.__index = Dispel

local SLOT = "dispel"
local FILTER = "HARMFUL|RAID"

-- Sets the glow texture up on `holder`: outset on every side, sliced.
local function glowTexture(holder)
  local U = ns.Theme.sizes.unit
  local tex = holder:CreateTexture(nil, "OVERLAY")
  tex:SetTexture(ns.Theme.textures.glow)
  tex:ClearAllPoints()
  tex:SetPoint("TOPLEFT", holder, "TOPLEFT", -U.glow, U.glow)
  tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", U.glow, -U.glow)
  -- UNVERIFIED (check in client): SetTextureSliceMargins on a texture.
  pcall(tex.SetTextureSliceMargins, tex, U.glowSlice, U.glowSlice, U.glowSlice, U.glowSlice)
  return tex
end

local function fit(self, button)
  local w, h = self.parent:GetWidth(), self.parent:GetHeight()
  if type(w) == "number" and type(h) == "number" then button:SetSize(w, h) end
end

local function initButton(self, button)
  local entry = self.buttons[button]
  if not entry then
    entry = { tex = glowTexture(button) }
    self.buttons[button] = entry
    button:EnableMouse(false)
    local E = _G.Enum
    local style = E and E.CustomAuraButtonDispelTypeTextureStyle
    if style then
      -- UNVERIFIED (check in client): AddDispelTypeTexture with PreserveAsset
      -- tints our white glow texture by the debuff type.
      pcall(button.AddDispelTypeTexture, button, entry.tex,
        { style = style.PreserveAsset, showWhenHarmful = true, showWhenHelpful = false })
    end
  end
  fit(self, button)
end

function Dispel.create(parent, unit)
  local Auras = ns.Units.Parts.Auras
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)
  frame:SetFrameLevel((parent:GetFrameLevel() or 0) + 7)
  local self = setmetatable({ frame = frame, parent = parent, unit = unit,
    buttons = setmetatable({}, { __mode = "k" }) }, Dispel)
  self.sampleTex = glowTexture(frame)
  self.sampleTex:Hide()
  Auras.loadAuraContainer()
  -- UNVERIFIED (check in client): AuraContainer:AddAuraSlot(key, filter,
  -- { initializeFrame }) and the "HARMFUL|RAID" filter.
  local c = Auras.makeContainer(frame, unit, "AddAuraSlot")
  if c and pcall(c.AddAuraSlot, c, SLOT, FILTER, {
    initializeFrame = function(button) initButton(self, button) end,
  }) then
    self.container = c
    pcall(c.SetAllPoints, c, frame)
  end
  self.available = self.container ~= nil
  return self
end

-- The glow follows the frame; call after the frame's size changed.
function Dispel:layout()
  if self.container then
    pcall(self.container.SetAllPoints, self.container, self.frame)
  end
  for button in pairs(self.buttons) do fit(self, button) end
end

-- Edit Mode: our own texture tinted with `color`; nil hides it (the live
-- glow comes back).
function Dispel:sample(color)
  if color then
    self.sampleTex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    self.sampleTex:Show()
    if self.container then self.container:Hide() end
  else
    self.sampleTex:Hide()
    if self.container then self.container:Show() end
  end
end

ns.Units.Parts.Dispel = Dispel
