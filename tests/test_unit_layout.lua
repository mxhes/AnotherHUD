local h = ...

local function load()
  return h.load({ "Core/Util.lua", "Core/Locale.lua", "Locales/deDE.lua", "Core/Theme.lua",
    "Core/UnitLayout.lua" })
end

h.test("player 200x60 classic", function()
  local UL = load().UnitLayout
  local L = UL.frame({ w = 200, h = 60, powerH = 15, portraitScale = 100, mirror = false, edge = 4, badge = 18 })
  h.eq(L.w, 200)
  h.eq(L.h, 60)
  h.eq(L.ring.dia, 75)
  h.eq(L.ring.cx, 24)
  h.eq(L.ring.cy, 30)
  h.eq(L.bars.left, 63.5)
  h.eq(L.bars.right, 195)
  h.eq(L.health.top, 5)
  h.eq(L.power.bottom, 55)
  h.eq(L.power.top, 40)
  h.eq(L.health.bottom, 39)
  h.eq(L.badge.cx, 24 + 0.33 * 75)
  h.eq(L.below, 14)
  h.eq(L.studCorners[1], "TOPRIGHT")
  h.eq(L.powerText.size, 10)
  h.eq(L.ringStuds, true)
end)

h.test("target mirrored", function()
  local UL = load().UnitLayout
  local L = UL.frame({ w = 200, h = 60, powerH = 15, portraitScale = 100, mirror = true, edge = 4, badge = 18 })
  h.eq(L.ring.cx, 176)
  h.eq(L.bars.left, 5)
  h.eq(L.bars.right, 136.5)
  h.eq(L.studCorners[1], "TOPLEFT")
  h.eq(L.studCorners[2], "BOTTOMLEFT")
  h.eq(L.badge.cx, 176 - 0.33 * 75)
end)

h.test("tot has no power and no ring studs", function()
  local UL = load().UnitLayout
  local L = UL.frame({ w = 120, h = 26, powerH = 0, portraitScale = 100, mirror = false, edge = 4 })
  h.eq(L.power, nil)
  h.eq(L.health.bottom, 21)
  h.eq(L.ringStuds, false)
  h.eq(L.ring.dia, 33)
  h.eq(L.badge, nil)
  h.eq(L.powerText, nil)
end)

h.test("portrait scale 150", function()
  local UL = load().UnitLayout
  local L = UL.frame({ w = 200, h = 60, powerH = 15, portraitScale = 150, edge = 4 })
  h.eq(L.ring.dia, 113)
end)

h.test("party ring with role badge and crown", function()
  local UL = load().UnitLayout
  local L = UL.frame({ w = 160, h = 40, powerH = 5, portraitScale = 92, mirror = false, edge = 4, role = true })
  h.eq(L.ring.dia, 46)
  h.eq(L.ring.cx, 15)
  h.eq(L.role.size, 15)
  h.eq(L.role.cx, 15 - 0.33 * 46)
  h.eq(L.role.cy, 20 + 0.33 * 46)
  h.eq(L.crown.size, 12)
  h.eq(L.crown.cx, 15)
  h.eq(L.crown.top, 20 - 23 - 7)
  L = UL.frame({ w = 160, h = 40, powerH = 5, portraitScale = 92, mirror = true, edge = 4, role = true })
  h.eq(L.role.cx, 145 + 0.33 * 46)
  L = UL.frame({ w = 160, h = 40, powerH = 5, portraitScale = 92, edge = 4 })
  h.eq(L.role, nil)
  h.eq(L.crown, nil)
end)

h.test("aura rows", function()
  local UL = load().UnitLayout
  local perRow, shown = UL.auras(200, 22, 2, 2, 40)
  h.eq(perRow, 8)
  h.eq(shown, 16)
  perRow, shown = UL.auras(10, 22, 2, 1, 3)
  h.eq(perRow, 1)
  h.eq(shown, 1)
end)

h.test("edge width per border", function()
  local UL = load().UnitLayout
  h.eq(UL.edgeWidth("round"), 4)
  h.eq(UL.edgeWidth("thin"), 2)
  h.eq(UL.edgeWidth("gilded"), 6)
end)
