local ADDON, ns = ...

-- Pure rules for when a unit frame shows and how opaque it is.
local UnitState = {}

-- s = { editMode, inCombat, hover, outOfCombat (percent), mouseover }.
-- Fully opaque in Edit Mode, in combat, and under the mouse when the hover
-- option is on; otherwise the out-of-combat opacity.
function UnitState.alpha(s)
  if s.editMode or s.inCombat or (s.mouseover and s.hover) then return 1 end
  return (s.outOfCombat or 100) / 100
end

-- The state driver condition that shows / hides a unit frame.
function UnitState.visibility(unit, showInVehicle)
  local cond = "[petbattle] hide; "
  if showInVehicle == false then cond = cond .. "[vehicleui] hide; " end
  if unit == "player" then return cond .. "show" end
  return cond .. "[@" .. unit .. ",exists] show; hide"
end

ns.UnitState = UnitState
