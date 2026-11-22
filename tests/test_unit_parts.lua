local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  return h.load({ "Core/Util.lua", "Core/Locale.lua", "Locales/deDE.lua", "Core/Theme.lua",
    "Core/UnitLayout.lua", "Units/Settings.lua", "Units/Parts/Panel.lua", "Units/Parts/Ring.lua",
    "Units/Parts/Bars.lua", "Units/Parts/Auras.lua", "Units/Parts/Role.lua", "Units/Parts/Dispel.lua" })
end

-- Runs fn(ns) with a fake client and unit API; restores units first, then
-- the client (reverse install order).
local function withClient(fn)
  local client = fakes.client({})
  local units = fakes.units({})
  local ok, err = pcall(fn, load())
  units.restore()
  client.restore()
  if not ok then error(err, 0) end
end

local function point(frame, name)
  for i = #frame.calls, 1, -1 do
    local c = frame.calls[i]
    if c[1] == "SetPoint" and c[2] == name then return c end
  end
end

local function shownCount(list)
  local n = 0
  for _, t in ipairs(list) do if t:IsShown() then n = n + 1 end end
  return n
end

local function player(ns, extra)
  local o = { w = 200, h = 60, powerH = 15, portraitScale = 100, edge = 4, badge = 18 }
  for k, v in pairs(extra or {}) do o[k] = v end
  return ns.UnitLayout.frame(o)
end

h.test("bars take secrets", function()
  withClient(function(ns)
    local bars = ns.Units.Parts.Bars.create(fakes.frame())
    bars:layout(player(ns), { texture = "Smooth", fontSize = 11, showName = true })
    local cur, max = fakes.secret(1), fakes.secret(2)
    bars:setHealth(cur, max)
    h.eq(rawequal(bars.health:GetValue(), cur), true, "health value stored")
    local pc, pm = fakes.secret(3), fakes.secret(4)
    bars:setPower(pc, pm)
    h.eq(rawequal(bars.power:GetValue(), pc), true, "power value stored")
    local name, a, b = fakes.secret(5), fakes.secret(6), fakes.secret(7)
    bars:setTexts(name, "%s | %.0f%%", { a, b }, "%s", { pc })
    h.eq(rawequal(bars.name:GetText(), name), true, "name stored")
    h.eq(bars.healthText._fmt, "%s | %.0f%%")
    h.eq(rawequal(bars.healthText._args[1], a) and rawequal(bars.healthText._args[2], b), true)
    h.eq(rawequal(bars.powerText._args[1], pc), true)
    bars:setTexts("Name", "", {}, "", {})
    h.eq(bars.healthText:GetText(), "")
    h.eq(bars.powerText:GetText(), "")
  end)
end)

h.test("bars layout follows the geometry", function()
  withClient(function(ns)
    local L = ns.UnitLayout.frame({ w = 200, h = 60, powerH = 15, portraitScale = 100, edge = 4 })
    local bars = ns.Units.Parts.Bars.create(fakes.frame())
    bars:layout(L, { texture = "Smooth", fontSize = 11, showName = true })
    local tl = point(bars.health, "TOPLEFT")
    h.eq({ tl[5], tl[6] }, { 63.5, -5 })
    local tr = point(bars.health, "TOPRIGHT")
    h.eq({ tr[5], tr[6] }, { -5, -5 })
    h.eq(bars.health._height, 34)
    h.eq(bars.power._height, 15)
    h.eq(bars.power:IsShown(), true)
    h.eq(bars.divider:IsShown(), true)
    local d = point(bars.divider, "TOPLEFT")
    h.eq({ d[5], d[6] }, { 63.5, -39 })
  end)
end)

