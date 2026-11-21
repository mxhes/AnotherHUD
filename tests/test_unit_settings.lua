local h = ...
local fakes = dofile("tests/fakes.lua")

local FILES = { "Core/Util.lua", "Core/Locale.lua", "Locales/deDE.lua", "Core/Theme.lua",
  "Core/UnitText.lua", "Core/Options.lua", "Units/Settings.lua" }

local function load(locale)
  local ns
  fakes.withGlobals({ GetLocale = function() return locale or "enUS" end }, function()
    ns = h.load(FILES)
  end)
  return ns
end

local ALL = { "Size", "Text", "Look", "Behaviour", "Cast Bar", "Auras", "Fading",
  portrait = true, power = true, detach = true }

local function keys(settings)
  local set = {}
  for _, section in ipairs(settings) do
    for _, control in ipairs(section.controls) do set[control.key] = control end
  end
  return set
end

h.test("sections in the order asked", function()
  local settings = load().Units.Settings.build({ "Size", "Fading" }, {})
  h.eq(#settings, 2)
  h.eq(settings[1].section, "Size")
  h.eq(settings[2].section, "Fading")
end)

h.test("portrait and power controls only when asked", function()
  local settings, defaults = load().Units.Settings.build({ "Size", portrait = false, power = false }, {})
  local set = keys(settings)
  h.eq(set.portraitScale, nil)
  h.eq(set.powerHeight, nil)
  h.eq(defaults.portraitScale, nil)
  h.eq(defaults.powerHeight, nil)
  h.eq(set.width ~= nil and set.height ~= nil, true)
end)

h.test("unit defaults override shared ones", function()
  local _, defaults = load().Units.Settings.build({ "Size", power = true }, { width = 160, powerHeight = 8 })
  h.eq(defaults.width, 160)
  h.eq(defaults.powerHeight, 8)
  h.eq(defaults.height, 60)
end)

h.test("every control has a default, label and tooltip", function()
  local settings, defaults = load().Units.Settings.build(ALL, {})
  local n = 0
  for _, section in ipairs(settings) do
    for _, control in ipairs(section.controls) do
      n = n + 1
      h.eq(defaults[control.key] ~= nil, true, control.key .. " default")
      h.eq(type(control.label), "string", control.key .. " label")
      h.eq(type(control.tooltip), "string", control.key .. " tooltip")
      h.eq(type(control.type), "string", control.key .. " type")
    end
  end
  h.eq(n >= 24, true)
  -- shared defaults from the brief
  h.eq(defaults.portraitScale, 100)
  h.eq(defaults.powerHeight, 15)
  h.eq(defaults.healthText, "Value")
  h.eq(defaults.powerText, "Percent")
  h.eq(defaults.skin, "Classic")
  h.eq(defaults.barTexture, "Smooth")
  h.eq(defaults.castDetach, false)
  h.eq(defaults.outOfCombat, 100)
  h.eq(defaults.onlyMine, false)
end)

h.test("gated controls are left out without their option", function()
  local settings, defaults = load().Units.Settings.build({ "Size", "Text", "Cast Bar" }, {})
  local set = keys(settings)
  h.eq(set.portraitScale, nil)
  h.eq(set.powerHeight, nil)
  h.eq(set.powerText, nil)
  h.eq(set.castDetach, nil)
  h.eq(defaults.castDetach, nil)
  h.eq(set.healthText ~= nil, true)
end)

h.test("fresh tables per call", function()
  local S = load().Units.Settings
  local s1, d1 = S.build({ "Size" }, {})
  local s2, d2 = S.build({ "Size" }, {})
  h.eq(s1 ~= s2 and d1 ~= d2 and s1[1] ~= s2[1] and s1[1].controls[1] ~= s2[1].controls[1], true)
  d1.width = 1
  h.eq(d2.width, 200)
end)

h.test("German labels fit 24 glyphs", function()
  local ns = load("deDE")
  local L, glyphs = ns.L, ns.Options.glyphs
  local settings = ns.Units.Settings.build(ALL, {})
  local function check(x)
    h.eq(L[x] ~= x, true, x .. " translated")
    h.eq(glyphs(L[x]) <= 24, true, L[x])
  end
  for _, section in ipairs(settings) do
    check(section.section)
    for _, control in ipairs(section.controls) do
      check(control.label)
      h.eq(L[control.tooltip] ~= control.tooltip, true, control.tooltip .. " translated")
      for _, v in ipairs(control.values or {}) do check(v) end
    end
  end
end)

h.test("English labels fit 24 glyphs", function()
  local ns = load()
  for _, section in ipairs(ns.Units.Settings.build(ALL, {})) do
    for _, control in ipairs(section.controls) do
      h.eq(ns.Options.glyphs(control.label) <= 24, true, control.label)
    end
  end
end)
