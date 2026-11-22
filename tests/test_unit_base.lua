local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  local ns = h.load({ "Core/Util.lua", "Core/Locale.lua", "Locales/deDE.lua", "Core/Theme.lua",
    "Core/DB.lua", "Core/Modules.lua", "Core/Combat.lua", "Core/Options.lua",
    "Core/UnitText.lua", "Core/UnitColor.lua", "Core/UnitState.lua", "Core/UnitLayout.lua",
    "Units/Settings.lua", "Units/Parts/Panel.lua", "Units/Parts/Ring.lua", "Units/Parts/Bars.lua",
    "Units/Parts/CastBar.lua", "Units/Parts/Auras.lua", "Units/Base.lua" })
  ns.db, ns.chardb = ns.DB.init(nil, nil)
  return ns
end

-- A target-like module spec with every section.
local function define(ns, id, saved)
  local settings, defaults = ns.Units.Settings.build(
    { "Size", "Text", "Look", "Behaviour", "Cast Bar", "Auras", "Fading", portrait = true, power = true })
  local spec = ns.Modules.define({ id = id or "target", label = "Target", kind = "unit",
    defaults = defaults, settings = settings })
  if saved then ns.DB.profile().modules[spec.id] = saved end
  return spec
end

-- Runs fn(ns, client, units) with a fake client and unit API; restores units
-- first, then the client.
local function withUnits(opts, map, fn)
  local client = fakes.client(opts)
  local units = fakes.units(map)
  local ok, err = pcall(fn, load(), client, units)
  units.restore()
  client.restore()
  if not ok then error(err, 0) end
end

local function make(ns, spec, unit)
  local frame = ns.Units.Base.create(spec, { unit = unit or "target", name = "AHTestFrame",
    castBar = true, auras = true, badge = 18 })
  ns.Units.Base.apply(spec)
  return frame
end

local function count(frame, name)
  local n = 0
  for _, c in ipairs(frame.calls) do if c[1] == name then n = n + 1 end end
  return n
end

h.test("secure button with clicks", function()
  withUnits({}, {}, function(ns)
    local spec = define(ns)
    local frame = make(ns, spec)
    h.eq(spec.frame, frame, "spec.frame set")
    h.eq(frame:GetAttribute("unit"), "target")
    h.eq(frame:GetAttribute("*type1"), "target")
    h.eq(frame:GetAttribute("*type2"), "togglemenu")
    h.eq(frame._events.UNIT_HEALTH, true, "unit events")
    h.eq(frame._events.PLAYER_TARGET_CHANGED, true, "change event")
    h.eq(frame._events.UNIT_SPELLCAST_START, true, "cast events")
    h.eq(frame._events.PLAYER_REGEN_DISABLED, true, "fading events")
  end)
end)

h.test("update passes secrets to the parts", function()
  local hp, hpMax, pct = fakes.secret(1), fakes.secret(2), fakes.secret(3)
  local pw, pwMax, ppct, name = fakes.secret(4), fakes.secret(5), fakes.secret(6), fakes.secret(7)
  withUnits({}, { target = { exists = true, name = name, health = hp, healthMax = hpMax, healthPct = pct,
    power = pw, powerMax = pwMax, powerPct = ppct, powerToken = fakes.secret(8),
    level = fakes.secret(9), classification = fakes.secret(10), reaction = fakes.secret(11),
    dead = fakes.secret(12), connected = fakes.secret(13), isPlayer = fakes.secret(14) } },
    function(ns)
      local frame = make(ns, define(ns))
      ns.Units.Base.update(frame)
      h.eq(rawequal(frame.bars.health._value, hp), true, "health value is the secret")
      h.eq(rawequal(frame.bars.power._value, pw), true, "power value is the secret")
      h.eq(rawequal(frame.bars.name:GetText(), name), true, "name passed on")
      h.eq(frame.bars.healthText._fmt, "%s / %s", "Value text")
      h.eq(rawequal(frame.bars.healthText._args[1], hp), true)
      h.eq(rawequal(frame.bars.powerText._args[1], ppct), true, "power percent passed on")
      h.eq(frame.ring.level._fmt, "%d", "secret level formatted by the client")
    end)
end)

h.test("health events update values only, a target change everything", function()
  withUnits({}, { target = { exists = true, name = "Boar", health = 50, healthMax = 100 } },
    function(ns, client, units)
      make(ns, define(ns))
      local before, hp = units.calls.UnitClassification, units.calls.UnitHealth
      client.fire("UNIT_HEALTH", "target")
      h.eq(units.calls.UnitHealth, hp + 1, "health read")
      h.eq(units.calls.UnitClassification, before, "ring not read")
      client.fire("PLAYER_TARGET_CHANGED")
      h.eq(units.calls.UnitClassification, before + 1, "full update")
    end)
end)

