local ADDON, ns = ...

-- Small helpers shared by every module. Loaded first; pure except `say`.
local Util = {}

local huge = math.huge

-- A real, finite number (saved variables and addon APIs can hand back anything).
function Util.isNumber(v)
  return type(v) == "number" and v == v and v ~= huge and v ~= -huge
end

-- A "secret" value: unit names, GUIDs and tooltip lines the client hides
-- from addons in restricted contexts. Comparing, concatenating or matching
-- one raises an error, so such values are dropped unread. issecretvalue is
-- looked up at call time; without it nothing is secret.
function Util.isSecret(v)
  local f = _G.issecretvalue
  if type(f) ~= "function" then return false end
  local ok, secret = pcall(f, v)
  return not ok or secret == true
end

-- `v` when it is a readable, non-empty string, else nil.
function Util.plainString(v)
  if type(v) ~= "string" or Util.isSecret(v) or v == "" then return nil end
  return v
end

-- A deep copy of `v` (tables copied all the way down; other values as they are).
function Util.copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = Util.copy(x) end
  return out
end

-- Fills the keys of `dst` that are missing with copies of `defaults`, deeply.
-- Never overwrites a value `dst` already has. Returns `dst`.
function Util.merge(dst, defaults)
  for k, v in pairs(defaults) do
    if dst[k] == nil then
      dst[k] = Util.copy(v)
    elseif type(dst[k]) == "table" and type(v) == "table" then
      Util.merge(dst[k], v)
    end
  end
  return dst
end

function Util.clamp(v, lo, hi)
  if hi < lo then hi = lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local PREFIX = "|cff33ff99AnotherHUD|r: "

-- Chat line with the addon prefix.
function Util.say(msg)
  print(PREFIX .. msg)
end

ns.Util = Util
