local h = ...
local fakes = dofile("tests/fakes.lua")

-- The class resource bar module (Bars/Resource.lua) loaded from the .toc and
-- started through Core.init with a fake client, fake units, a fake
-- LibEditMode and a fake resource API reading from a table the tests change.

local BLIZZARD = { "PlayerFrame", "PlayerCastingBarFrame", "TargetFrame", "FocusFrame", "PetFrame",
  "PartyFrame", "CompactPartyFrame", "BossTargetFrameContainer" }

local POWER = { Mana = 0, Rage = 1, Energy = 3, ComboPoints = 4, Runes = 5, SoulShards = 7,
  HolyPower = 9, Chi = 12, ArcaneCharges = 16, Essence = 19 }

local function fakeLem()
  local lem = { SettingType = { Checkbox = 1, Slider = 2, Dropdown = 3, Divider = 4 }, callbacks = {} }
  function lem:AddFrame() end
  function lem:AddFrameSettings() end
  function lem:AddFrameSettingsButtons() end
  function lem:RegisterCallback(name, fn) self.callbacks[name] = fn end
  function lem:GetActiveLayoutName() return "Modern" end
  return lem
end

-- r = { class, spec, token, power[type], raw[type], max[type], mod, runes[i] =
-- { start, duration, ready }, partial, regen, now }: what the fake API answers.
local function resourceGlobals(r)
  local enum = {}
  for k, v in pairs(_G.Enum or {}) do enum[k] = v end
  enum.PowerType = POWER
  local base = {
    power = _G.UnitPower, powerMax = _G.UnitPowerMax,
  }
  return {
    Enum = enum,
    UnitClass = function() return r.class, r.class end,
    GetSpecialization = function() return r.spec end,
    UnitPowerType = function() return 0, r.token end,
    UnitPower = function(unit, ptype, raw)
      if ptype == nil then return base.power(unit) end
      if raw then return r.raw[ptype] end
      return r.power[ptype]
    end,
    UnitPowerMax = function(unit, ptype)
      if ptype == nil then return base.powerMax(unit) end
      return r.max[ptype]
    end,
    UnitPowerDisplayMod = function() return r.mod end,
    GetRuneCooldown = function(i)
      local rune = r.runes[i]
      if not rune then return nil end
      return rune[1], rune[2], rune[3]
    end,
    UnitPartialPower = function() return r.partial end,
    GetPowerRegenForPowerType = function() return r.regen end,
    GetTime = function() return r.now end,
  }
end

-- Runs fn(ns, r, client, lem) after Core.init with r as the resource state.
local function withBar(state, fn, opts)
  local r = { class = "PALADIN", spec = 1, token = "MANA", power = {}, raw = {}, max = {}, mod = 10,
    runes = {}, partial = 0, regen = 0, now = 100 }
  for k, v in pairs(state or {}) do r[k] = v end
  local client = fakes.client(opts)
  local units = fakes.units({ player = { exists = true, name = "Me", class = r.class, level = 60,
    health = 100, healthMax = 100, isPlayer = true } })
  local lem = fakeLem()
  local globals = resourceGlobals(r)
  globals.LibStub = fakes.libstub({ LibEditMode = lem })
  globals.AnotherHUDDB, globals.AnotherHUDCharDB = fakes.NIL, fakes.NIL
  globals.EditModeManagerFrame = fakes.NIL
  for _, name in ipairs(BLIZZARD) do globals[name] = fakes.frame(name) end
  local ok, err = pcall(fakes.withGlobals, globals, function()
    local ns = h.load(h.toc())
    ns.Util.say = function() end
    ns.Core.init()
    fn(ns, r, client, lem)
  end)
  units.restore()
  client.restore()
  if not ok then error(err, 0) end
end

local function lastPoint(f)
  local p
  for _, c in ipairs(f.calls) do if c[1] == "SetPoint" then p = c end end
  return p
end

local function count(f, name)
  local n = 0
  for _, c in ipairs(f.calls) do if c[1] == name then n = n + 1 end end
  return n
end

local function parts(ns)
  local spec = ns.Modules.get("resource")
  return spec, spec.bar, spec.frame, spec.seg, ns.Modules.get("player").frame
end

local function castPoint(player)
  return lastPoint(player.cast.frame)
end

