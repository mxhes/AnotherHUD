local h = ...

local function load()
  return h.load({ "Core/Util.lua", "Core/Theme.lua" })
end

h.test("theme has all four skins", function()
  local Theme = load().Theme
  for _, id in ipairs({ "classic", "forge", "slate", "gilded" }) do
    h.eq(type(Theme.skins[id]), "table", id)
    h.eq(Theme.skins[id].id, id)
  end
end)

h.test("every skin picks valid parts", function()
  local Theme = load().Theme
  for id, skin in pairs(Theme.skins) do
    for part, list in pairs(Theme.skinParts) do
      local found = false
      for _, v in ipairs(list) do if v == skin[part] then found = true end end
      h.eq(found, true, id .. "." .. part)
    end
  end
end)

h.test("textures point into the AnotherHUD folder", function()
  local Theme = load().Theme
  h.eq(Theme.textures.skinStud, "Interface\\AddOns\\AnotherHUD\\Media\\Skins\\Stud")
  h.eq(Theme.textures.skinDotted, "Interface\\AddOns\\AnotherHUD\\Media\\Skins\\Dotted")
end)

h.test("setStyle accepts known values only", function()
  local Theme = load().Theme
  h.eq(Theme.setStyle("border", "bevel"), true)
  h.eq(Theme.style.border, "bevel")
  h.eq(Theme.setStyle("border", "nope"), false)
  h.eq(Theme.setStyle("unknown", "x"), false)
  h.eq(Theme.style.border, "bevel")
end)

h.test("color helpers round-trip", function()
  local Theme = load().Theme
  local r, g, b = Theme.hexToRGB("#ff8000")
  h.near(r, 1)
  h.near(b, 0)
  h.eq(Theme.colorToHex({ r, g, b }), "ff8000")
  h.eq(Theme.hexToRGB("zz"), nil)
  h.eq(Theme.scaleColor({ 0.5, 0.5, 0.5, 0.3 }, 3)[1], 1)
end)

h.test("body text is readable on the panel", function()
  local Theme = load().Theme
  local c, p = Theme.colors.ink, Theme.colors.panelTint
  h.eq(Theme.contrast(c[1], c[2], c[3], p[1], p[2], p[3]) >= 7, true)
end)

h.test("snap distance lives in Theme.sizes", function()
  local Theme = load().Theme
  h.eq(Theme.sizes.snapDistance, 8)
  h.eq(Theme.sizes.gridSnapDistance, nil)
end)

h.test("bar color tint", function()
  local Theme = load().Theme
  local r, g, b = Theme.barColor({ 0.4, 0.8, 0.2 }, "Smooth")
  h.near(r, 0.5)
  h.near(g, 1)
  h.near(b, 0.25)
  r, g, b = Theme.barColor({ 0.4, 0.8, 0.2 }, "Flat")
  h.near(r, 0.4)
  h.near(g, 0.8)
  h.near(b, 0.2)
  r, g, b = Theme.barColor({ 0.4, 0.8, 0.2 }, "Nope")
  h.near(r, 0.5)
  h.near(g, 1)
  h.near(b, 0.25)
end)

h.test("every bar texture has a file and a tint", function()
  local Theme = load().Theme
  for _, name in ipairs({ "Smooth", "Flat", "Gloss" }) do
    local t = Theme.barTextures[name]
    h.eq(type(t), "table", name)
    h.eq(type(t.file), "string", name)
    h.eq(type(t.tint), "number", name)
  end
  h.eq(Theme.barTextures.Flat.file, "Interface\\Buttons\\WHITE8X8")
  h.near(Theme.barTextures.Smooth.tint, 1.25)
  h.near(Theme.barTextures.Gloss.tint, 1.05)
  for _, name in ipairs({ "disc", "spark", "shield" }) do
    h.eq(type(Theme.textures[name]), "string", name)
  end
  h.eq(Theme.sizes.unit.badge, 18)
  h.eq(Theme.sizes.unit.interruptHold, 0.6)
end)

h.test("unit art files exist on disk", function()
  for _, name in ipairs({ "Disc", "BarSmooth", "BarGloss", "Spark", "Shield" }) do
    local f = io.open("AnotherHUD/Media/Units/" .. name .. ".tga", "rb")
    h.eq(f ~= nil, true, name)
    if f then f:close() end
  end
end)
