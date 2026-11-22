local ADDON, ns = ...

-- Pure rules for the party and boss frames: member order, block offsets and
-- the visibility conditions of the holders. Role and exists can be secret and
-- are only read when plain.
local GroupLayout = {}
local Util = ns.Util

-- The roles that have a badge texture.
GroupLayout.ROLES = { "TANK", "HEALER", "DAMAGER" }

local RANK = { TANK = 1, HEALER = 2, DAMAGER = 3 }

local function rank(role)
  if role == nil or Util.isSecret(role) then return 4 end
  return RANK[role] or 4
end

-- A missing flag or a secret one counts as existing only when not plain false.
local function exists(v)
  if v == nil then return false end
  if Util.isSecret(v) then return true end
  return v and true or false
end

-- slots = array of { index, unit, role, exists }; o = { sortByRole, showPlayer }.
-- Returns the slot indexes in display order.
function GroupLayout.order(slots, o)
  local list = {}
  for _, s in ipairs(slots) do
    if not (s.unit == "player" and not o.showPlayer) then
      list[#list + 1] = { index = s.index, here = exists(s.exists) and 0 or 1,
        rank = o.sortByRole and rank(s.role) or 0 }
    end
  end
  table.sort(list, function(a, b)
    if a.here ~= b.here then return a.here < b.here end
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.index < b.index
  end)
  local out = {}
  for i, s in ipairs(list) do out[i] = s.index end
  return out
end

-- o = { orientation = "Vertical" | "Horizontal", growth, w, h, gap } (w, h =
-- one member's block). Returns list[i] = { point, x, y } relative to the
-- holder, and the holder's width and height.
function GroupLayout.offsets(count, o)
  local w, h, gap = o.w, o.h, o.gap
  local list = {}
  local vertical = o.orientation ~= "Horizontal"
  local reverse = o.growth == "Up" or o.growth == "Up / Left"
  for i = 1, count do
    local step = i - 1
    if vertical then
      if reverse then list[i] = { point = "BOTTOMLEFT", x = 0, y = step * (h + gap) }
      else list[i] = { point = "TOPLEFT", x = 0, y = -step * (h + gap) } end
    else
      if reverse then list[i] = { point = "TOPRIGHT", x = -step * (w + gap), y = 0 }
      else list[i] = { point = "TOPLEFT", x = step * (w + gap), y = 0 } end
    end
  end
  if count == 0 then return list, w, h end
  if vertical then return list, w, count * h + (count - 1) * gap end
  return list, count * w + (count - 1) * gap, h
end

function GroupLayout.partyVisibility()
  return "[petbattle] hide; [group:raid] hide; [@raid1,exists] hide; [@party1,exists] show; hide"
end

function GroupLayout.bossVisibility()
  return "[petbattle] hide; show"
end

ns.GroupLayout = GroupLayout
