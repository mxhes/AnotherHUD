local ADDON, ns = ...

-- Pure geometry of a unit frame, from the approved mockups (layout "overhang").
-- All values are frame pixels from the TOPLEFT, y growing down.
local UnitLayout = {}

local function round(x) return math.floor(x + 0.5) end

-- Width of a skin's border: its line count; Round has a soft 4 px edge.
function UnitLayout.edgeWidth(border)
  if border == "round" then return 4 end
  return #ns.Theme.edgeRects(border)
end

-- o = { w, h, powerH, portraitScale (percent), mirror, edge, badge (px or nil), fontSize }
function UnitLayout.frame(o)
  local w, h, edge = o.w, o.h, o.edge
  local powerH = o.powerH or 0
  local ps = (o.portraitScale or 100) / 100
  local dia = round(h * 1.25 * ps)
  local cx = round(dia * 0.32)
  local L = {}

  local bottom = h - edge - 1
  local bars
  if o.mirror then
    bars = { left = edge + 1, right = w - cx - dia / 2 - 2 }
    L.ring = { dia = dia, cx = w - cx, cy = h / 2 }
    L.studCorners = { "TOPLEFT", "BOTTOMLEFT" }
  else
    bars = { left = cx + dia / 2 + 2, right = w - edge - 1 }
    L.ring = { dia = dia, cx = cx, cy = h / 2 }
    L.studCorners = { "TOPRIGHT", "BOTTOMRIGHT" }
  end
  L.bars = bars

  if powerH > 0 then
    L.power = { top = bottom - powerH, bottom = bottom }
    L.health = { top = edge + 1, bottom = L.power.top - 1 }
  else
    L.health = { top = edge + 1, bottom = bottom }
  end

  if o.badge then
    local dx = 0.33 * dia
    L.badge = { size = o.badge, cx = L.ring.cx + (o.mirror and -dx or dx), cy = L.ring.cy + 0.36 * dia }
  end

  if powerH >= 9 then L.powerText = { size = math.min(10, powerH - 3) } end
  L.ringStuds = dia >= 40
  L.below = round(math.max(8, h / 2 + dia / 2 - h + 6))
  return L
end

-- Icons per row and how many of `count` show.
function UnitLayout.auras(width, size, gap, rows, count)
  local perRow = math.max(1, math.floor((width + gap) / (size + gap)))
  return perRow, math.min(count, perRow * rows)
end

ns.UnitLayout = UnitLayout
