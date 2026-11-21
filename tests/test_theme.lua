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
