local ADDON, ns = ...

-- Start-up, called by Boot.lua on ADDON_LOADED: saved state first, then the
-- modules' frames and their Edit Mode registration, then (with LibEditMode
-- only) the checklist toggles.
local Core = {}

function Core.init()
  AnotherHUDDB, AnotherHUDCharDB = ns.DB.init(AnotherHUDDB, AnotherHUDCharDB)
  ns.db, ns.chardb = AnotherHUDDB, AnotherHUDCharDB
  local em = ns.EditMode
  em.Glue.registerAll()
  if em.Glue.lib() then
    if em.Checklist then em.Checklist.attach() end
  end
end

ns.Core = Core