h.test("a paladin gets five holy power segments under the Player frame", function()
  withBar({ class = "PALADIN", power = { [9] = 2 }, max = { [9] = 5 } }, function(ns)
    local spec, bar, holder, seg, player = parts(ns)
    h.eq(spec.kind, "bar")
    h.eq(spec.parent, "player")
    h.eq(bar:GetName(), "AnotherHUDResourceBar")
    h.eq(holder:GetName(), "AnotherHUDResourceBarHolder")
    h.eq(seg.count, 5)
    h.eq(#seg.slots, 5)
    h.eq(bar:GetParent(), player)
    h.eq(lastPoint(bar), { "SetPoint", "TOPLEFT", player, "BOTTOMLEFT", 64, -4 })
    h.eq({ bar._width, bar._height }, { 136, 18 })
    h.eq(bar:IsShown(), true, "bar shown")
    h.eq(holder:IsShown(), false, "holder hidden while attached")
    h.eq(castPoint(player), { "SetPoint", "TOPLEFT", player, "BOTTOMLEFT", 0, -26 })
    h.eq(seg.slots[1].full._value, 2, "holy power")
    h.eq(seg.slots[1].full._barColor, { ns.Theme.barColor({ 1, 0.82, 0.25 }, "Smooth") }, "holy power color")
  end)
end)

h.test("a warrior gets no bar and no reserved space", function()
  withBar({ class = "WARRIOR" }, function(ns)
    local spec, bar, holder, _, player = parts(ns)
    h.eq(spec.def, nil)
    h.eq(bar:IsShown(), false, "bar hidden")
    h.eq(holder:IsShown(), false, "holder hidden")
    h.eq(castPoint(player), { "SetPoint", "TOPLEFT", player, "BOTTOMLEFT", 0, -14 })
  end)
end)

h.test("secret holy power reaches the segments untouched", function()
  withBar({ class = "PALADIN" }, function(ns, r, client)
    local _, _, _, seg = parts(ns)
    local s = fakes.secret(3)
    r.power[9] = s
    client.fire("UNIT_POWER_FREQUENT", "player", "HOLY_POWER")
    for i = 1, 5 do h.eq(rawequal(seg.slots[i].full._value, s), true, "slot " .. i) end
  end)
end)

h.test("a druid's bar follows Cat Form in combat", function()
  withBar({ class = "DRUID", spec = 2, token = "ENERGY", max = { [4] = 5 } }, function(ns, r, client)
    local _, bar, _, seg, player = parts(ns)
    h.eq(seg.count, 5)
    h.eq(bar:IsShown(), true, "shown in Cat Form")
    h.eq(castPoint(player)[6], -26, "space kept")
    client.setCombat(true)
    local before = count(player.cast.frame, "SetPoint")
    r.token = "MANA"
    client.fire("UPDATE_SHAPESHIFT_FORM")
    h.eq(bar:IsShown(), false, "hidden out of Cat Form")
    r.token = "ENERGY"
    client.fire("UNIT_DISPLAYPOWER", "player")
    h.eq(bar:IsShown(), true, "back in Cat Form")
    h.eq(count(player.cast.frame, "SetPoint"), before, "cast bar not moved in combat")
    h.eq(castPoint(player)[6], -26, "space does not follow the form")
  end)
end)

h.test("UNIT_MAXPOWER re-lays out the segments", function()
  withBar({ class = "ROGUE", token = "ENERGY", max = { [4] = 5 } }, function(ns, r, client)
    local _, _, _, seg = parts(ns)
    h.eq(seg.count, 5)
    r.max[4] = 7
    client.fire("UNIT_MAXPOWER", "player", "COMBO_POINTS")
    h.eq(seg.count, 7)
    for i = 1, 7 do h.eq(seg.slots[i].bg._shown, true, "slot " .. i .. " shown") end
  end)
end)

h.test("soul shard fragments fill the next shard", function()
  withBar({ class = "WARLOCK", power = { [7] = 2 }, raw = { [7] = 23 }, max = { [7] = 5 } },
    function(ns, r, client)
      local _, _, _, seg = parts(ns)
      local p = seg.slots[3].partial
      h.eq({ p._min, p._max, p._value }, { 20, 30, 23 })
      h.eq(seg.slots[1].full._value, 2)
      r.mod = fakes.secret(10)
      local s = fakes.secret(23)
      r.raw[7] = s
      client.fire("UNIT_POWER_FREQUENT", "player", "SOUL_SHARDS")
      h.eq(rawequal(seg.slots[3].partial._value, s), true, "secret fragments pass through")
      h.eq({ p._min, p._max }, { 20, 30 }, "unreadable mod: 10")
    end)
end)

h.test("recharging runes sort and show seconds", function()
  local runes = { { 95, 10, false }, { 98, 10, false }, { 0, 10, true }, { 0, 10, true },
    { 0, 10, true }, { 0, 10, true } }
  withBar({ class = "DEATHKNIGHT", spec = 2, runes = runes, max = { [5] = 6 } }, function(ns, r, client)
    local _, bar, _, seg = parts(ns)
    local R = ns.Resource
    h.eq(seg.count, 6)
    h.eq(seg.slots[1].full._barColor, { ns.Theme.barColor({ 0.3, 0.7, 1 }, "Smooth") }, "frost runes")
    for i = 1, 4 do h.eq(seg.slots[i].full._value, i, "rune " .. i .. " ready") end
    h.eq(seg.slots[5].full._value, 4, "slot 5 recharging")
    h.eq(seg.slots[5].partial._value, 0.5)
    h.eq(seg.slots[5].text._text, R.timerText(5))
    h.eq(seg.slots[6].text._text, R.timerText(8))
    h.eq(bar._scripts.OnUpdate ~= nil, true, "ticker while recharging")
    r.now = 101
    bar._scripts.OnUpdate(bar, 0.1)
    h.eq(seg.slots[5].text._text, R.timerText(4), "ticker refreshes")

    ns.Options.set("player", "resourceTimers", false)
    h.eq(seg.slots[5].text._text, "", "no timers")

    r.runes[1] = { fakes.secret(95), 10, fakes.secret(false) }
    client.fire("RUNE_POWER_UPDATE", 1)
    h.eq(seg.slots[6].partial._value, 0, "secret rune last and empty")
    h.eq(seg.slots[6].full._value, 5)

    for i = 1, 6 do r.runes[i] = { 0, 10, true } end
    client.fire("RUNE_POWER_UPDATE", 1)
    h.eq(bar._scripts.OnUpdate, nil, "ticker gone when all are ready")
  end)
end)

h.test("essence shows the regenerating segment", function()
  withBar({ class = "EVOKER", power = { [19] = 3 }, max = { [19] = 5 }, partial = 550, regen = 0.2 },
    function(ns, r, client)
      local _, bar, _, seg = parts(ns)
      h.eq(seg.slots[4].partial._value, 0.55)
      h.eq(seg.slots[4].text._text, "3")
      h.eq(seg.slots[1].full._value, 3)
      h.eq(bar._scripts.OnUpdate ~= nil, true, "ticker while regenerating")
      r.partial = fakes.secret(550)
      client.fire("UNIT_POWER_FREQUENT", "player", "ESSENCE")
      h.eq(seg.slots[4].partial._value, 0, "partials cleared")
      h.eq(seg.slots[4].text._text, "")
      h.eq(seg.slots[1].full._value, 3, "whole points still set")
      h.eq(bar._scripts.OnUpdate, nil, "no ticker while unreadable")
    end)
end)

h.test("detach moves the bar to its holder and frees the space", function()
  withBar({ class = "PALADIN" }, function(ns)
    local _, bar, holder, seg, player = parts(ns)
    ns.Options.set("player", "resourceDetach", true)
    h.eq(holder:IsShown(), true, "holder shown")
    h.eq({ holder._width, holder._height }, { 200, 20 })
    h.eq(bar:GetParent(), holder)
    h.eq(bar:IsShown(), true)
    h.eq(castPoint(player), { "SetPoint", "TOPLEFT", player, "BOTTOMLEFT", 0, -14 })
    h.eq(seg.count, 5)
    ns.EditMode.Checklist.toggle("player", false)
    h.eq(holder:IsShown(), false, "holder hidden with the Player")
    h.eq(bar:IsShown(), false, "bar hidden with the Player")
    ns.EditMode.Checklist.toggle("player", true)
    h.eq(holder:IsShown(), true, "holder back")
  end)
end)

h.test("Edit Mode shows the sample", function()
  withBar({ class = "DRUID", spec = 2, token = "MANA", power = { [4] = 1 } }, function(ns, _, _, lem)
    local _, bar, _, seg = parts(ns)
    h.eq(bar:IsShown(), false, "caster form")
    lem.callbacks.enter()
    h.eq(bar:IsShown(), true, "sample shown in Edit Mode")
    for i = 1, 5 do h.eq(seg.slots[i].full._value, 3, "slot " .. i) end
    lem.callbacks.exit()
    for i = 1, 5 do h.eq(seg.slots[i].full._value, 1, "slot " .. i .. " real") end
    h.eq(bar:IsShown(), false, "hidden again in caster form")
  end)
end)

h.test("Edit Mode sample of runes shows a recharging rune", function()
  withBar({ class = "DEATHKNIGHT", spec = 1, runes = { { 0, 10, true } } }, function(ns, _, _, lem)
    local _, _, _, seg = parts(ns)
    lem.callbacks.enter()
    h.eq(seg.slots[4].partial._value, 0.55)
    h.eq(seg.slots[4].text._text, "2")
    lem.callbacks.exit()
    h.eq(seg.slots[4].text._text, "", "real values back")
  end)
end)

h.test("a fire mage has no bar", function()
  withBar({ class = "MAGE", spec = 2 }, function(ns, r, client)
    local _, bar, holder, seg, player = parts(ns)
    h.eq(bar:IsShown(), false)
    h.eq(holder:IsShown(), false)
    h.eq(castPoint(player)[6], -14)
    r.spec = 1
    client.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    h.eq(bar:IsShown(), true, "arcane shown")
    h.eq(seg.count, 4)
    h.eq(castPoint(player)[6], -26)
  end)
end)
