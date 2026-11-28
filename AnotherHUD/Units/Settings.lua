local ADDON, ns = ...

-- The settings sections the unit frame modules share. A module asks for the
-- sections it has:
--   settings, defaults = ns.Units.Settings.build(
--     { "Size", "Text", "Look", portrait = true, power = true }, { width = 160 })
-- The array part of `parts` is the sections in panel order; the hash part
-- switches on controls that only some frames have (portrait, power bar,
-- detachable cast bar). Texts are English keys, translated where drawn
-- (EditMode/Panel.lua). Pure data: no client calls.
ns.Units = ns.Units or {}
local Settings = {}

local function slider(key, label, tooltip, min, max, step)
  return { key = key, type = "slider", label = label, tooltip = tooltip, min = min, max = max, step = step }
end

local function checkbox(key, label, tooltip)
  return { key = key, type = "checkbox", label = label, tooltip = tooltip }
end

local function dropdown(key, label, tooltip, values)
  local copy = {}
  for i, v in ipairs(values) do copy[i] = v end
  return { key = key, type = "dropdown", label = label, tooltip = tooltip, values = copy }
end

-- Each builder returns the controls of one section (in panel order) and
-- writes the section's shared defaults into `d`.
local builders = {}

builders["Size"] = function(d, opts)
  d.width, d.height = 200, 60
  local controls = {
    slider("width", "Width", "Width of the frame.", 80, 400, 1),
    slider("height", "Height", "Height of the frame.", 20, 120, 1),
  }
  if opts.portrait then
    d.portraitScale = 100
    controls[#controls + 1] = slider("portraitScale", "Portrait scale",
      "Size of the portrait ring, in percent.", 50, 150, 5)
  end
  if opts.power then
    d.powerHeight = 15
    controls[#controls + 1] = slider("powerHeight", "Power bar height",
      "Height of the power bar.", 2, 40, 1)
  end
  return controls
end

