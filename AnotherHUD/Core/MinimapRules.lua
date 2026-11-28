local ADDON, ns = ...

-- Pure rules of the minimap: the mask texture and the GetMinimapShape answer
-- of a Shape setting, and the mouse wheel zoom step. No client calls.
local MinimapRules = {}
local Util = ns.Util

-- UNVERIFIED (check in client): Minimap:SetMaskTexture takes these paths and
-- gives a square / round map.
local MASKS = { Square = "Interface\\Buttons\\WHITE8x8" }
local ROUND_MASK = "Textures\\MinimapMask"

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

ns.MinimapRules = MinimapRules
