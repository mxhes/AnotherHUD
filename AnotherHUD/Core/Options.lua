local ADDON, ns = ...

-- Module settings: values live in the active profile
-- (profile.modules[id][key]); the module's `defaults` fill the gaps.
local Options = {}

local function findControl(spec, key)
  for _, section in ipairs(spec.settings or {}) do
    for _, control in ipairs(section.controls or {}) do
      if control.key == key then return control end
    end
  end
end

local function allowed(control, value)
  for _, v in ipairs(control.values or {}) do
    if v == value then return true end
  end
  return false
end

-- A saved dropdown value that is no longer a choice (a removed skin such as
-- Gilded) reads as the default.
function Options.get(id, key)
  local saved = ns.DB.profile().modules[id]
  local spec = ns.Modules.get(id)
  if saved and saved[key] ~= nil then
    local control = spec and findControl(spec, key)
    if not (control and control.type == "dropdown" and not allowed(control, saved[key])) then
      return saved[key]
    end
  end
  return spec and spec.defaults and spec.defaults[key]
end

-- Rounds to the nearest step from min, then clamps to min..max.
local function normalizeSlider(control, value)
  if not ns.Util.isNumber(value) then return nil end
  local min, max, step = control.min, control.max, control.step
  if step and step > 0 and min then value = min + math.floor((value - min) / step + 0.5) * step end
  if min and max then value = ns.Util.clamp(value, min, max) end
  return value
end

-- Validates and stores a setting, then runs the module's apply. Returns
-- whether the value was accepted.
function Options.set(id, key, value)
  local spec = ns.Modules.get(id)
  if not spec then return false end
  local control = findControl(spec, key)
  if control and control.type == "slider" then
    value = normalizeSlider(control, value)
    if value == nil then return false end
  elseif control and control.type == "dropdown" then
    if not allowed(control, value) then return false end
  end
  local modules = ns.DB.profile().modules
  if type(modules[id]) ~= "table" then modules[id] = {} end
  modules[id][key] = value
  if spec.apply then
    ns.Combat.after("apply:" .. id, function() spec.apply(spec, key, value) end)
  end
  return true
end

-- Number of UTF-8 characters (not bytes) in `s`.
function Options.glyphs(s)
  local _, n = s:gsub("[^\128-\191]", "")
  return n
end

-- The module and control labels, translated through `L`, that are longer than
-- `max` glyphs (Edit Mode / options panels have room for 24).
function Options.longLabels(specs, L, max)
  local bad = {}
  local function check(label)
    if type(label) ~= "string" then return end
    local text = L[label]
    if Options.glyphs(text) > max then bad[#bad + 1] = text end
  end
  for _, spec in ipairs(specs) do
    check(spec.label)
    for _, section in ipairs(spec.settings or {}) do
      for _, control in ipairs(section.controls or {}) do check(control.label) end
    end
  end
  return bad
end

ns.Options = Options
