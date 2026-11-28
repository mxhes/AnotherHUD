local ADDON, ns = ...

-- Pure rules of the XP / Reputation bar: what shows, the rested end, the
-- texts and the reputation colors. Every client number is only read when
-- plain; a secret one only travels on to the bar's SetValue.
local Tracking = {}
local Util = ns.Util
local Theme = ns.Theme
local L = ns.L

local NEUTRAL = 4
local STANDINGS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

local function plain(v)
  return not Util.isSecret(v) and Util.isNumber(v)
end

-- 12345 -> "12,345". Plain integers only. Uses the client's BreakUpLargeNumbers
-- when it exists (UNVERIFIED (check in client): its separator follows the
-- client language), else its own comma grouping.
function Tracking.number(n)
  local f = _G.BreakUpLargeNumbers
  if type(f) == "function" then
    local ok, s = pcall(f, n)
    if ok and type(s) == "string" then return s end
  end
  local s = string.format("%d", math.floor(n))
  local sign, digits = s:match("^(-?)(%d+)$")
  digits = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  if digits:sub(1, 1) == "," then digits = digits:sub(2) end
  return sign .. digits
end

-- The standing name of a reaction (1 Hated .. 8 Exalted), "" for anything else.
function Tracking.standing(reaction)
  local key = STANDINGS[reaction]
  if not key then return "" end
  return L[key]
end

-- "Level 42  12,345 / 50,000 (24%)" plus "  +3,000 rested" when rested > 0.
-- Plain numbers only; with max <= 0 there is no percent part.
function Tracking.xpText(level, xp, max, rested)
  local text = string.format("%s %d  %s / %s", L["Level"], level or 0, Tracking.number(xp), Tracking.number(max))
  if max > 0 then
    text = text .. string.format(" (%d%%)", math.floor(xp * 100 / max))
  end
  if plain(rested) and rested > 0 then
    text = text .. "  +" .. Tracking.number(rested) .. " " .. L["rested"]
  end
  return text
end

-- s = { xp, max, rested, level, atMax, disabled } -> nil | { value, max, restedEnd, text }
function Tracking.xp(s)
  if not s or s.atMax or s.disabled then return nil end
  -- nil only (== nil is safe for a secret value): no row without numbers.
  if s.xp == nil or s.max == nil then return nil end
  local r = { value = s.xp, max = s.max }
  if plain(s.xp) and plain(s.max) and s.max > 0 then
    if plain(s.rested) and s.rested > 0 then
      r.restedEnd = math.min(s.xp + s.rested, s.max)
    end
    r.text = Tracking.xpText(plain(s.level) and s.level or 0, s.xp, s.max, s.rested)
  end
  return r
end

-- "Honor level 12  1,240 / 4,000 (31%)". Plain numbers only; with max <= 0
-- there is no percent part.
function Tracking.honorText(level, value, max)
  local text = string.format("%s %d  %s / %s", L["Honor level"], level or 0, Tracking.number(value),
    Tracking.number(max))
  if max > 0 then
    text = text .. string.format(" (%d%%)", math.floor(value * 100 / max))
  end
  return text
end

-- s = { value, max, level } -> nil | { value, max, text }. A secret value or
-- max goes to the bar unread (no text).
function Tracking.honor(s)
  if not s or s.value == nil or s.max == nil then return nil end
  local r = { value = s.value, max = s.max }
  if plain(s.value) and plain(s.max) and s.max > 0 then
    r.text = Tracking.honorText(plain(s.level) and s.level or 0, s.value, s.max)
  end
  return r
end

-- Which row (1..count) a point `offset` px down from the frame's top edge is
-- on: rows start at `edge`, each `height` tall with `gap` between; nil on the
-- edge, in a gap or past the last row.
function Tracking.rowAt(offset, height, gap, edge, count)
  local y = offset - edge
  if y < 0 then return nil end
  local i = math.floor(y / (height + gap))
  if i >= count or y - i * (height + gap) >= height then return nil end
  return i + 1
end

-- d = C_Reputation.GetWatchedFactionData() or { legacy = { name, reaction, min,
-- max, value } } from GetWatchedFactionInfo() -> nil | { name, min, max, value,
-- reaction, text }.
function Tracking.reputation(d)
  if type(d) ~= "table" then return nil end
  local name, reaction, min, max, value
  if type(d.legacy) == "table" then
    local g = d.legacy
    name, reaction, min, max, value = g.name, g.reaction, g.min, g.max, g.value
  else
    name, reaction, min, max, value = d.name, d.reaction, d.currentReactionThreshold,
      d.nextReactionThreshold, d.currentStanding
  end
  name = Util.plainString(name)
  if not name then return nil end
  if min == nil or max == nil or value == nil then return nil end
  local r = { name = name, min = min, max = max, value = value, reaction = reaction }
  if plain(min) and plain(max) and plain(value) then
    local standing = Tracking.standing(plain(reaction) and reaction or nil)
    -- An empty standing (secret reaction) is left out: no doubled space.
    local head = standing ~= "" and (name .. "  " .. standing) or name
    if max > min then
      r.text = string.format("%s  %s / %s", head, Tracking.number(value - min), Tracking.number(max - min))
    else
      r.min, r.max, r.value = 0, 1, 1
      r.text = head
    end
  end
  return r
end

-- The bar color {r, g, b} of a reaction: the client's FACTION_BAR_COLORS when
-- it has it (UNVERIFIED (check in client)), else the Theme copy, else neutral.
function Tracking.reactionColor(reaction)
  local colors = _G.FACTION_BAR_COLORS
  local c = type(colors) == "table" and plain(reaction) and colors[reaction] or nil
  if type(c) == "table" and plain(c.r) and plain(c.g) and plain(c.b) then
    return { c.r, c.g, c.b }
  end
  local t = Theme.trackingColors.reaction
  local f = (plain(reaction) and t[reaction]) or t[NEUTRAL]
  -- A copy: callers must not be able to change the Theme.
  return { f[1], f[2], f[3] }
end

ns.Tracking = Tracking
