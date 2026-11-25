local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  return h.load({ "Core/Util.lua", "Core/Theme.lua", "Core/UnitLayout.lua", "Core/Resource.lua" })
end

local function withSecrets(fn)
  fakes.withGlobals({ issecretvalue = fakes.isSecret }, fn)
end

h.test("forPlayer maps classes and specs to their resource", function()
  local R = load().Resource
  h.eq(R.forPlayer("ROGUE", 1).power, "ComboPoints")
  h.eq(R.forPlayer("DRUID", 2).form, "Energy")
  h.eq(R.forPlayer("ROGUE", 1).form, nil)
  h.eq(R.forPlayer("PALADIN", 3).mode, "points")
  h.eq(R.forPlayer("DEATHKNIGHT", 1).mode, "runes")
  h.eq(R.forPlayer("DEATHKNIGHT", 2).color, "runesFrost")
  h.eq(R.forPlayer("WARLOCK", 3).mode, "fragments")
  h.eq(R.forPlayer("MONK", 3).power, "Chi")
  h.eq(R.forPlayer("MONK", 1), nil)
  h.eq(R.forPlayer("MAGE", 1).power, "ArcaneCharges")
  h.eq(R.forPlayer("MAGE", 2), nil)
  h.eq(R.forPlayer("EVOKER", 2).mode, "essence")
  for _, c in ipairs({ "WARRIOR", "HUNTER", "PRIEST", "SHAMAN", "DEMONHUNTER" }) do h.eq(R.forPlayer(c, 1), nil, c) end
end)

h.test("forPlayer returns fallback counts and a fresh table", function()
  local R = load().Resource
  local want = { ROGUE = 5, PALADIN = 5, DEATHKNIGHT = 6, WARLOCK = 5, EVOKER = 5 }
  for class, n in pairs(want) do h.eq(R.forPlayer(class, 1).fallback, n, class) end
  h.eq(R.forPlayer("MONK", 3).fallback, 5)
  h.eq(R.forPlayer("MAGE", 1).fallback, 4)
  local a, b = R.forPlayer("ROGUE", 1), R.forPlayer("ROGUE", 1)
  a.power = "x"
  h.eq(b.power, "ComboPoints")
end)

h.test("active needs Cat Form for druids", function()
  local R = load().Resource
  local druid = R.forPlayer("DRUID", 2)
  h.eq(R.active(druid, "Energy"), true)
  h.eq(R.active(druid, "Mana"), false)
  h.eq(R.active(druid, "Rage"), false)
  h.eq(R.active(R.forPlayer("ROGUE", 1), "Energy"), true)
  h.eq(R.active(nil, "Energy"), false)
end)

h.test("runeColor follows the death knight spec", function()
  local R = load().Resource
  h.eq(R.runeColor(1), "runes"); h.eq(R.runeColor(2), "runesFrost")
  h.eq(R.runeColor(3), "runesUnholy"); h.eq(R.runeColor(nil), "runes")
end)

h.test("count falls back when max is unreadable", function()
  local R = load().Resource
  h.eq(R.count(6, 5), 6); h.eq(R.count(12, 5), 10)
  h.eq(R.count(0, 5), 5); h.eq(R.count(nil, 4), 4)
  withSecrets(function()
    h.eq(R.count(fakes.secret(6), 6), 6)
    h.eq(R.count(fakes.secret(3), 5), 5)
  end)
end)

h.test("runes sort ready first, then by time left", function()
  local R = load().Resource
  local out = R.runes({ { 10, 10, false }, { 0, 10, true }, { 14, 10, false }, {}, { 0, 10, true },
    { 12, 10, false } }, 16)
  h.eq(out[1], { fill = 1 }); h.eq(out[2], { fill = 1 })
  h.near(out[3].fill, 0.6); h.near(out[3].left, 4)
  h.near(out[4].left, 6); h.near(out[5].left, 8)
  h.eq(out[6], { fill = 0 })
end)

h.test("runes read named fields", function()
  local R = load().Resource
  local out = R.runes({ { start = 10, duration = 10, ready = false }, { ready = true } }, 15)
  h.eq(out[1], { fill = 1 })
  h.near(out[2].fill, 0.5); h.near(out[2].left, 5)
end)

h.test("essence gives the regenerating segment", function()
  local R = load().Resource
  local e = R.essence(3, 5, 550, 0.2)
  h.eq(e.index, 4); h.near(e.fill, 0.55); h.near(e.left, 2.25)
  h.eq(R.essence(5, 5, 0, 0.2), nil)
  h.eq(R.essence(3, 5, 550, 0).left, nil)
  withSecrets(function()
    h.eq(R.essence(3, 5, fakes.secret(550), 0.2), nil)
    h.eq(R.essence(fakes.secret(3), 5, 550, 0.2), nil)
  end)
end)

h.test("timerText rounds up whole seconds", function()
  local R = load().Resource
  h.eq(R.timerText(2.25), "3"); h.eq(R.timerText(0), ""); h.eq(R.timerText(nil), "")
  h.eq(R.timerText(9.0), "9"); h.eq(R.timerText(-1), ""); h.eq(R.timerText(false), "")
  withSecrets(function() h.eq(R.timerText(fakes.secret(4)), "") end)
end)

h.test("attached spans the health / power column", function()
  local ns = load()
  local L = ns.UnitLayout.frame({ w = 200, h = 60, powerH = 15, edge = 1 })
  h.eq(ns.Resource.attached(L), { x = 64, w = 136, h = 18 })
  h.eq(ns.Resource.reserve(18), 26)
end)

h.test("theme carries the approved resource colors", function()
  local T = load().Theme
  local want = {
    combo = { 0.95, 0.35, 0.2 }, holy = { 1, 0.82, 0.25 }, runes = { 0.85, 0.2, 0.25 },
    runesFrost = { 0.3, 0.7, 1 }, runesUnholy = { 0.4, 0.85, 0.3 }, shards = { 0.62, 0.35, 0.95 },
    chi = { 0.45, 0.95, 0.75 }, arcane = { 0.45, 0.55, 1 }, essence = { 0.35, 0.85, 0.8 },
  }
  for key, c in pairs(want) do h.eq(T.resourceColors[key], c, key) end
  h.eq(T.sizes.resource, { attachedHeight = 18, gap = 4, detachedWidth = 200, detachedHeight = 20,
    partialShade = 0.55, timerFont = 9, maxSegments = 10, tick = 0.1 })
end)
