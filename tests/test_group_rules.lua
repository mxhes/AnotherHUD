local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  return h.load({ "Core/Util.lua", "Core/Locale.lua", "Locales/deDE.lua", "Core/Theme.lua",
    "Core/GroupLayout.lua" })
end

local function withSecrets(fn)
  fakes.withGlobals({ issecretvalue = fakes.isSecret }, fn)
end

local function slots(roles, missing)
  local list = {}
  for i = 1, #roles do
    list[i] = { index = i - 1, unit = i == 1 and "player" or ("party" .. (i - 1)),
      role = roles[i], exists = not (missing and missing[i - 1]) }
  end
  return list
end

h.test("order: existing first, player dropped", function()
  local GL = load().GroupLayout
  local list = slots({ "NONE", "NONE", "NONE", "NONE", "NONE" }, { [3] = true })
  local order = GL.order(list, { sortByRole = false, showPlayer = false })
  h.eq(#order, 4)
  h.eq(order[1], 1); h.eq(order[2], 2); h.eq(order[3], 4); h.eq(order[4], 3)
end)

h.test("order by role with ties by index", function()
  local GL = load().GroupLayout
  local list = slots({ "DAMAGER", "TANK", "NONE", "HEALER", "DAMAGER" })
  local order = GL.order(list, { sortByRole = true, showPlayer = true })
  local want = { 1, 3, 0, 4, 2 }
  h.eq(#order, 5)
  for i = 1, 5 do h.eq(order[i], want[i]) end
end)

h.test("order: secret role and secret exists", function()
  withSecrets(function()
    local GL = load().GroupLayout
    local list = slots({ "HEALER", fakes.secret(1), "TANK", "DAMAGER" })
    list[4].exists = fakes.secret(2)
    local order = GL.order(list, { sortByRole = true, showPlayer = true })
    -- TANK(2), HEALER(0), DAMAGER(3, secret exists counts), NONE(1)
    local want = { 2, 0, 3, 1 }
    h.eq(#order, 4)
    for i = 1, 4 do h.eq(order[i], want[i]) end
  end)
end)

h.test("offsets: four directions and sizes", function()
  local GL = load().GroupLayout
  local function fifth(o)
    o.w, o.h, o.gap = 160, 40, 8
    local list, w, hh = GL.offsets(5, o)
    return list[5], w, hh
  end
  local e, w, hh = fifth({ orientation = "Vertical", growth = "Down" })
  h.eq(e.point, "TOPLEFT"); h.eq(e.x, 0); h.eq(e.y, -192)
  h.eq(w, 160); h.eq(hh, 232)
  e = fifth({ orientation = "Vertical", growth = "Up" })
  h.eq(e.point, "BOTTOMLEFT"); h.eq(e.x, 0); h.eq(e.y, 192)
  e, w, hh = fifth({ orientation = "Horizontal", growth = "Down / Right" })
  h.eq(e.point, "TOPLEFT"); h.eq(e.x, 672); h.eq(e.y, 0)
  h.eq(w, 832); h.eq(hh, 40)
  e = fifth({ orientation = "Horizontal", growth = "Up / Left" })
  h.eq(e.point, "TOPRIGHT"); h.eq(e.x, -672); h.eq(e.y, 0)
  local _
  _, w, hh = GL.offsets(0, { orientation = "Vertical", growth = "Down", w = 160, h = 40, gap = 8 })
  h.eq(w, 160); h.eq(hh, 40)
end)

h.test("boss blocks are 74 apart", function()
  local GL = load().GroupLayout
  local list = GL.offsets(2, { orientation = "Vertical", growth = "Down", w = 180, h = 42 + 4 + 16, gap = 12 })
  h.eq(list[2].y, -74)
end)

h.test("party holder visibility hides in raids and solo", function()
  local GL = load().GroupLayout
  h.eq(GL.partyVisibility(),
    "[petbattle] hide; [group:raid] hide; [@raid1,exists] hide; [@party1,exists] show; hide")
end)

h.test("boss visibility", function()
  local GL = load().GroupLayout
  h.eq(GL.bossVisibility(), "[petbattle] hide; show")
  h.eq(GL.ROLES[1], "TANK"); h.eq(GL.ROLES[2], "HEALER"); h.eq(GL.ROLES[3], "DAMAGER")
end)
