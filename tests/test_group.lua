local h = ...
local fakes = dofile("tests/fakes.lua")

-- Units/Group.lua: ns.Units.defineGroup builds a holder (the Edit Mode
-- frame) and member unit buttons at fixed tokens, orders and places them.

local function load()
  local ns = h.load({ "Core/Util.lua", "Core/Locale.lua", "Locales/deDE.lua", "Core/Theme.lua",
    "Core/DB.lua", "Core/Modules.lua", "Core/Combat.lua", "Core/Options.lua",
    "Core/UnitText.lua", "Core/UnitColor.lua", "Core/UnitState.lua", "Core/UnitLayout.lua",
    "Core/GroupLayout.lua",
    "Units/Settings.lua", "Units/Parts/Panel.lua", "Units/Parts/Ring.lua", "Units/Parts/Bars.lua",
    "Units/Parts/CastBar.lua", "Units/Parts/Auras.lua", "Units/Parts/Role.lua", "Units/Parts/Dispel.lua",
    "Units/Base.lua", "Units/Group.lua" })
  ns.db, ns.chardb = ns.DB.init(nil, nil)
  return ns
end

-- Fixtures: the mockup's members (Task 7 owns the real lists).
local PARTY_SAMPLES = {
  { name = "Arthelis", class = "PALADIN", role = "TANK", leader = true, healthPct = 84 },
  { name = "Lunaria", class = "PRIEST", role = "HEALER", healthPct = 97 },
  { name = "Brakka", class = "WARRIOR", role = "DAMAGER", healthPct = 41, dispel = "Magic" },
  { name = "Ssylith", class = "MAGE", role = "DAMAGER", healthPct = 66, far = true },
  { name = "Torvald", class = "HUNTER", role = "DAMAGER", healthPct = 0, dead = true },
}
local BOSS_SAMPLES = {
  { name = "Vyrastra", healthPct = 62, reaction = 2, classification = "elite" },
  { name = "Ironmaw", healthPct = 88, reaction = 2, classification = "elite" },
  { name = "The Hollow King", healthPct = 31, reaction = 2, classification = "elite" },
  { name = "Grimscale", healthPct = 54, reaction = 2, classification = "elite" },
  { name = "Sister Vexa", healthPct = 77, reaction = 2, classification = "elite" },
}

local function party(ns)
  local spec = ns.Units.defineGroup({
    id = "party", label = "Party", name = "AHTestParty",
    units = { "player", "party1", "party2", "party3", "party4" },
    visibility = ns.GroupLayout.partyVisibility,
    auras = true, auraMode = "line", auraSide = "right", range = true, role = true, dispel = true,
    roles = true, samples = PARTY_SAMPLES,
    parts = { "Group", "Size", "Text", "Look", "Behaviour", "Auras", "Fading",
      orientation = true, roles = true, portrait = true, power = true },
    defaults = { width = 160, height = 40, portraitScale = 92, powerHeight = 5, fontSize = 10,
      healthText = "Percent", powerText = "None", auraSize = 20 },
    defaultPosition = { point = "LEFT", x = 40, y = 120 },
  })
  spec.create(spec)
  return spec
end

local function boss(ns)
  local spec = ns.Units.defineGroup({
    id = "boss", label = "Boss", name = "AHTestBoss",
    units = { "boss1", "boss2", "boss3", "boss4", "boss5" },
    visibility = ns.GroupLayout.bossVisibility,
    mirror = true, castBar = true, castGap = ns.Theme.sizes.unit.bossCastGap, auras = true,
    auraSide = "left", badge = ns.Theme.sizes.unit.focusBadge, samples = BOSS_SAMPLES,
    parts = { "Group", "Size", "Text", "Look", "Cast Bar", "Auras", portrait = true, power = true },
    defaults = { width = 180, height = 42, powerHeight = 6, fontSize = 10, healthText = "Percent",
      powerText = "None", castWidth = 180, castHeight = 16, buffs = false, onlyMine = true, gap = 12 },
    defaultPosition = { point = "RIGHT", x = -120, y = 120 },
    orderEvents = { "INSTANCE_ENCOUNTER_ENGAGE_UNIT" },
  })
  spec.create(spec)
  return spec
end