h.test("unit gone: update hides texts and does not throw", function()
  withUnits({}, { target = { exists = true, name = "Boar", health = 50, healthMax = 100, healthPct = 50 } },
    function(ns, _, units)
      local frame = make(ns, define(ns))
      ns.Units.Base.update(frame)
      h.eq(frame.bars.name:GetText(), "Boar")
      local before = units.calls.UnitHealth
      units.set("target", "exists", false)
      ns.Units.Base.update(frame)
      h.eq(frame.bars.name:GetText(), "", "name cleared")
      h.eq(frame.bars.healthText:GetText(), "", "health text cleared")
      h.eq(units.calls.UnitHealth, before, "UnitHealth not read")
    end)
end)

h.test("created in combat: secure work waits for PLAYER_REGEN_ENABLED", function()
  withUnits({ inCombat = true }, {}, function(ns, client)
    local frame = make(ns, define(ns))
    h.eq(count(frame, "SetPoint"), 0, "no frame SetPoint")
    h.eq(count(frame.cast.frame, "SetPoint"), 0, "no cast SetPoint")
    h.eq(frame:GetAttribute("unit"), nil, "no attributes")
    h.eq(client.drivers[frame], nil, "no driver")
    client.setCombat(false)
    client.fire("PLAYER_REGEN_ENABLED")
    h.eq(frame:GetAttribute("unit"), "target")
    h.eq(frame:GetAttribute("*type2"), "togglemenu")
    h.eq(client.drivers[frame].cond, ns.UnitState.visibility("target", true))
    h.eq(count(frame.cast.frame, "SetPoint") > 0, true, "cast anchored")
    h.eq(frame._width, 200, "sized")
  end)
end)

h.test("edit mode shows samples and restores visibility", function()
  withUnits({}, {}, function(ns, client)
    local spec = define(ns)
    local frame = make(ns, spec)
    h.eq(client.drivers[frame].attr, "visibility")
    frame:Hide()
    ns.Units.Base.editMode(spec, true)
    h.eq(frame:IsShown(), true, "shown")
    h.eq(client.drivers[frame], nil, "driver gone")
    h.eq(frame.bars.health._value, 0.72)
    h.eq(frame.bars.power._value, 0.55)
    h.eq(frame.bars.name:GetText(), ns.L["Target"])
    h.eq(frame.cast.sampling, true, "cast sample")
    h.eq(frame.auras.sampling, true, "aura sample")
    h.eq(frame:GetAlpha(), 1)
    ns.Units.Base.editMode(spec, false)
    h.eq(client.drivers[frame].cond, ns.UnitState.visibility("target", true), "driver back")
    h.eq(frame.cast.sampling, false)
    h.eq(frame.auras.sampling, false)
    h.eq(frame.bars.name:GetText(), "", "update ran (no target)")
  end)
end)

h.test("fading follows combat and hover", function()
  withUnits({}, {}, function(ns, client)
    local frame = make(ns, define(ns, "target", { outOfCombat = 40, mouseover = true }))
    h.near(frame:GetAlpha(), 0.4)
    client.fire("PLAYER_REGEN_DISABLED")
    h.eq(frame:GetAlpha(), 1, "in combat")
    client.fire("PLAYER_REGEN_ENABLED")
    h.near(frame:GetAlpha(), 0.4)
    frame._scripts.OnEnter(frame)
    h.eq(frame:GetAlpha(), 1, "hover")
    frame._scripts.OnLeave(frame)
    h.near(frame:GetAlpha(), 0.4)
    ns.DB.profile().modules.target.mouseover = false
    frame._scripts.OnEnter(frame)
    h.near(frame:GetAlpha(), 0.4) -- hover option off
  end)
end)

h.test("hideBlizzard reparents once, and re-hides on Show", function()
  withUnits({}, {}, function(ns, client)
    local blizz = fakes.frame("PlayerFrame")
    blizz._events.UNIT_HEALTH = true
    blizz.IsProtected = function() return true end
    fakes.withGlobals({ PlayerFrame = blizz }, function()
      ns.Units.Base.hideBlizzard({ "PlayerFrame" })
      ns.Units.Base.hideBlizzard({ "PlayerFrame", "NoSuchFrame" })
      h.eq(count(blizz, "SetParent"), 1, "reparented once")
      h.eq(blizz:GetParent():IsShown(), false, "hidden parent")
      h.eq(blizz._events.UNIT_HEALTH, nil, "events off")
      blizz:Show()
      h.eq(blizz:IsShown(), false, "hidden again")
      client.setCombat(true)
      blizz:Show()
      h.eq(blizz:IsShown(), true, "waits in combat")
      client.setCombat(false)
      client.fire("PLAYER_REGEN_ENABLED")
      h.eq(blizz:IsShown(), false, "hidden after combat")
    end)
  end)
end)