h.test("divider follows the Lines pick", function()
  withClient(function(ns)
    local T = ns.Theme
    local bars = ns.Units.Parts.Bars.create(fakes.frame())
    local gl, k = T.colors.goldLine, T.skinScales
    local function run(id)
      bars:layout(player(ns), { texture = "Smooth", fontSize = 11, skin = T.skins[id] })
      return bars.divider._color
    end
    local c = run("classic")
    h.eq(c, { gl[1], gl[2], gl[3], T.colors.divider[4] })
    h.eq(bars.groove:IsShown(), false)
    c = run("gilded")
    h.eq(c[4], T.colors.divider[4], "dotted alpha")
    c = run("slate")
    h.eq(c[4], 1, "plain alpha")
    c = run("forge")
    local dark, light = T.scaleColor(gl, k.grooveDark), T.scaleColor(gl, k.grooveLight)
    h.eq(c, { dark[1], dark[2], dark[3], 1 })
    h.eq(bars.groove._color, { light[1], light[2], light[3], k.grooveLightAlpha })
    h.eq(bars.groove:IsShown(), true)
    h.eq(bars.levels.groove < bars.levels.power, true, "groove line under the power bar")
    h.eq(bars.levels.divider > bars.levels.power, true, "divider above the bars")
    local g = point(bars.groove, "TOPLEFT")
    h.eq({ g[5], g[6] }, { 63.5, -40 })
  end)
end)

h.test("texts mirror and keep apart", function()
  withClient(function(ns)
    local bars = ns.Units.Parts.Bars.create(fakes.frame())
    -- Fonts are set at create: texts before layout do not error.
    for _, fs in ipairs({ bars.name, bars.healthText, bars.powerText }) do
      h.eq(fs._font, { ns.Theme.fonts.file, 11, "OUTLINE" })
    end
    h.eq(ns.Units.Parts.Ring.create(fakes.frame()).level._font[3], "OUTLINE")
    bars:setTexts("Name", "%s", { "1" }, "%s", { "2" })
    local L = player(ns, { mirror = true })
    bars:layout(L, { texture = "Smooth", fontSize = 11, mirror = true })
    local n = point(bars.name, "RIGHT")
    h.eq({ n[5], n[6] }, { 136.5 - 4, -22 })
    local v = point(bars.healthText, "LEFT")
    h.eq({ v[5], v[6] }, { 5 + 4, -22 })
    local bw = 136.5 - 5
    h.eq(bars.name._width, bw * ns.Theme.sizes.unit.nameShare - 4)
    h.eq(bars.healthText._width, bw * (1 - ns.Theme.sizes.unit.nameShare) - 4)
    bars:layout(player(ns), { texture = "Smooth", fontSize = 11 })
    n = point(bars.name, "LEFT")
    h.eq({ n[5], n[6] }, { 63.5 + 4, -22 })
    v = point(bars.healthText, "RIGHT")
    h.eq({ v[5], v[6] }, { 195 - 4, -22 })
  end)
end)

