local ADDON, ns = ...

-- The unit frame panel: the leather fill and the skin's border. Round is the
-- backdrop's tooltip edge; Bevel / Thin are 1 px line rectangles
-- (Theme.edgeRects). Adapted from AnotherLedger UI/Widgets.lua (skinEdges /
-- paintEdges). Plain frames and textures, nothing secure.
ns.Units = ns.Units or {}
ns.Units.Parts = ns.Units.Parts or {}

local Panel = {}
Panel.__index = Panel

local function tint(tex, c, alpha)
  tex:SetVertexColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

-- Four line textures of one edge rectangle, placed `inset` px inside.
local function placeRect(frame, r, inset)
  local o = inset
  for _, t in ipairs(r) do t:ClearAllPoints() end
  local top, bottom, left, right = r[1], r[2], r[3], r[4]
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", o, -o); top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -o, -o)
  top:SetHeight(1)
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", o, o); bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -o, o)
  bottom:SetHeight(1)
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", o, -o); left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", o, o)
  left:SetWidth(1)
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -o, -o); right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -o, o)
  right:SetWidth(1)
end

function Panel.create(parent)
  -- UNVERIFIED (check in client): BackdropTemplate on a plain child frame of
  -- a secure unit button.
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  frame:SetAllPoints(parent)
  local self = setmetatable({ frame = frame, parent = parent, rects = {}, edges = {} }, Panel)
  return self
end

-- opts = { skin } (a Theme.skins entry; Classic when missing).
function Panel:layout(opts)
  local T = ns.Theme
  local border = ((opts and opts.skin) or T.skins.classic).border
  local frame = self.frame
  frame:SetBackdrop(T.backdropSpec(border))
  local bg, edge = T.colors.panelTint, T.colors.panelBorder
  frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)

  local specs = T.edgeRects(border)
  for i, spec in ipairs(specs) do
    local r = self.rects[i]
    if not r then
      r = {}
      for k = 1, 4 do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetTexture(T.textures.line)
        r[k] = t
        self.edges[#self.edges + 1] = t
      end
      self.rects[i] = r
    end
    placeRect(frame, r, spec.inset)
    local c = T.scaleColor(edge, spec.shade)
    for _, t in ipairs(r) do
      tint(t, c)
      t:Show()
    end
  end
  for i = #specs + 1, #self.rects do
    for _, t in ipairs(self.rects[i]) do t:Hide() end
  end
end

ns.Units.Parts.Panel = Panel
