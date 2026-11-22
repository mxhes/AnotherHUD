local ADDON, ns = ...

-- The shape every unit frame module shares, so each unit file is one call:
--   ns.Units.define{ id, label, unit, name (global frame name), mirror,
--     castBar, auras, badge, parts (Units.Settings.build), defaults
--     (overrides), blizzard, defaultPosition, apply (optional, replaces
--     Base.apply) }
-- It builds the settings, then ns.Modules.define{ kind = "unit", ... }:
-- create -> Base.create + apply + Base.hideBlizzard, apply -> Base.apply,
-- onEditMode -> Base.editMode. Returns the spec.
ns.Units = ns.Units or {}

function ns.Units.define(o)
  local Base = ns.Units.Base
  local settings, defaults = ns.Units.Settings.build(o.parts, o.defaults)
  local apply = o.apply or function(spec) Base.apply(spec) end
  return ns.Modules.define({
    id = o.id, label = o.label, kind = "unit",
    defaults = defaults, settings = settings,
    blizzard = o.blizzard, defaultPosition = o.defaultPosition,
    create = function(spec)
      Base.create(spec, { unit = o.unit, name = o.name, mirror = o.mirror,
        castBar = o.castBar, auras = o.auras, badge = o.badge })
      apply(spec)
      Base.hideBlizzard(spec.blizzard or {})
    end,
    apply = function(spec) apply(spec) end,
    onEditMode = function(spec, active) Base.editMode(spec, active) end,
  })
end
