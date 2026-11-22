local h = ...

local function load()
  local ns = h.load({ "Core/Util.lua", "Core/DB.lua", "Core/Modules.lua" })
  ns.db, ns.chardb = ns.DB.init(nil, nil)
  return ns
end

local function spec(extra)
  local s = { id = "a", label = "A", kind = "unit" }
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end

h.test("define rejects duplicate id", function()
  local ns = load()
  ns.Modules.define(spec())
  h.eq(pcall(ns.Modules.define, spec()), false)
end)

h.test("define rejects missing id, label and unknown kind", function()
  local ns = load()
  h.eq(pcall(ns.Modules.define, spec({ id = false })), false)
  h.eq(pcall(ns.Modules.define, spec({ label = false })), false)
  h.eq(pcall(ns.Modules.define, spec({ kind = "wat" })), false)
  h.eq(#ns.Modules.list(), 0)
end)

h.test("list keeps define order and get finds by id", function()
  local ns = load()
  ns.Modules.define(spec({ id = "b" }))
  ns.Modules.define(spec({ id = "a" }))
  h.eq(ns.Modules.list()[1].id, "b")
  h.eq(ns.Modules.list()[2].id, "a")
  h.eq(ns.Modules.get("a").id, "a")
  h.eq(ns.Modules.get("zz"), nil)
end)

h.test("isEnabled defaults to true and follows setEnabled", function()
  local ns = load()
  ns.Modules.define(spec())
  h.eq(ns.Modules.isEnabled("a"), true)
  ns.Modules.setEnabled("a", false)
  h.eq(ns.Modules.isEnabled("a"), false)
  h.eq(ns.DB.profile().modules.a.enabled, false)
end)

h.test("setEnabled needs reload only with blizzard list and created frame", function()
  local ns = load()
  ns.Modules.define(spec({ id = "p", blizzard = { "PlayerFrame" } }))
  ns.Modules.define(spec({ id = "q" }))
  h.eq(ns.Modules.setEnabled("p", false), false) -- no frame yet
  ns.Modules.get("p").frame = {}
  ns.Modules.get("q").frame = {}
  h.eq(ns.Modules.setEnabled("p", true), true)
  h.eq(ns.Modules.setEnabled("q", false), false) -- no blizzard list
end)

h.test("a child follows its parent", function()
  local ns = load()
  ns.Modules.define(spec({ id = "a" }))
  ns.Modules.define(spec({ id = "b", parent = "a" }))
  h.eq(ns.Modules.isEnabled("b"), true)
  ns.Modules.setEnabled("a", false)
  h.eq(ns.Modules.isEnabled("b"), false)
  ns.Modules.setEnabled("a", true)
  ns.Modules.setEnabled("b", false) -- its own flag counts too
  h.eq(ns.Modules.isEnabled("b"), false)
end)
