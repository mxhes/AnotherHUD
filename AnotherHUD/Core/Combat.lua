local ADDON, ns = ...

-- Combat lockdown queue: secure frames must not change in combat. `after`
-- runs a function now, or (in combat) stores it under a key and runs it when
-- combat ends. A later call with the same key replaces the earlier function
-- but keeps its place in the order.
local Combat = {}

local keys, fns = {}, {}
local frame

local function inCombat()
  return InCombatLockdown ~= nil and InCombatLockdown() and true or false
end

local function report(err)
  if geterrorhandler then geterrorhandler()(err) end
end

local function flush()
  if inCombat() then return end
  local k, f = keys, fns
  keys, fns = {}, {}
  for _, key in ipairs(k) do
    local ok, err = pcall(f[key])
    if not ok then report(err) end
  end
end

local function ensureFrame()
  if frame then return end
  frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:SetScript("OnEvent", flush)
end

function Combat.after(key, fn)
  if not inCombat() then
    fn()
    return
  end
  ensureFrame()
  if fns[key] == nil then keys[#keys + 1] = key end
  fns[key] = fn
end

function Combat.pending()
  return #keys
end

ns.Combat = Combat
