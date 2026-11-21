local ADDON, ns = ...

-- Saved state. Account (AnotherHUDDB):
--   profiles[name] = { modules = { [moduleId] = { ...settings } } }
--   positions[layoutName][moduleId] = { point, x, y }   (Edit Mode layouts)
--   lastLayout = layoutName   (last Edit Mode layout seen; positions are
--                              taken from it when LibEditMode is missing)
-- Character (AnotherHUDCharDB):
--   profile = "Default"                                  (active profile name)
-- DB.init works on the tables it is given and touches no globals; Boot
-- passes the saved variables and stores the result in ns.db / ns.chardb.
local DB = {}

DB.DEFAULT_PROFILE = "Default"

DB.defaults = {
  version = 1,
  profiles = {},
  positions = {},
}

DB.charDefaults = {
  profile = DB.DEFAULT_PROFILE,
}

local function newProfile()
  return { modules = {} }
end

-- Fills the saved tables with defaults (keeping what is there) and makes sure
-- the active profile exists. `saved` / `charSaved` may be nil (first run).
-- Returns db, chardb.
function DB.init(saved, charSaved)
  local db = ns.Util.merge(type(saved) == "table" and saved or {}, DB.defaults)
  local chardb = ns.Util.merge(type(charSaved) == "table" and charSaved or {}, DB.charDefaults)
  if type(chardb.profile) ~= "string" or chardb.profile == "" then
    chardb.profile = DB.DEFAULT_PROFILE
  end
  if type(db.profiles[DB.DEFAULT_PROFILE]) ~= "table" then
    db.profiles[DB.DEFAULT_PROFILE] = newProfile()
  end
  if type(db.profiles[chardb.profile]) ~= "table" then
    db.profiles[chardb.profile] = newProfile()
  end
  for _, profile in pairs(db.profiles) do
    if type(profile.modules) ~= "table" then profile.modules = {} end
  end
  return db, chardb
end

-- The active profile table (ns.db / ns.chardb, set by Boot after DB.init).
function DB.profile()
  return ns.db.profiles[ns.chardb.profile]
end

ns.DB = DB
