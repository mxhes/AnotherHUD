local h = ...

-- LibEditMode's SettingType with and without the Divider row type.
local TYPES = { Dropdown = 0, Checkbox = 1, Slider = 2, ColorPicker = 10, Divider = "divider" }
local BASIC = { Dropdown = 0, Checkbox = 1, Slider = 2, ColorPicker = 10 }

local function load()
  local ns = h.load({ "Core/Util.lua", "Core/DB.lua", "Core/Modules.lua", "Core/Combat.lua",
    "Core/Options.lua", "EditMode/Panel.lua" })
  ns.db, ns.chardb = ns.DB.init(nil, nil)
  local spec = ns.Modules.define{
    id = "m", label = "M", kind = "unit",
    defaults = { width = 200, mode = "a", on = true, tint = { 1, 0, 0, 1 } },
    settings = {
      { section = "Size", controls = {
        { key = "width", type = "slider", label = "Width", tooltip = "How wide", min = 80, max = 400, step = 1 },
        { key = "mode", type = "dropdown", label = "Mode", values = { "a", "b" } },
      } },
      { section = "Look", controls = {
        { key = "on", type = "checkbox", label = "Show" },
        { key = "tint", type = "color", label = "Tint" },
      } },
    },
  }
  return ns, spec
end

local function find(settings, name)
  for _, s in ipairs(settings) do
    if s.name == name then return s end
  end
end

h.test("slider maps min/max/step", function()
  local ns, spec = load()
  local settings = ns.EditMode.Panel.build(spec, TYPES)
  local s = find(settings, "Width")
  h.eq(s.kind, TYPES.Slider)
  h.eq(s.minValue, 80)
  h.eq(s.maxValue, 400)
  h.eq(s.valueStep, 1)
  h.eq(s.default, 200)
  h.eq(s.desc, "How wide")
  h.eq(s.get("Modern"), 200)
  local d = find(settings, "Mode")
  h.eq(d.kind, TYPES.Dropdown)
  h.eq(d.values, { { text = "a", value = "a" }, { text = "b", value = "b" } })
  h.eq(find(settings, "Show").kind, TYPES.Checkbox)
  h.eq(find(settings, "Tint").kind, TYPES.ColorPicker)
end)

h.test("colour opacity from the control or the default alpha", function()
  local ns, spec = load()
  h.eq(find(ns.EditMode.Panel.build(spec, TYPES), "Tint").hasOpacity, false)
  spec.settings[2].controls[2].hasOpacity = true
  h.eq(find(ns.EditMode.Panel.build(spec, TYPES), "Tint").hasOpacity, true)
  spec.settings[2].controls[2].hasOpacity = nil
  spec.defaults.tint = { 1, 0, 0, 0.5 }
  h.eq(find(ns.EditMode.Panel.build(spec, TYPES), "Tint").hasOpacity, true)
end)

h.test("one header per section", function()
  local ns, spec = load()
  local settings = ns.EditMode.Panel.build(spec, TYPES)
  h.eq(#settings, 6)
  h.eq(settings[1].kind, TYPES.Divider)
  h.eq(settings[1].name, "Size")
  h.eq(settings[4].kind, TYPES.Divider)
  h.eq(settings[4].name, "Look")
  -- without a Divider type: a disabled line carrying the section name
  local plain = ns.EditMode.Panel.build(spec, BASIC)
  h.eq(#plain, 6)
  h.eq(plain[1].name, "Size")
  h.eq(plain[1].disabled, true)
  h.eq(plain[4].name, "Look")
  h.eq(plain[4].disabled, true)
  local headers = 0
  for _, s in ipairs(plain) do if s.disabled then headers = headers + 1 end end
  h.eq(headers, 2)
end)

h.test("header rows take get and set (library Reset Settings)", function()
  local ns, spec = load()
  for _, types in ipairs({ TYPES, BASIC, { Expander = "expander", Slider = 2 } }) do
    local headers = 0
    for _, s in ipairs(ns.EditMode.Panel.build(spec, types)) do
      if s.name == "Size" or s.name == "Look" then
        headers = headers + 1
        h.eq(type(s.get), "function", s.name)
        h.eq(type(s.set), "function", s.name)
        s.set("Modern", s.default, true)
        s.get("Modern")
      end
    end
    h.eq(headers, 2)
  end
end)

h.test("set writes through Options.set", function()
  local ns, spec = load()
  local applied = {}
  spec.apply = function(_, key, value) applied[#applied + 1] = { key, value } end
  local settings = ns.EditMode.Panel.build(spec, TYPES)
  find(settings, "Width").set("Modern", 500, false)
  h.eq(ns.Options.get("m", "width"), 400) -- clamped by Options.set
  h.eq(find(settings, "Width").get("Modern"), 400)
  h.eq(applied, { { "width", 400 } })
  find(settings, "Mode").set("Modern", "zzz")
  h.eq(ns.Options.get("m", "mode"), "a")
  find(settings, "Show").set("Modern", false)
  h.eq(ns.Options.get("m", "on"), false)
end)

h.test("color goes through rgba tables", function()
  local ns, spec = load()
  local settings = ns.EditMode.Panel.build(spec, TYPES)
  local c = find(settings, "Tint")
  -- outside the client (no CreateColor) the value is the plain table
  h.eq(c.get("Modern"), { 1, 0, 0, 1 })
  local mixin = { GetRGBA = function() return 0, 0.5, 1, 0.8 end }
  c.set("Modern", mixin)
  h.eq(ns.Options.get("m", "tint"), { 0, 0.5, 1, 0.8 })
end)

h.test("no header row type at all still builds", function()
  local ns, spec = load()
  local settings = ns.EditMode.Panel.build(spec, { Slider = 2 })
  -- only the slider has a row type; headers fall back to nothing usable
  h.eq(find(settings, "Width").kind, 2)
  h.eq(find(settings, "Mode"), nil)
end)
