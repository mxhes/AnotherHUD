local ADDON, ns = ...

-- Pure rules of the class resource bar: which resource a class and spec has,
-- the segment count, the rune order, the essence segment and the layout under
-- the Player frame. Every client number is only read when plain.
local Resource = {}
local Util = ns.Util
local Theme = ns.Theme

local function plain(v)
  return not Util.isSecret(v) and Util.isNumber(v)
end

local function clamp01(v)
  return math.min(1, math.max(0, v))
end

-- power = Enum.PowerType field name, color = Theme.resourceColors key,
-- fallback = the segment count used while the maximum is unreadable.
local function def(key, power, fallback, color, mode, form)
  return { key = key, power = power, fallback = fallback, color = color, mode = mode, form = form }
end

-- The resource of a class (and spec, 1-based) or nil. Returns a fresh table.
function Resource.forPlayer(class, spec)
  if class == "ROGUE" then return def("combo", "ComboPoints", 5, "combo", "points") end
  if class == "DRUID" then return def("combo", "ComboPoints", 5, "combo", "points", "Energy") end
  if class == "PALADIN" then return def("holy", "HolyPower", 5, "holy", "points") end
  if class == "DEATHKNIGHT" then return def("runes", "Runes", 6, Resource.runeColor(spec), "runes") end
  if class == "WARLOCK" then return def("shards", "SoulShards", 5, "shards", "fragments") end
  if class == "MONK" and spec == 3 then return def("chi", "Chi", 5, "chi", "points") end
  if class == "MAGE" and spec == 1 then return def("arcane", "ArcaneCharges", 4, "arcane", "points") end
  if class == "EVOKER" then return def("essence", "Essence", 5, "essence", "essence") end
  return nil
end

-- Whether the resource shows now: a form-bound one (Druid combo points) only
-- while the player's power token is that form's.
function Resource.active(d, powerToken)
  if not d then return false end
  if d.form then return powerToken == d.form end
  return true
end

-- The rune color key of a death knight spec (1 Blood, 2 Frost, 3 Unholy).
function Resource.runeColor(spec)
  if spec == 2 then return "runesFrost" end
  if spec == 3 then return "runesUnholy" end
  return "runes"
end

-- The segment count: the maximum when readable (at most maxSegments), else
-- the class fallback.
function Resource.count(max, fallback)
  if plain(max) and max >= 1 then
    return math.min(math.floor(max), Theme.sizes.resource.maxSegments)
  end
  return fallback
end

-- list[i] = { start, duration, ready } (plain numbers / booleans or nil; the
-- caller drops secrets). Returns { { fill, left } ... }: ready runes first,
-- then recharging ones by time left, unreadable ones last.
function Resource.runes(list, now)
  local items = {}
  for i, r in ipairs(list) do
    local start, duration, ready = r.start or r[1], r.duration or r[2], r.ready
    if ready == nil then ready = r[3] end
    local item = { index = i, fill = 0, group = 3 }
    if ready == true then
      item.fill, item.group = 1, 1
    elseif plain(start) and plain(duration) and plain(now) and duration > 0 then
      item.fill = clamp01((now - start) / duration)
      item.left = start + duration - now
      item.group = 2
    end
    items[#items + 1] = item
  end
  table.sort(items, function(a, b)
    if a.group ~= b.group then return a.group < b.group end
    if a.group == 2 and a.left ~= b.left then return a.left < b.left end
    return a.index < b.index
  end)
  local out = {}
  for i, it in ipairs(items) do out[i] = { fill = it.fill, left = it.left } end
  return out
end

-- The regenerating essence: partial is UnitPartialPower (0..1000), rate the
-- regeneration per second. nil when not all plain or the bar is full.
function Resource.essence(count, max, partial, rate)
  if not (plain(count) and plain(max) and plain(partial) and plain(rate)) then return nil end
  if count >= max then return nil end
  local fill = clamp01(partial / 1000)
  local left
  if rate > 0 then left = (1 - fill) / rate end
  return { index = count + 1, fill = fill, left = left }
end

-- Whole seconds left, rounded up; "" for anything that is not a positive number.
function Resource.timerText(left)
  if not plain(left) or left <= 0 then return "" end
  return string.format("%d", math.ceil(left))
end

-- The attached bar's box under the Player frame (a UnitLayout.frame result):
-- x from the frame's left, as wide as the health / power column.
function Resource.attached(L)
  local x = math.floor(L.bars.left + 0.5)
  return { x = x, w = L.w - x, h = Theme.sizes.resource.attachedHeight }
end

-- The gap the Player frame keeps below itself for an attached bar of height h.
function Resource.reserve(h)
  local gap = Theme.sizes.resource.gap
  return gap + h + gap
end

ns.Resource = Resource
