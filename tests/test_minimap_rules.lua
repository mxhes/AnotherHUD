local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  return h.load({ "Core/Util.lua", "Core/Locale.lua", "Core/Theme.lua", "Core/MinimapRules.lua" })
end

h.test("clock text, 24 h and 12 h", function()
  local R = load().MinimapRules
  h.eq(R.clockText(14, 5, true), "14:05")
  h.eq(R.clockText(14, 5, false), "2:05 PM")
  h.eq(R.clockText(0, 0, false), "12:00 AM")
  h.eq(R.clockText(12, 0, false), "12:00 PM")
  h.eq(R.clockText(0, 7, true), "0:07")
  h.eq(R.clockText(nil, 5, true), "")
end)

h.test("coordinate text", function()
  local R = load().MinimapRules
  h.eq(R.coordText(0.421, 0.658), "42.1, 65.8")
  h.eq(R.coordText(0, 0), "")
  h.eq(R.coordText(nil, 0.5), "")
  fakes.withGlobals({ issecretvalue = fakes.isSecret }, function()
    h.eq(R.coordText(fakes.secret(0.4), 0.5), "")
  end)
end)

h.test("zone colors are copies with a fallback", function()
  local ns = load()
  local R = ns.MinimapRules
  h.eq(R.zoneColor("friendly"), { 0.10, 1.00, 0.10 })
  h.eq(R.zoneColor("nonsense"), ns.Theme.minimapZoneColors.normal)
  h.eq(R.zoneColor(nil), ns.Theme.minimapZoneColors.normal)
  local c = R.zoneColor("friendly")
  c[1] = 9
  h.eq(R.zoneColor("friendly"), { 0.10, 1.00, 0.10 })
end)

h.test("minimap mask follows the shape", function()
  local R = load().MinimapRules
  h.eq(R.mask("Square"), "Interface\\Buttons\\WHITE8x8")
  h.eq(R.mask("Round"), "ui-hud-minimap-frame-generic-mask")
  h.eq(R.mask(nil), "ui-hud-minimap-frame-generic-mask")
end)

h.test("shape name for GetMinimapShape", function()
  local R = load().MinimapRules
  h.eq(R.shapeName("Square"), "SQUARE")
  h.eq(R.shapeName("Round"), "ROUND")
  h.eq(R.shapeName(nil), "ROUND")
end)

h.test("wheel zoom stays in range", function()
  local R = load().MinimapRules
  h.eq(R.zoom(0, 1, 6), 1)
  h.eq(R.zoom(5, 1, 6), nil)
  h.eq(R.zoom(0, -1, 6), nil)
  h.eq(R.zoom(3, -1, 6), 2)
  h.eq(R.zoom(nil, 1, 6), nil)
  h.eq(R.zoom(1, 1, nil), nil)
  h.eq(R.zoom(1, 0, 6), nil)
end)