h.test("targettarget refreshes on a throttle", function()
  withUnits({}, { targettarget = { exists = true, name = "Tank" } }, function(ns, _, units)
    local spec = define(ns, "tot")
    local frame = ns.Units.Base.create(spec, { unit = "targettarget", name = "AHTestToT" })
    ns.Units.Base.apply(spec)
    h.eq(frame._events.UNIT_HEALTH, nil, "no unit events")
    h.eq(frame._events.UNIT_TARGET, true)
    local before = units.calls.UnitName or 0
    frame._scripts.OnUpdate(frame, 0.1)
    h.eq(units.calls.UnitName or 0, before, "not yet")
    frame._scripts.OnUpdate(frame, 0.15)
    h.eq(units.calls.UnitName, before + 1, "refreshed")
    h.eq(frame.bars.name:GetText(), "Tank")
  end)
end)

h.test("hideBlizzard: protected frames wait, child bars off, SetParent re-parked", function()
  withUnits({}, {}, function(ns, client)
    local blizz = fakes.frame("TargetFrame")
    blizz.IsProtected = function() return true end
    blizz.healthbar = fakes.frame()
    blizz.healthbar._events.UNIT_HEALTH = true
    blizz.spellbar = fakes.frame()
    blizz.spellbar._events.UNIT_SPELLCAST_START = true
    fakes.withGlobals({ TargetFrame = blizz }, function()
      ns.Units.Base.hideBlizzard({ "TargetFrame" })
      h.eq(blizz.healthbar._events.UNIT_HEALTH, nil, "healthbar events off")
      h.eq(blizz.spellbar._events.UNIT_SPELLCAST_START, nil, "spellbar events off")
      local hiddenParent = blizz:GetParent()
      blizz:Show()
      h.eq(blizz:IsShown(), false, "hidden out of combat")
      blizz:SetParent(UIParent)
      h.eq(blizz:GetParent(), hiddenParent, "re-parked")
      client.setCombat(true)
      blizz:Show()
      blizz:SetParent(UIParent)
      h.eq(blizz:IsShown(), true, "protected: waits in combat")
      h.eq(blizz:GetParent(), UIParent, "re-park waits in combat")
      client.setCombat(false)
      client.fire("PLAYER_REGEN_ENABLED")
      h.eq(blizz:IsShown(), false)
      h.eq(blizz:GetParent(), hiddenParent)
    end)
  end)
end)

h.test("hideBlizzard: a missing frame is retried later", function()
  withUnits({}, {}, function(ns)
    ns.Units.Base.hideBlizzard({ "LateFrame" })
    local late = fakes.frame("LateFrame")
    fakes.withGlobals({ LateFrame = late }, function()
      ns.Units.Base.hideBlizzard({ "LateFrame" })
      h.eq(late:GetParent() ~= nil, true, "hidden on the second call")
    end)
  end)
end)

h.test("tooltip hides only when we own it", function()
  withUnits({}, {}, function(ns)
    local frame = make(ns, define(ns))
    local owner
    GameTooltip.IsOwned = function(_, f) return f == owner end
    frame._scripts.OnLeave(frame)
    h.eq(GameTooltip:IsShown(), true, "someone else's tooltip stays")
    owner = frame
    frame._scripts.OnLeave(frame)
    h.eq(GameTooltip:IsShown(), false, "ours hides")
  end)
end)

h.test("leaving Edit Mode refreshes a running cast", function()
  withUnits({}, {}, function(ns, _, units)
    local spec = define(ns)
    local frame = make(ns, spec)
    ns.Units.Base.editMode(spec, true)
    units.set("target", "exists", true)
    units.set("target", "casting", { name = "Bolt", duration = 1 })
    ns.Units.Base.editMode(spec, false)
    h.eq(frame.cast.frame:IsShown(), true, "cast shown")
    h.eq(frame.cast.name:GetText(), "Bolt")
  end)
end)

h.test("targettarget: values on ticks, everything on a new GUID", function()
  local guid = "A"
  withUnits({}, { targettarget = { exists = true, name = "Tank" } }, function(ns, client, units)
    fakes.withGlobals({ UnitGUID = function() return guid end }, function()
      local spec = define(ns, "tot")
      local frame = ns.Units.Base.create(spec, { unit = "targettarget", name = "AHTestToT" })
      ns.Units.Base.apply(spec)
      frame._scripts.OnUpdate(frame, 0.25) -- first GUID seen: full
      local full = units.calls.UnitClassification
      frame._scripts.OnUpdate(frame, 0.25)
      h.eq(units.calls.UnitClassification, full, "same GUID: values only")
      guid = "B"
      frame._scripts.OnUpdate(frame, 0.25)
      h.eq(units.calls.UnitClassification, full + 1, "new GUID: full")
      guid = fakes.secret(1)
      frame._scripts.OnUpdate(frame, 0.25)
      h.eq(units.calls.UnitClassification, full + 2, "secret GUID: full")
      client.fire("UNIT_TARGET", "target")
      h.eq(units.calls.UnitClassification, full + 3, "UNIT_TARGET: full")
    end)
  end)
end)