-- Runs fn(ns, client, units) with a fake client (CreateFrame keeps the
-- parent) and unit API.
local function withUnits(opts, map, fn)
  local client = fakes.client(opts)
  local create = _G.CreateFrame
  _G.CreateFrame = function(kind, name, parent, tpl)
    local f = create(kind, name, parent, tpl)
    f._parent = parent
    f._kind = kind
    return f
  end
  local units = fakes.units(map)
  local ok, err = pcall(fn, load(), client, units)
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

-- The y offset of each member (by slot index) inside the holder.
local function ys(spec)
  local out = {}
  for i, m in ipairs(spec.members) do
    local p = lastPoint(m)
    h.eq(p[3], spec.frame, "member " .. i .. " anchored to the holder")
    out[i] = p[6]
  end
  return out
end

local ME = { exists = true, name = "Me", class = "MAGE", isPlayer = true }

h.test("holder is the Edit Mode frame, members are its children", function()
  withUnits({}, { player = ME }, function(ns)
    local spec = party(ns)
    local holder = spec.frame
    h.eq(spec.kind, "unit")
    h.eq(ns.Modules.get("party"), spec)
    h.eq(holder:GetName(), "AHTestParty")
    h.eq(holder._kind, "Frame", "plain frame")
    h.eq(holder:GetParent(), UIParent)
    h.eq(#spec.members, 5)
    for i, m in ipairs(spec.members) do
      h.eq(m:GetName(), "AHTestParty" .. i)
      h.eq(m:GetParent(), holder, "member " .. i .. " on the holder")
      h.eq(m.key, "party:" .. i)
      h.eq(m:GetAttribute("unit"), spec.members[i].unit)
      h.eq(m._events.GROUP_ROSTER_UPDATE, true, "roster")
      h.eq(m.role ~= false and m.dispel ~= false and m.range, true, "party parts")
    end
    h.eq(spec.members[2]:GetAttribute("unit"), "party1")
    h.eq(holder._events.GROUP_ROSTER_UPDATE, true)
    h.eq(holder._events.PLAYER_ROLES_ASSIGNED, true)
    h.eq({ holder._width, holder._height }, { 160, 232 }, "five blocks, 8 px apart")
    h.eq(spec.settings[1].section, "Group", "Group section first")
  end)
end)

h.test("holder gets the party driver, Edit Mode shows it", function()
  withUnits({}, { player = ME }, function(ns, client)
    local spec = party(ns)
    local holder = spec.frame
    h.eq(client.drivers[holder].cond, ns.GroupLayout.partyVisibility())
    holder:Hide()
    spec.onEditMode(spec, true)
    h.eq(client.drivers[holder], nil, "no driver while open")
    h.eq(holder:IsShown(), true, "shown")
    spec.onEditMode(spec, false)
    h.eq(client.drivers[holder].cond, ns.GroupLayout.partyVisibility(), "driver back")
  end)
end)

h.test("members sorted by role after roster change", function()
  withUnits({}, { player = ME }, function(ns, client, units)
    local spec = party(ns)
    h.eq(ys(spec), { 0, -48, -96, -144, -192 }, "index order")
    units.set("player", "role", "DAMAGER")
    for _, u in ipairs({ "party1", "party2", "party3" }) do units.set(u, "exists", true) end
    units.set("party1", "role", "HEALER")
    units.set("party2", "role", "DAMAGER")
    units.set("party3", "role", "TANK")
    client.fire("GROUP_ROSTER_UPDATE")
    -- party3 (tank), party1 (healer), player, party2 (damage), party4 (missing)
    h.eq(ys(spec), { -96, -48, -144, 0, -192 })
    units.set("party2", "role", "TANK")
    units.set("party3", "role", "DAMAGER")
    client.fire("PLAYER_ROLES_ASSIGNED")
    h.eq(ys(spec), { -96, -48, 0, -144, -192 }, "roles assigned")
  end)
end)

h.test("roster change in combat re-sorts after combat", function()
  withUnits({}, { player = ME }, function(ns, client, units)
    local spec = party(ns)
    local before = count(spec.members[3], "SetPoint")
    client.setCombat(true)
    units.set("party2", "exists", true)
    units.set("party2", "role", "TANK")
    client.fire("GROUP_ROSTER_UPDATE")
    h.eq(count(spec.members[3], "SetPoint"), before, "nothing moves in combat")
    h.eq(ys(spec), { 0, -48, -96, -144, -192 })
    client.setCombat(false)
    client.fire("PLAYER_REGEN_ENABLED")
    h.eq(ys(spec), { -48, -96, 0, -144, -192 }, "tank first after combat")
  end)
end)

h.test("show player off hides the player slot and shrinks the block", function()
  withUnits({}, { player = ME }, function(ns, client)
    local spec = party(ns)
    local me = spec.members[1]
    h.eq(client.drivers[me] ~= nil, true, "player driven")
    ns.Options.set("party", "showPlayer", false)
    h.eq(me:IsShown(), false, "player hidden")
    h.eq(client.drivers[me], nil, "no player driver")
    h.eq(spec.frame._height, 184, "four blocks")
    local y = {}
    for i = 2, 5 do y[#y + 1] = lastPoint(spec.members[i])[6] end
    h.eq(y, { 0, -48, -96, -144 })
    ns.Options.set("party", "showPlayer", true)
    h.eq(client.drivers[me] ~= nil, true, "player back")
    h.eq(spec.frame._height, 232)
  end)
end)

h.test("growth and orientation move the members", function()
  withUnits({}, { player = ME }, function(ns)
    local spec = party(ns)
    local last = spec.members[5]
    h.eq(lastPoint(last), { "SetPoint", "TOPLEFT", spec.frame, "TOPLEFT", 0, -192 })
    ns.Options.set("party", "growth", "Up / Left")
    h.eq(lastPoint(last), { "SetPoint", "BOTTOMLEFT", spec.frame, "BOTTOMLEFT", 0, 192 })
    ns.Options.set("party", "orientation", "Horizontal")
    h.eq(lastPoint(last), { "SetPoint", "TOPRIGHT", spec.frame, "TOPRIGHT", -672, 0 })
    ns.Options.set("party", "growth", "Down / Right")
    h.eq(lastPoint(last), { "SetPoint", "TOPLEFT", spec.frame, "TOPLEFT", 672, 0 })
    h.eq({ spec.frame._width, spec.frame._height }, { 832, 40 })
    ns.Options.set("party", "gap", 0)
    h.eq(lastPoint(last)[5], 640, "gap")
  end)
end)

h.test("boss blocks include the cast bar", function()
  withUnits({}, {}, function(ns, client)
    local spec = boss(ns)
    h.eq(client.drivers[spec.frame].cond, ns.GroupLayout.bossVisibility())
    h.eq(lastPoint(spec.members[2]), { "SetPoint", "TOPLEFT", spec.frame, "TOPLEFT", 0, -74 })
    h.eq({ spec.frame._width, spec.frame._height }, { 180, 5 * 62 + 4 * 12 })
    h.eq(spec.members[1].mirror, true)
    h.eq(spec.members[1].cast ~= false, true, "cast bar")
    h.eq(spec.members[1].role, false, "no role badge")
    h.eq(spec.members[1].range, false, "no range")
    h.eq(spec.frame._events.PLAYER_ROLES_ASSIGNED, nil, "no roles")
    h.eq(spec.frame._scripts.OnUpdate, nil, "no range ticker")
    ns.Options.set("boss", "castBar", false)
    h.eq(lastPoint(spec.members[2])[6], -54, "without the cast bar")
  end)
end)

h.test("group off hides holder and members", function()
  withUnits({}, { player = ME }, function(ns, client)
    local spec = party(ns)
    ns.Modules.setEnabled("party", false)
    spec.apply(spec)
    h.eq(spec.frame:IsShown(), false, "holder hidden")
    h.eq(client.drivers[spec.frame], nil, "no holder driver")
    for i, m in ipairs(spec.members) do
      h.eq(m:IsShown(), false, "member " .. i .. " hidden")
      h.eq(client.drivers[m], nil, "member " .. i .. " no driver")
    end
    spec.onEditMode(spec, true)
    h.eq(spec.frame:IsShown(), false, "Edit Mode keeps it hidden")
    spec.onEditMode(spec, false)
    ns.Modules.setEnabled("party", true)
    spec.apply(spec)
    h.eq(client.drivers[spec.frame].cond, ns.GroupLayout.partyVisibility(), "holder back")
    h.eq(client.drivers[spec.members[3]] ~= nil, true, "member back")
  end)
end)

h.test("edit mode samples every slot and restores drivers", function()
  withUnits({}, { player = ME, party2 = { exists = true, role = "TANK" } }, function(ns, client)
    local spec = party(ns)
    h.eq(ys(spec), { -48, -96, 0, -144, -192 }, "live: tank first")
    spec.onEditMode(spec, true)
    h.eq(ys(spec), { 0, -48, -96, -144, -192 }, "Edit Mode: index order")
    for i, m in ipairs(spec.members) do
      h.eq(m:IsShown(), true, "member " .. i .. " shown")
      h.eq(client.drivers[m], nil, "member " .. i .. " no driver")
      h.eq(m.bars.name:GetText(), PARTY_SAMPLES[i].name)
    end
    h.near(spec.members[4]:GetAlpha(), 0.55) -- far sample
    h.eq(spec.members[3].dispel.sampleTex:IsShown(), true, "dispel sample")
    ns.Options.set("party", "showPlayer", false)
    h.eq(spec.members[1]:IsShown(), false, "player slot gone")
    h.eq(spec.frame._height, 184, "block shrinks in Edit Mode")
    h.eq(lastPoint(spec.members[2])[6], 0)
    ns.Options.set("party", "showPlayer", true)
    h.eq(spec.members[1]:IsShown(), true, "player sample back")
    h.eq(spec.members[1].bars.name:GetText(), "Arthelis")
    h.eq(client.drivers[spec.members[1]], nil, "still no driver")
    spec.onEditMode(spec, false)
    for i, m in ipairs(spec.members) do
      h.eq(client.drivers[m] ~= nil, true, "member " .. i .. " driver back")
    end
    h.eq(client.drivers[spec.frame].cond, ns.GroupLayout.partyVisibility())
    h.eq(ys(spec), { -48, -96, 0, -144, -192 }, "live order back")
  end)
end)

h.test("range ticker fades shown members", function()
  withUnits({}, { player = ME, party1 = { exists = true, inRange = false, rangeChecked = true },
    party2 = { exists = true, inRange = false, rangeChecked = true } }, function(ns)
    local spec = party(ns)
    local tick = spec.frame._scripts.OnUpdate
    h.eq(type(tick), "function", "ticker")
    for _, m in ipairs(spec.members) do m._alphaFrom = nil end
    spec.members[3]:Hide()
    tick(spec.frame, 0.3)
    h.eq(spec.members[2]._alphaFrom, nil, "not yet")
    tick(spec.frame, 0.3)
    h.eq(spec.members[2]._alphaFrom ~= nil, true, "faded by range")
    h.eq(spec.members[3]._alphaFrom, nil, "hidden member skipped")
    spec.members[2]._alphaFrom = nil
    tick(spec.frame, 0.1)
    h.eq(spec.members[2]._alphaFrom, nil, "timer restarted")
  end)
end)

h.test("orderEvents re-sort the block", function()
  withUnits({}, { boss2 = { exists = true } }, function(ns, client, units)
    local spec = boss(ns)
    h.eq(spec.frame._events.INSTANCE_ENCOUNTER_ENGAGE_UNIT, true, "registered")
    h.eq(spec.frame._events.PLAYER_ROLES_ASSIGNED, nil, "still no roles event")
    -- created with boss2 present: it is already first
    h.eq(ys(spec)[2], 0)
    units.set("boss2", "exists", false)
    units.set("boss3", "exists", true)
    client.fire("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    h.eq(ys(spec)[3], 0, "boss3 at the top after the event")
    h.eq(ys(spec)[2], -148, "boss2 behind the missing boss1")
  end)
end)

h.test("edit mode enter and exit in combat restore drivers and order", function()
  withUnits({}, { player = ME, party2 = { exists = true, role = "TANK" } }, function(ns, client)
    local spec = party(ns)
    h.eq(ys(spec), { -48, -96, 0, -144, -192 }, "live: tank first")
    client.setCombat(true)
    spec.onEditMode(spec, true)
    spec.onEditMode(spec, false)
    client.setCombat(false)
    client.fire("PLAYER_REGEN_ENABLED")
    h.eq(client.drivers[spec.frame].cond, ns.GroupLayout.partyVisibility(), "holder driver back")
    for i, m in ipairs(spec.members) do
      h.eq(client.drivers[m] ~= nil, true, "member " .. i .. " driver back")
    end
    h.eq(ys(spec), { -48, -96, 0, -144, -192 }, "live order applies")
  end)
end)
