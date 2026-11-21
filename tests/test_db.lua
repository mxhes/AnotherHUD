local h = ...

local function load()
  return h.load({ "Core/Util.lua", "Core/DB.lua" })
end

h.test("init creates Default profile", function()
  local ns = load()
  local db, chardb = ns.DB.init(nil, nil)
  h.eq(chardb.profile, "Default")
  h.eq(type(db.profiles.Default.modules), "table")
  h.eq(type(db.positions), "table")
end)

h.test("init keeps existing values", function()
  local ns = load()
  local saved = { profiles = { Default = { modules = { player = { width = 250 } } } } }
  local db = ns.DB.init(saved, { profile = "Default" })
  h.eq(db.profiles.Default.modules.player.width, 250)
end)

h.test("init does not overwrite a chosen profile", function()
  local ns = load()
  local saved = { profiles = { Raid = { modules = {} } } }
  local _, chardb = ns.DB.init(saved, { profile = "Raid" })
  h.eq(chardb.profile, "Raid")
end)

h.test("profile returns the active profile and creates a missing one", function()
  local ns = load()
  local db, chardb = ns.DB.init(nil, { profile = "Gone" })
  ns.db, ns.chardb = db, chardb
  local p = ns.DB.profile()
  h.eq(type(p.modules), "table")
  h.eq(db.profiles.Gone, p)
end)

h.test("merge fills missing keys deeply and never overwrites", function()
  local ns = load()
  local dst = { a = 1, t = { x = 1 } }
  ns.Util.merge(dst, { a = 2, b = 3, t = { x = 9, y = 8 } })
  h.eq(dst, { a = 1, b = 3, t = { x = 1, y = 8 } })
end)

h.test("copy is deep", function()
  local ns = load()
  local src = { t = { x = 1 } }
  local c = ns.Util.copy(src)
  c.t.x = 2
  h.eq(src.t.x, 1)
end)
