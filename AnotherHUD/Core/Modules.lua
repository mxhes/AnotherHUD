local ADDON, ns = ...

-- Module registry. Each module file calls ns.Modules.define(spec) at load:
--   spec = { id, label, kind = "unit"|"bar"|"misc", defaults, settings,
--            blizzard = { frame names to hide }, create, apply,
--            defaultPosition = { point, x, y },
--            parent = "<id>", onEditMode = function(spec, active) }
-- `parent`: a child module (e.g. a detached cast bar's holder): it is off
-- when its parent is off, and the Edit Mode checklist does not list it.
-- `onEditMode(spec, active)`: called by EditMode/Glue for every registered
-- module when Edit Mode opens (true) / closes (false), and once right after
-- a module registers while Edit Mode is already open.
-- `spec.frame` is set by the module's create path once its frame exists;
-- setEnabled uses it to tell whether a /reload is needed.
local Modules = {}

local KINDS = { unit = true, bar = true, misc = true }

local list = {}
local byId = {}

function Modules.define(spec)
  if type(spec) ~= "table" then error("Modules.define: spec must be a table", 2) end
  if type(spec.id) ~= "string" or spec.id == "" then error("Modules.define: missing id", 2) end
  if byId[spec.id] then error("Modules.define: duplicate id '" .. spec.id .. "'", 2) end
  if type(spec.label) ~= "string" or spec.label == "" then
    error("Modules.define: module '" .. spec.id .. "' has no label", 2)
  end
  if not KINDS[spec.kind] then
    error("Modules.define: module '" .. spec.id .. "' has unknown kind '" .. tostring(spec.kind) .. "'", 2)
  end
  list[#list + 1] = spec
  byId[spec.id] = spec
  return spec
end

-- The specs in define order.
function Modules.list()
  return list
end

function Modules.get(id)
  return byId[id]
end

-- Enabled unless the profile says otherwise.
function Modules.isEnabled(id)
  local spec = byId[id]
  -- A child follows its parent. An unknown parent id counts as enabled: only
  -- the child's own flag applies.
  local parent = spec and spec.parent and byId[spec.parent]
  if parent and not Modules.isEnabled(parent.id) then return false end
  local saved = ns.DB.profile().modules[id]
  return not (saved and saved.enabled == false)
end

-- Stores the flag. Returns true when the change needs /reload: the module
-- hides Blizzard frames and its own frame already exists this session.
function Modules.setEnabled(id, on)
  local modules = ns.DB.profile().modules
  if type(modules[id]) ~= "table" then modules[id] = {} end
  modules[id].enabled = on and true or false
  local spec = byId[id]
  return spec ~= nil and spec.blizzard ~= nil and spec.frame ~= nil
end

ns.Modules = Modules