h.test("parts default to the classic skin", function()
  withClient(function(ns)
    local ring = ns.Units.Parts.Ring.create(fakes.frame())
    ring:layout(player(ns), {})
    h.eq(shownCount(ring.lines), #ns.Theme.ringRoundShades)
    local panel = ns.Units.Parts.Panel.create(fakes.frame())
    panel:layout(player(ns))
    h.eq(shownCount(panel.edges), 0)
  end)
end)

h.test("no power bar when the layout has none", function()
  withClient(function(ns)
    local bars = ns.Units.Parts.Bars.create(fakes.frame())
    bars:layout(player(ns), { texture = "Flat", fontSize = 10, showName = true })
    bars:layout(ns.UnitLayout.frame({ w = 120, h = 26, powerH = 0, portraitScale = 100, edge = 4 }),
      { texture = "Flat", fontSize = 10, showName = true })
    h.eq(bars.power:IsShown(), false)
    h.eq(bars.divider:IsShown(), false)
    h.eq(bars.powerText:IsShown(), false)
  end)
end)

h.test("ring has one disc per edge line", function()
  withClient(function(ns)
    local ring = ns.Units.Parts.Ring.create(fakes.frame())
    local Theme = ns.Theme
    ring:layout(player(ns), { skin = Theme.skins.forge })
    h.eq(shownCount(ring.lines), 5)
    ring:layout(player(ns), { skin = Theme.skins.classic })
    h.eq(shownCount(ring.lines), #Theme.ringRoundShades)
    h.eq(ring.lines[1]._width, 75)
    h.eq(ring.lines[2]._width, 73)
    h.eq(ring.portrait._width, 75 - 2 * 4)
  end)
end)

h.test("ring studs and badge follow the layout", function()
  withClient(function(ns)
    local ring = ns.Units.Parts.Ring.create(fakes.frame())
    local Theme = ns.Theme
    ring:layout(player(ns), { skin = Theme.skins.gilded })
    h.eq(shownCount(ring.studs), 4)
    h.eq(ring.badge:IsShown(), true)
    ring:layout(player(ns, { badge = false }), { skin = Theme.skins.classic })
    h.eq(shownCount(ring.studs), 0)
    h.eq(ring.badge:IsShown(), false)
    local lvl = fakes.secret(8)
    ring:setLevel("%d", { lvl })
    h.eq(rawequal(ring.level._args[1], lvl), true)
    ring:setColors(Theme.colors.gold, Theme.unitColors.rare)
    ring:setUnit("target")
    h.eq(ring.portrait._portraitUnit, "target")
  end)
end)

h.test("panel studs only on the free corners", function()
  withClient(function(ns)
    local panel = ns.Units.Parts.Panel.create(fakes.frame())
    local Theme = ns.Theme
    panel:layout(player(ns), { skin = Theme.skins.gilded })
    h.eq(shownCount(panel.edges), 6 * 4)
    h.eq(panel.studs.TOPRIGHT:IsShown(), true)
    h.eq(panel.studs.TOPLEFT:IsShown(), false)
    panel:layout(player(ns), { skin = Theme.skins.classic })
    h.eq(shownCount(panel.edges), 0)
    h.eq(panel.studs.TOPRIGHT:IsShown(), false)
  end)
end)

-- Group parts: role badge, crown, dispel glow, aura line.
local function roleLayout(ns, extra)
  local o = { w = 160, h = 40, powerH = 5, portraitScale = 92, edge = 4, badge = false, role = true }
  for k, v in pairs(extra or {}) do o[k] = v end
  return ns.UnitLayout.frame(o)
end

h.test("role badge shows plain roles only", function()
  withClient(function(ns)
    local T = ns.Theme
    local role = ns.Units.Parts.Role.create(fakes.frame())
    role:layout(roleLayout(ns), { skin = T.skins.forge })
    h.eq(role.badge:IsShown(), false, "no role yet")
    for _, r in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
      role:setRole(r)
      h.eq(role.badge:IsShown(), true, r)
      h.eq(role.glyph._texture, T.textures.role[r])
    end
    h.eq(role.glyph._width, 15 * 0.72)
    for _, r in ipairs({ "NONE", false, fakes.secret("TANK") }) do
      role:setRole("TANK")
      role:setRole(r)
      h.eq(role.badge:IsShown(), false)
    end
    role:setRole("TANK")
    role:setRole(nil)
    h.eq(role.badge:IsShown(), false)
    h.eq(shownCount(role.lines), #ns.Units.Parts.Ring.shadesOf(T.skins.forge.border))
    h.eq(role.lines[1]._width, 15)
    h.eq(role.lines[2]._width, 13)
  end)
end)

h.test("role setUnit reads the unit API", function()
  withClient(function(ns)
    local role = ns.Units.Parts.Role.create(fakes.frame())
    role:layout(roleLayout(ns), {})
    local units = fakes.units({ party1 = { role = "HEALER", leader = true }, party2 = { role = "NONE", leader = false } })
    local ok, err = pcall(function()
      role:setUnit("party1")
      h.eq(role.badge:IsShown(), true)
      h.eq(role.crown:IsShown(), true)
      role:setUnit("party2")
      h.eq(role.badge:IsShown(), false)
      h.eq(role.crown:IsShown(), false)
    end)
    units.restore()
    if not ok then error(err, 0) end
  end)
end)

h.test("crown only for a plain leader", function()
  withClient(function(ns)
    local role = ns.Units.Parts.Role.create(fakes.frame())
    local L = roleLayout(ns)
    role:layout(L, {})
    h.eq(role.crown:IsShown(), false)
    role:setLeader(true)
    h.eq(role.crown:IsShown(), true)
    h.eq(role.crown._width, 12)
    h.eq(role.crown._height, 9)
    h.eq(point(role.crown, "TOP")[6], -L.crown.top)
    role:setLeader(fakes.secret(true))
    h.eq(role.crown:IsShown(), false)
    role:setLeader(true)
    role:setLeader(false)
    h.eq(role.crown:IsShown(), false)
  end)
end)

h.test("role and crown hidden without L.role", function()
  withClient(function(ns)
    local role = ns.Units.Parts.Role.create(fakes.frame())
    role:layout(roleLayout(ns), {})
    role:setRole("TANK")
    role:setLeader(true)
    h.eq(role.badge:IsShown(), true)
    role:layout(roleLayout(ns, { role = false }), {})
    h.eq(role.badge:IsShown(), false)
    h.eq(role.crown:IsShown(), false)
  end)
end)

-- A fake AuraContainer with slots and groups.
local function fakeContainer()
  local c = fakes.frame()
  c.groups, c.slots = {}, {}
  function c:AddAuraGroup(key, filter, opts) self.groups[#self.groups + 1] = { key = key, filter = filter, opts = opts } end
  function c:AddAuraSlot(key, filter, opts) self.slots[key] = { filter = filter, opts = opts } end
  return c
end

local function withContainers(fn, noSlot)
  withClient(function(ns)
    local containers = {}
    local create = _G.CreateFrame
    _G.CreateFrame = function(kind, ...)
      if kind == "AuraContainer" then
        local c = fakeContainer()
        if noSlot then c.AddAuraSlot = false end
        containers[#containers + 1] = c
        return c
      end
      return create(kind, ...)
    end
    local ok, err = pcall(fn, ns, containers)
    _G.CreateFrame = create
    if not ok then error(err, 0) end
  end)
end

h.test("dispel slot uses the raid filter and our glow", function()
  withContainers(function(ns, cs)
    local U = ns.Theme.sizes.unit
    local parent = fakes.frame()
    parent._width, parent._height = 160, 40
    local dispel = ns.Units.Parts.Dispel.create(parent, "party1")
    h.eq(dispel.available, true)
    h.eq(#cs, 1)
    local slot = cs[1].slots.dispel
    h.eq(slot.filter, "HARMFUL|RAID")
    local calls = {}
    local button = fakes.frame()
    function button:AddDispelTypeTexture(tex, opts) calls[#calls + 1] = { tex, opts } end
    local oldEnum = _G.Enum
    _G.Enum = { CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = "Preserve" } }
    slot.opts.initializeFrame(button)
    _G.Enum = oldEnum
    h.eq(#calls, 1)
    local tex, opts = calls[1][1], calls[1][2]
    h.eq(tex._texture, ns.Theme.textures.glow)
    h.eq(opts.showWhenHarmful, true)
    h.eq(opts.showWhenHelpful, false)
    h.eq(opts.style, "Preserve")
    h.eq(button._width, 160, "covers the frame")
    h.eq(button._height, 40)
    h.eq(tex._slice, { U.glowSlice, U.glowSlice, U.glowSlice, U.glowSlice })
    h.eq(point(tex, "TOPLEFT")[5], -U.glow, "reaches out on every side")
    h.eq(point(tex, "TOPLEFT")[6], U.glow)
    h.eq(point(tex, "BOTTOMRIGHT")[5], U.glow)
    h.eq(point(tex, "BOTTOMRIGHT")[6], -U.glow)
    parent._width = 100
    dispel:layout()
    h.eq(button._width, 100, "follows the frame")
  end)
end)

h.test("dispel without the template does nothing", function()
  withContainers(function(ns)
    local dispel = ns.Units.Parts.Dispel.create(fakes.frame(), "party1")
    h.eq(dispel.available, false)
    dispel:layout()
    dispel:sample({ 1, 0, 0, 1 })
    dispel:sample(nil)
  end, true)
  withClient(function(ns)
    local create = _G.CreateFrame
    _G.CreateFrame = function(kind, ...)
      if kind == "AuraContainer" then error("no such template") end
      return create(kind, ...)
    end
    local ok, d = pcall(ns.Units.Parts.Dispel.create, fakes.frame(), "party1")
    _G.CreateFrame = create
    h.eq(ok, true, "no error")
    h.eq(d.available, false)
  end)
end)

h.test("dispel sample tints and hides", function()
  withContainers(function(ns, cs)
    local dispel = ns.Units.Parts.Dispel.create(fakes.frame(), "party1")
    local red = ns.Theme.unitColors.debuff.none
    dispel:sample(red)
    h.eq(dispel.sampleTex:IsShown(), true)
    h.eq(dispel.sampleTex._color, { red[1], red[2], red[3], red[4] })
    h.eq(cs[1]:IsShown(), false, "live glow hidden under the sample")
    dispel:sample(nil)
    h.eq(dispel.sampleTex:IsShown(), false)
    h.eq(cs[1]:IsShown(), true)
  end)
end)

local function lineAuras(ns)
  local auras = ns.Units.Parts.Auras.create(fakes.frame(), "party1", "line")
  auras:layout({ size = 20, rows = 1, width = 200, buffs = true, debuffs = true, onlyMine = false })
  return auras
end

h.test("aura line holds debuffs then my buffs", function()
  withContainers(function(ns, cs)
    local auras = lineAuras(ns)
    h.eq(#cs, 1, "one container")
    local keys, filters = {}, {}
    for i, g in ipairs(cs[1].groups) do keys[i], filters[i] = g.key, g.filter end
    h.eq(keys, { "debuffMine", "debuffOther", "buffMine" })
    h.eq(filters, { "HARMFUL|PLAYER", "HARMFUL|!PLAYER", "HELPFUL|PLAYER" })
    h.eq(cs[1].groups[3].opts.layout.layoutIndex, 3)
    h.eq(auras.frame._height, 20, "one line")
    h.eq(auras.frame._width, 200)
    h.eq(auras.kinds.line.clip._height, 20)
    -- rows mode is unchanged
    ns.Units.Parts.Auras.create(fakes.frame(), "target")
    h.eq(#cs, 3, "rows mode: two more containers")
    h.eq(cs[3].groups[2].key, "buffOther")
  end)
end)

h.test("aura line samples in one row", function()
  withContainers(function(ns, cs)
    local auras = lineAuras(ns)
    auras:sample(true)
    local shown, xs = 0, {}
    for _, p in ipairs(auras.samples) do
      if p.holder:IsShown() then
        shown = shown + 1
        local pt = point(p.holder, "TOPLEFT")
        xs[#xs + 1] = pt[5]
        h.eq(pt[6], 0, "one row")
      end
    end
    h.eq(shown, 5, "4 debuffs and my buff, not the other player's buff")
    h.eq(xs, { 0, 22, 44, 66, 88 })
    h.eq(cs[1]:IsShown(), false)
    auras:sample(false)
    h.eq(cs[1]:IsShown(), true)
  end)
end)

-- A plain value the client reports as secret (a table fake is rejected by
-- the type checks alone, so it does not prove the isSecret guard).
local function withSecretPlain(values, fn)
  local old = _G.issecretvalue
  _G.issecretvalue = function(v)
    for _, s in ipairs(values) do if rawequal(v, s) then return true end end
    return fakes.isSecret(v)
  end
  local ok, err = pcall(fn)
  _G.issecretvalue = old
  if not ok then error(err, 0) end
end

h.test("role and crown hide when a plain looking value is secret", function()
  withClient(function(ns)
    local role = ns.Units.Parts.Role.create(fakes.frame())
    role:layout(roleLayout(ns), {})
    role:setRole("TANK")
    role:setLeader(true)
    h.eq(role.badge:IsShown(), true)
    h.eq(role.crown:IsShown(), true)
    withSecretPlain({ "TANK", true }, function()
      role:setRole("TANK")
      h.eq(role.badge:IsShown(), false, "secret role")
      role:setLeader(true)
      h.eq(role.crown:IsShown(), false, "secret leader")
    end)
    local units = fakes.units({ party1 = { role = "TANK", leader = true } })
    local ok, err = pcall(function()
      role:setUnit("party1")
      h.eq(role.badge:IsShown(), true)
      h.eq(role.crown:IsShown(), true)
      withSecretPlain({ "TANK", true }, function()
        role:setUnit("party1")
        h.eq(role.badge:IsShown(), false, "secret role via setUnit")
        h.eq(role.crown:IsShown(), false, "secret leader via setUnit")
      end)
    end)
    units.restore()
    if not ok then error(err, 0) end
  end)
end)

h.test("aura line without debuffs starts at the left", function()
  withContainers(function(ns)
    local auras = ns.Units.Parts.Auras.create(fakes.frame(), "party1", "line")
    auras:layout({ size = 20, rows = 1, width = 200, buffs = true, debuffs = false, onlyMine = false })
    auras:sample(true)
    local xs = {}
    for _, p in ipairs(auras.samples) do
      if p.holder:IsShown() then xs[#xs + 1] = point(p.holder, "TOPLEFT")[5] end
    end
    h.eq(xs, { 0 }, "my buff alone, no gap")
  end)
end)
