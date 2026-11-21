local h = ...

local function load()
  return h.load({ "EditMode/Snap.lua" })
end

local SCREEN = { x = 0, y = 0, w = 1000, h = 800 }

h.test("snaps left edge to target within 8", function()
  local Snap = load().EditMode.Snap
  -- target spans 100..300; our left edge sits 5 px right of its left edge
  local target = { x = 100, y = 400, w = 200, h = 50 }
  local x, y = Snap.snap({ x = 105, y = 200, w = 60, h = 30 }, { target }, { threshold = 8 })
  h.eq(x, 100)
  h.eq(y, 200)
  -- our left edge 6 px past its right edge snaps onto it (frames side by side)
  x = Snap.snap({ x = 306, y = 200, w = 60, h = 30 }, { target }, { threshold = 8 })
  h.eq(x, 300)
end)

h.test("no snap beyond threshold", function()
  local Snap = load().EditMode.Snap
  local target = { x = 100, y = 400, w = 200, h = 50 }
  local x, y = Snap.snap({ x = 112, y = 200, w = 60, h = 30 }, { target }, { threshold = 8 })
  h.eq(x, 112)
  h.eq(y, 200)
  -- threshold defaults to 8
  x = Snap.snap({ x = 109, y = 200, w = 60, h = 30 }, { target }, {})
  h.eq(x, 109)
end)

h.test("grid snap when no target near", function()
  local Snap = load().EditMode.Snap
  local x, y = Snap.snap({ x = 137, y = 213, w = 60, h = 30 }, { SCREEN }, { grid = 20, threshold = 8 })
  h.eq(x, 140)
  h.eq(y, 220)
  -- a near target wins over the grid; the other axis still goes to the grid
  x, y = Snap.snap({ x = 3, y = 213, w = 60, h = 30 }, { SCREEN }, { grid = 20, threshold = 8 })
  h.eq(x, 0)
  h.eq(y, 220)
end)

h.test("centre line snap", function()
  local Snap = load().EditMode.Snap
  -- our centre (x + 30) 4 px left of the screen's centre line (500)
  local x, y = Snap.snap({ x = 466, y = 200, w = 60, h = 30 }, { SCREEN }, { threshold = 8 })
  h.eq(x, 470)
  h.eq(y, 200)
  -- vertical: our centre (y + 15) 3 px above the screen's centre line (400)
  x, y = Snap.snap({ x = 200, y = 388, w = 60, h = 30 }, { SCREEN }, { threshold = 8 })
  h.eq(x, 200)
  h.eq(y, 385)
end)

h.test("the nearest line wins", function()
  local Snap = load().EditMode.Snap
  -- right edge (166) is 2 px from target left (168); left edge (106) is 6 px from 100
  local a = { x = 100, y = 0, w = 1, h = 1 }
  local b = { x = 168, y = 0, w = 1, h = 1 }
  local x = Snap.snap({ x = 106, y = 300, w = 60, h = 30 }, { a, b }, { threshold = 8 })
  h.eq(x, 108)
end)