builders["Text"] = function(d, opts)
  d.showName, d.healthText, d.fontSize = true, "Value", 11
  local controls = {
    checkbox("showName", "Show name", "Show the unit's name."),
    dropdown("healthText", "Health text", "What the health bar shows as text.", ns.UnitText.FORMATS),
  }
  if opts.power then
    d.powerText = "Percent"
    controls[#controls + 1] = dropdown("powerText", "Power text",
      "What the power bar shows as text.", ns.UnitText.FORMATS)
  end
  controls[#controls + 1] = slider("fontSize", "Text size", "Size of the texts on the frame.", 8, 20, 1)
  return controls
end

builders["Look"] = function(d)
  d.skin, d.classColor, d.barTexture = "Classic", true, "Smooth"
  return {
    dropdown("skin", "Skin", "Border and decoration style of the frame.",
      { "Classic", "Forge", "Slate" }),
    checkbox("classColor", "Class colors", "Color the health bar by class."),
    dropdown("barTexture", "Bar texture", "Look of the bar fill.", { "Smooth", "Flat", "Gloss" }),
  }
end

builders["Behaviour"] = function(d)
  d.showInVehicle = true
  return {
    checkbox("showInVehicle", "Show in vehicle", "Show the frame while in a vehicle."),
  }
end

builders["Cast Bar"] = function(d, opts)
  d.castBar, d.castWidth, d.castHeight, d.castIcon = true, 200, 18, true
  local controls = {
    checkbox("castBar", "Show cast bar", "Show a cast bar for this unit."),
    slider("castWidth", "Cast bar width", "Width of the cast bar.", 80, 400, 1),
    slider("castHeight", "Cast bar height", "Height of the cast bar.", 10, 40, 1),
    checkbox("castIcon", "Show spell icon", "Show the spell icon on the cast bar."),
  }
  if opts.detach then
    d.castDetach = false
    controls[#controls + 1] = checkbox("castDetach", "Detach cast bar",
      "Make the cast bar a separate frame you can move.")
  end
  return controls
end

-- The class resource bar (Bars/Resource.lua); only with `resource`.
builders["Resource Bar"] = function(d, opts)
  if not opts.resource then return {} end
  d.showResource, d.resourceDetach, d.resourceWidth, d.resourceHeight, d.resourceTimers =
    true, false, ns.Theme.sizes.resource.detachedWidth, ns.Theme.sizes.resource.detachedHeight, true
  return {
    checkbox("showResource", "Show resource bar",
      "Show your class resource (combo points, holy power, runes, ...)."),
    checkbox("resourceDetach", "Detach resource bar",
      "Make the resource bar a separate frame you can move."),
    slider("resourceWidth", "Resource bar width", "Width of the resource bar when detached.", 80, 400, 1),
    slider("resourceHeight", "Resource bar height", "Height of the resource bar when detached.", 10, 40, 1),
    checkbox("resourceTimers", "Show recharge timers",
      "Show the seconds left on recharging runes and essence."),
  }
end

builders["Auras"] = function(d)
  d.buffs, d.debuffs, d.auraSize, d.auraRows, d.onlyMine = true, true, 22, 1, false
  return {
    checkbox("buffs", "Show buffs", "Show the unit's buffs."),
    checkbox("debuffs", "Show debuffs", "Show the unit's debuffs."),
    slider("auraSize", "Aura size", "Size of the aura icons.", 14, 40, 1),
    slider("auraRows", "Aura rows", "Number of aura rows.", 1, 4, 1),
    checkbox("onlyMine", "Only my auras", "Show only auras you applied."),
  }
end

builders["Fading"] = function(d)
  d.outOfCombat, d.mouseover = 100, true
  return {
    slider("outOfCombat", "Out of combat opacity", "Opacity of the frame out of combat, in percent.",
      0, 100, 5),
    checkbox("mouseover", "Show on mouseover", "Show the frame fully while the mouse is over it."),
  }
end

builders["Group"] = function(d, opts)
  d.growth, d.gap = "Down", 8
  local controls = {}
  if opts.orientation then
    d.orientation, d.growth = "Vertical", "Down / Right"
    controls[#controls + 1] = dropdown("orientation", "Orientation",
      "Stack the frames on top of each other or side by side.", { "Vertical", "Horizontal" })
    controls[#controls + 1] = dropdown("growth", "Growth", "Which way new frames are added.",
      { "Down / Right", "Up / Left" })
  else
    controls[#controls + 1] = dropdown("growth", "Growth", "Which way new frames are added.",
      { "Down", "Up" })
  end
  controls[#controls + 1] = slider("gap", "Frame gap", "Space between the frames.", 0, 40, 1)
  if opts.roles then
    d.sortByRole, d.showPlayer = true, true
    controls[#controls + 1] = checkbox("sortByRole", "Sort by role",
      "Tanks first, then healers, then damage.")
    controls[#controls + 1] = checkbox("showPlayer", "Show player",
      "Show your own frame in the group.")
  end
  return controls
end

-- `parts`: section names in panel order plus the option fields `portrait`,
-- `power`, `detach`, `orientation`, `roles`, `resource`. `defaults`
-- overrides the shared defaults per unit.
-- Returns a fresh settings list and a fresh merged defaults table.
function Settings.build(parts, defaults)
  local opts = { portrait = parts.portrait, power = parts.power, detach = parts.detach,
    orientation = parts.orientation, roles = parts.roles, resource = parts.resource }
  local merged, settings = {}, {}
  for _, name in ipairs(parts) do
    local builder = builders[name]
    if not builder then error("Units.Settings.build: unknown section '" .. tostring(name) .. "'", 2) end
    settings[#settings + 1] = { section = name, controls = builder(merged, opts) }
  end
  for key, value in pairs(defaults or {}) do
    if merged[key] ~= nil then merged[key] = value end
  end
  return settings, merged
end

ns.Units.Settings = Settings
