local ADDON, ns = ...

-- Builds a module's Edit Mode panel: turns its `settings` sections into
-- LibEditMode setting tables. Pure except that colors become ColorMixins
-- (CreateColor, looked up at call time) when the client has them.
ns.EditMode = ns.EditMode or {}
local Panel = {}

local L = ns.L

-- Stored colors are { r, g, b, a }; LibEditMode's color picker wants a
-- ColorMixin and hands one back.
local function toColor(v)
  if type(v) ~= "table" then return v end
  if CreateColor then return CreateColor(v[1], v[2], v[3], v[4] or 1) end
  return v
end

local function fromColor(c)
  if type(c) == "table" and type(c.GetRGBA) == "function" then
    local r, g, b, a = c:GetRGBA()
    return { r, g, b, a }
  end
  return c
end

local function dropdownValues(control)
  local out = {}
  for _, v in ipairs(control.values or {}) do
    out[#out + 1] = { text = L[tostring(v)], value = v }
  end
  return out
end

local KIND = { slider = "Slider", dropdown = "Dropdown", checkbox = "Checkbox", color = "ColorPicker" }

local function setting(spec, control, types)
  local kind = KIND[control.type] and types[KIND[control.type]]
  if kind == nil or type(control.key) ~= "string" then return nil end
  local id, key = spec.id, control.key
  local isColor = control.type == "color"
  local default = spec.defaults and spec.defaults[key]
  local s = {
    name = L[control.label or key],
    desc = control.tooltip and L[control.tooltip] or nil,
    kind = kind,
    default = isColor and toColor(default) or default,
    get = function(layoutName)
      local v = ns.Options.get(id, key)
      if isColor then return toColor(v) end
      return v
    end,
    set = function(layoutName, value)
      if isColor then value = fromColor(value) end
      ns.Options.set(id, key, value)
    end,
  }
  if control.type == "slider" then
    s.minValue, s.maxValue, s.valueStep = control.min, control.max, control.step
  elseif control.type == "dropdown" then
    s.values = dropdownValues(control)
  elseif isColor then
    local alpha = type(default) == "table" and default[4]
    s.hasOpacity = control.hasOpacity == true or (type(alpha) == "number" and alpha < 1)
  end
  return s
end

-- The section title row: the library's Divider when it has one, else an
-- open Expander (its state lives here, for this panel only), else a
-- disabled checkbox line carrying the name. Every header has a get / set
-- (no-op where nothing is stored), so a library Reset Settings that calls
-- set on every row cannot error.
local function header(name, types)
  if types.Divider ~= nil then
    return { name = name, kind = types.Divider,
      get = function() return nil end, set = function() end }
  end
  if types.Expander ~= nil then
    local open = true
    return { name = name, kind = types.Expander, default = true,
      get = function() return open end, set = function(_, v) open = v and true or false end }
  end
  if types.Checkbox ~= nil then
    return { name = name, kind = types.Checkbox, default = false, disabled = true,
      get = function() return false end, set = function() end }
  end
end

-- `types` is the library's SettingType table. Controls whose type the
-- library lacks are left out.
function Panel.build(spec, types)
  types = types or {}
  local out = {}
  for _, section in ipairs(spec.settings or {}) do
    local title = type(section.section) == "string" and header(L[section.section], types)
    if title then out[#out + 1] = title end
    for _, control in ipairs(section.controls or {}) do
      local s = setting(spec, control, types)
      if s then out[#out + 1] = s end
    end
  end
  return out
end

ns.EditMode.Panel = Panel
