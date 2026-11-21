local ADDON, ns = ...

-- Start-up, called by Boot.lua on ADDON_LOADED: saved state first, then the
-- modules' frames and their Edit Mode registration.
local Core = {}

function Core.init()
  AnotherHUDDB, AnotherHUDCharDB = ns.DB.init(AnotherHUDDB, AnotherHUDCharDB)
  ns.db, ns.chardb = AnotherHUDDB, AnotherHUDCharDB
  ns.EditMode.Glue.registerAll()
end

ns.Core = Core
