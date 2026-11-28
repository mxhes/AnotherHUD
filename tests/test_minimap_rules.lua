local h = ...

local function load()
  return h.load({ "Core/Util.lua", "Core/MinimapRules.lua" })
end

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
