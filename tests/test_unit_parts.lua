local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  return h.load({ "Core/Util.lua", "Core/Locale.lua", "Locales/deDE.lua", "Core/Theme.lua",
    "Core/UnitLayout.lua", "Units/Settings.lua", "Units/Parts/Panel.lua", "Units/Parts/Ring.lua",
    "Units/Parts/Bars.lua" })
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
