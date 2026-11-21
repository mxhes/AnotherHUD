local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  return h.load({ "Core/Combat.lua" })
end

h.test("runs now out of combat", function()
  local client = fakes.client{}
  local ns = load()
  local ran = 0
  ns.Combat.after("k", function() ran = ran + 1 end)
  h.eq(ran, 1)
  h.eq(ns.Combat.pending(), 0)
  client.restore()
end)

h.test("queues in combat and flushes on regen", function()
  local client = fakes.client{ inCombat = true }
  local ns = load()
  local order = {}
  ns.Combat.after("a", function() order[#order + 1] = "a" end)
  ns.Combat.after("b", function() order[#order + 1] = "b" end)
  h.eq(order, {})
  h.eq(ns.Combat.pending(), 2)
  client.setCombat(false)
  client.fire("PLAYER_REGEN_ENABLED")
  h.eq(order, { "a", "b" })
  h.eq(ns.Combat.pending(), 0)
  client.fire("PLAYER_REGEN_ENABLED")
  h.eq(order, { "a", "b" })
  client.restore()
end)

h.test("same key keeps only the last", function()
  local client = fakes.client{ inCombat = true }
  local ns = load()
  local order = {}
  ns.Combat.after("a", function() order[#order + 1] = "a1" end)
  ns.Combat.after("b", function() order[#order + 1] = "b" end)
  ns.Combat.after("a", function() order[#order + 1] = "a2" end)
  h.eq(ns.Combat.pending(), 2)
  client.setCombat(false)
  client.fire("PLAYER_REGEN_ENABLED")
  h.eq(order, { "a2", "b" })
  client.restore()
end)

h.test("an erroring function does not stop the flush", function()
  local client = fakes.client{ inCombat = true }
  local ns = load()
  local ran = false
  ns.Combat.after("a", function() error("boom") end)
  ns.Combat.after("b", function() ran = true end)
  client.setCombat(false)
  client.fire("PLAYER_REGEN_ENABLED")
  h.eq(ran, true)
  h.eq(ns.Combat.pending(), 0)
  client.restore()
end)

h.test("after during flush runs immediately", function()
  local client = fakes.client{ inCombat = true }
  local ns = load()
  local inner = false
  ns.Combat.after("a", function() ns.Combat.after("c", function() inner = true end) end)
  client.setCombat(false)
  client.fire("PLAYER_REGEN_ENABLED")
  h.eq(inner, true)
  h.eq(ns.Combat.pending(), 0)
  client.restore()
end)

h.test("without InCombatLockdown it runs now", function()
  local ns = load()
  local ran = false
  ns.Combat.after("k", function() ran = true end)
  h.eq(ran, true)
end)

h.test("options set in combat applies after combat", function()
  local client = fakes.client{ inCombat = true }
  local ns = h.load({ "Core/Util.lua", "Core/DB.lua", "Core/Modules.lua", "Core/Combat.lua", "Core/Options.lua" })
  ns.db, ns.chardb = ns.DB.init(nil, nil)
  local applied = {}
  ns.Modules.define{
    id = "m", label = "M", kind = "unit", defaults = { width = 200 },
    settings = { { section = "S", controls = { { key = "width", type = "slider", label = "W", min = 80, max = 400, step = 1 } } } },
    apply = function(spec, key, value) applied[#applied + 1] = value end,
  }
  h.eq(ns.Options.set("m", "width", 150), true)
  h.eq(ns.Options.get("m", "width"), 150)
  h.eq(applied, {})
  ns.Options.set("m", "width", 160)
  client.setCombat(false)
  client.fire("PLAYER_REGEN_ENABLED")
  h.eq(applied, { 160 })
  client.restore()
end)
