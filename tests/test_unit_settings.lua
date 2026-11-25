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

h.test("the Resource Bar section has its five controls and defaults", function()
  local ns = load()
  local settings, defaults = ns.Units.Settings.build(
    { "Cast Bar", "Resource Bar", detach = true, resource = true }, {})
  h.eq(settings[1].section, "Cast Bar")
  h.eq(settings[2].section, "Resource Bar")
  local c = settings[2].controls
  local want = { "showResource", "resourceDetach", "resourceWidth", "resourceHeight", "resourceTimers" }
  h.eq(#c, #want)
  for i, key in ipairs(want) do h.eq(c[i].key, key) end
  h.eq({ c[1].type, c[2].type, c[3].type, c[4].type, c[5].type },
    { "checkbox", "checkbox", "slider", "slider", "checkbox" })
  h.eq({ c[1].label, c[2].label, c[3].label, c[4].label, c[5].label },
    { "Show resource bar", "Detach resource bar", "Resource bar width", "Resource bar height",
      "Show recharge timers" })
  h.eq(c[1].tooltip, "Show your class resource (combo points, holy power, runes, ...).")
  h.eq(c[2].tooltip, "Make the resource bar a separate frame you can move.")
  h.eq(c[3].tooltip, "Width of the resource bar when detached.")
  h.eq(c[4].tooltip, "Height of the resource bar when detached.")
  h.eq(c[5].tooltip, "Show the seconds left on recharging runes and essence.")
  h.eq({ c[3].min, c[3].max, c[3].step }, { 80, 400, 1 })
  h.eq({ c[4].min, c[4].max, c[4].step }, { 10, 40, 1 })
  h.eq({ defaults.showResource, defaults.resourceDetach, defaults.resourceWidth, defaults.resourceHeight,
    defaults.resourceTimers }, { true, false, 200, 20, true })
  for _, control in ipairs(c) do
    h.eq(ns.Options.glyphs(control.label) <= 24, true, control.label)
  end
  local plain, d2 = ns.Units.Settings.build({ "Cast Bar", "Resource Bar" }, {})
  h.eq(#plain[2].controls, 0, "no controls without the resource option")
  h.eq(d2.showResource, nil)
end)

h.test("German Resource Bar texts fit 24 glyphs", function()
  local ns = load("deDE")
  local settings = ns.Units.Settings.build({ "Resource Bar", resource = true }, {})
  h.eq(ns.L["Resource Bar"], "Ressourcenleiste")
  h.eq(ns.L["Player Resource Bar"], "Spielerressourcenleiste")
  for _, control in ipairs(settings[1].controls) do
    h.eq(ns.L[control.label] ~= control.label, true, control.label .. " translated")
    h.eq(ns.Options.glyphs(ns.L[control.label]) <= 24, true, ns.L[control.label])
    h.eq(ns.L[control.tooltip] ~= control.tooltip, true, control.tooltip .. " translated")
  end
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

local function controlsOf(settings)
  local list = {}
  for _, control in ipairs(settings[1].controls) do list[#list + 1] = control end
  return list
end

h.test("group section for party", function()
  local settings, defaults = load().Units.Settings.build({ "Group", orientation = true, roles = true }, {})
  h.eq(settings[1].section, "Group")
  local c = controlsOf(settings)
  local want = { "orientation", "growth", "gap", "sortByRole", "showPlayer" }
  h.eq(#c, #want)
  for i, key in ipairs(want) do h.eq(c[i].key, key) end
  h.eq(c[1].type, "dropdown")
  h.eq(c[1].label, "Orientation")
  h.eq(c[1].values[1], "Vertical")
  h.eq(c[1].values[2], "Horizontal")
  h.eq(c[1].tooltip, "Stack the frames on top of each other or side by side.")
  h.eq(c[2].label, "Growth")
  h.eq(c[2].values[1], "Down / Right")
  h.eq(c[2].values[2], "Up / Left")
  h.eq(c[2].tooltip, "Which way new frames are added.")
  h.eq(c[3].type, "slider")
  h.eq(c[3].label, "Frame gap")
  h.eq(c[3].min, 0)
  h.eq(c[3].max, 40)
  h.eq(c[3].step, 1)
  h.eq(c[3].tooltip, "Space between the frames.")
  h.eq(c[4].type, "checkbox")
  h.eq(c[4].label, "Sort by role")
  h.eq(c[4].tooltip, "Tanks first, then healers, then damage.")
  h.eq(c[5].label, "Show player")
  h.eq(c[5].tooltip, "Show your own frame in the group.")
  h.eq(defaults.orientation, "Vertical")
  h.eq(defaults.growth, "Down / Right")
  h.eq(defaults.gap, 8)
  h.eq(defaults.sortByRole, true)
  h.eq(defaults.showPlayer, true)
end)

h.test("group section for boss", function()
  local settings, defaults = load().Units.Settings.build({ "Group" }, {})
  local c = controlsOf(settings)
  h.eq(#c, 2)
  h.eq(c[1].key, "growth")
  h.eq(c[1].values[1], "Down")
  h.eq(c[1].values[2], "Up")
  h.eq(c[2].key, "gap")
  h.eq(defaults.growth, "Down")
  h.eq(defaults.gap, 8)
  h.eq(defaults.orientation, nil)
  h.eq(defaults.sortByRole, nil)
  h.eq(defaults.showPlayer, nil)
end)

h.test("German group labels fit 24 glyphs", function()
  local ns = load("deDE")
  local L, glyphs = ns.L, ns.Options.glyphs
  for _, parts in ipairs({ { "Group", orientation = true, roles = true }, { "Group" } }) do
    local settings = ns.Units.Settings.build(parts, {})
    local function check(x)
      h.eq(L[x] ~= x, true, x .. " translated")
      h.eq(glyphs(L[x]) <= 24, true, L[x])
    end
    check(settings[1].section)
    for _, control in ipairs(settings[1].controls) do
      check(control.label)
      h.eq(L[control.tooltip] ~= control.tooltip, true, control.tooltip .. " translated")
      for _, v in ipairs(control.values or {}) do check(v) end
    end
  end
end)

h.test("unit overrides only apply to keys a section produced", function()
  local _, defaults = load().Units.Settings.build({ "Size", power = false }, { powerHeight = 8, bogus = 1 })
  h.eq(defaults.powerHeight, nil)
  h.eq(defaults.bogus, nil)
end)

h.test("unknown section name raises", function()
  local S = load().Units.Settings
  local ok, err = pcall(S.build, { "Size", "Cast bar" }, {})
  h.eq(ok, false)
  h.eq(tostring(err):find("Cast bar", 1, true) ~= nil, true)
end)
