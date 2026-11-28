local ADDON, ns = ...

-- Pure rules of the minimap: the mask texture and the GetMinimapShape answer
-- of a Shape setting, and the mouse wheel zoom step. No client calls.
local MinimapRules = {}
local Util = ns.Util

-- Square: a plain white texture (square confirmed in the client 2026-11-28).
-- Round: Blizzard's own round mask atlas, the one Forever's minimap sets
-- itself (Textures\MinimapMask gave a broken map on Forever, 2026-11-28).
-- UNVERIFIED (check in client): the atlas gives a round map.
local MASKS = { Square = "Interface\\Buttons\\WHITE8x8" }
local ROUND_MASK = "ui-hud-minimap-frame-generic-mask"

function MinimapRules.mask(shape)
  return MASKS[shape] or ROUND_MASK
end

-- What GetMinimapShape() answers for a Shape setting.
function MinimapRules.shapeName(shape)
  return shape == "Square" and "SQUARE" or "ROUND"
end

local function plain(v)
  return not Util.isSecret(v) and Util.isNumber(v)
end

-- The zoom after a wheel turn (delta > 0 zooms in, < 0 out), or nil when it
-- would leave 0 .. levels - 1 or an input is not a plain number.
function MinimapRules.zoom(current, delta, levels)
  if not plain(current) or not plain(delta) or not plain(levels) or delta == 0 then return nil end
  local z = current + (delta > 0 and 1 or -1)
  if z < 0 or z > levels - 1 then return nil end
  return z
end

-- "14:05" / "09:05" (military) or "2:05 PM"; "" without plain numbers.
function MinimapRules.clockText(hour, minute, military)
  if not plain(hour) or not plain(minute) then return "" end
  if military then return string.format("%02d:%02d", hour, minute) end
  local suffix = hour < 12 and ns.L["AM"] or ns.L["PM"]
  local h = hour % 12
  if h == 0 then h = 12 end
  return string.format("%d:%02d %s", h, minute, suffix)
end

-- x, y in 0..1 -> "42.1, 65.8"; "" when either is not a plain number or both
-- are 0 (the client's "no position").
function MinimapRules.coordText(x, y)
  if not plain(x) or not plain(y) or (x == 0 and y == 0) then return "" end
  return string.format("%.1f, %.1f", x * 100, y * 100)
end

-- The zone name color of a PvP type (a copy), the normal gold for others.
function MinimapRules.zoneColor(pvpType)
  local colors = ns.Theme.minimapZoneColors
  local c = (type(pvpType) == "string" and colors[pvpType]) or colors.normal
  return { c[1], c[2], c[3] }
end

ns.MinimapRules = MinimapRules
