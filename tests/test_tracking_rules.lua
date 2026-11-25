local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  return h.load({ "Core/Util.lua", "Core/Theme.lua", "Core/Tracking.lua" })
end

local function withSecrets(fn)
  fakes.withGlobals({ issecretvalue = fakes.isSecret }, fn)
end

h.test("xp hides at max level and when turned off", function()
  local T = load().Tracking
  h.eq(T.xp({ xp = 1, max = 10, atMax = true }), nil)
  h.eq(T.xp({ xp = 1, max = 10, disabled = true }), nil)
end)

h.test("xp gives range, rested end and text", function()
  local T = load().Tracking
  local r = T.xp({ xp = 12345, max = 50000, rested = 3000, level = 42 })
  h.eq(r.value, 12345); h.eq(r.max, 50000); h.eq(r.restedEnd, 15345)
  h.eq(r.text, "Level 42  12,345 / 50,000 (24%)  +3,000 rested")
  h.eq(T.xp({ xp = 49000, max = 50000, rested = 3000, level = 42 }).restedEnd, 50000)
  local none = T.xp({ xp = 12345, max = 50000, rested = 0, level = 42 })
  h.eq(none.restedEnd, nil)
  h.eq(none.text, "Level 42  12,345 / 50,000 (24%)")
  h.eq(T.xp({ xp = 12345, max = 50000, level = 42 }).restedEnd, nil)
end)

h.test("xp with a zero maximum has no percent", function()
  local T = load().Tracking
  local r = T.xp({ xp = 0, max = 0, rested = 100, level = 1 })
  h.eq(r.text, nil); h.eq(r.restedEnd, nil)
  h.eq(T.xpText(1, 0, 0, 0), "Level 1  0 / 0")
end)

h.test("secret xp passes through without text", function()
  local T = load().Tracking
  withSecrets(function()
    local s = fakes.secret(500)
    local r = T.xp({ xp = s, max = 1000, rested = 100, level = 3 })
    h.eq(r.value, s); h.eq(r.max, 1000); h.eq(r.text, nil); h.eq(r.restedEnd, nil)
    local r2 = T.xp({ xp = 500, max = fakes.secret(1000), rested = 100, level = 3 })
    h.eq(r2.text, nil); h.eq(r2.restedEnd, nil)
  end)
end)

h.test("reputation reads both client shapes", function()
  local T = load().Tracking
  local modern = T.reputation({ name = "Argent Dawn", reaction = 5, currentReactionThreshold = 3000,
    nextReactionThreshold = 9000, currentStanding = 4200 })
  local legacy = T.reputation({ legacy = { name = "Argent Dawn", reaction = 5, min = 3000, max = 9000, value = 4200 } })
  for _, r in ipairs({ modern, legacy }) do
    h.eq(r.name, "Argent Dawn"); h.eq(r.min, 3000); h.eq(r.max, 9000); h.eq(r.value, 4200)
    h.eq(r.reaction, 5)
    h.eq(r.text, "Argent Dawn  Friendly  1,200 / 6,000")
  end
end)

h.test("reputation at the top of a standing shows full", function()
  local T = load().Tracking
  local r = T.reputation({ name = "Argent Dawn", reaction = 8, currentReactionThreshold = 42000,
    nextReactionThreshold = 42000, currentStanding = 42000 })
  h.eq(r.min, 0); h.eq(r.max, 1); h.eq(r.value, 1)
  h.eq(r.text, "Argent Dawn  Exalted")
end)

h.test("reputation passes secret values through without text", function()
  local T = load().Tracking
  withSecrets(function()
    local s = fakes.secret(4200)
    local r = T.reputation({ name = "Argent Dawn", reaction = 5, currentReactionThreshold = 3000,
      nextReactionThreshold = 9000, currentStanding = s })
    h.eq(r.value, s); h.eq(r.text, nil)
  end)
end)

h.test("no watched faction gives nil", function()
  local T = load().Tracking
  h.eq(T.reputation(nil), nil)
  h.eq(T.reputation({}), nil)
  h.eq(T.reputation({ name = "", reaction = 4 }), nil)
  withSecrets(function()
    h.eq(T.reputation({ name = fakes.secret("Argent Dawn"), reaction = 4 }), nil)
  end)
end)

h.test("standing names the eight reactions", function()
  local T = load().Tracking
  local want = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
  for i, name in ipairs(want) do h.eq(T.standing(i), name) end
  h.eq(T.standing(0), ""); h.eq(T.standing(9), ""); h.eq(T.standing(nil), "")
end)

h.test("reactionColor falls back to the theme", function()
  local ns = load()
  local T = ns.Tracking
  h.eq(T.reactionColor(5), ns.Theme.trackingColors.reaction[5])
  h.eq(T.reactionColor(99), ns.Theme.trackingColors.reaction[4])
  h.eq(T.reactionColor(nil), ns.Theme.trackingColors.reaction[4])
  fakes.withGlobals({ FACTION_BAR_COLORS = { [5] = { r = 1, g = 2, b = 3 } } }, function()
    h.eq(T.reactionColor(5), { 1, 2, 3 })
    h.eq(T.reactionColor(99), ns.Theme.trackingColors.reaction[4])
  end)
end)

h.test("xp percent rounds down", function()
  local T = load().Tracking
  h.eq(T.xpText(5, 29, 100, 0), "Level 5  29 / 100 (29%)")
  h.eq(T.xp({ xp = 29, max = 100, level = 5 }).text, "Level 5  29 / 100 (29%)")
  h.eq(T.xpText(5, 999, 1000, 0), "Level 5  999 / 1,000 (99%)")
end)

h.test("reactionColor fallback is a copy", function()
  local ns = load()
  local T = ns.Tracking
  local c = T.reactionColor(5)
  c[1] = 42
  h.eq(ns.Theme.trackingColors.reaction[5], { 0, 0.6, 0.1 })
  local n = T.reactionColor(nil)
  n[2] = 42
  h.eq(ns.Theme.trackingColors.reaction[4], { 0.9, 0.7, 0 })
end)

h.test("number separates thousands", function()
  local T = load().Tracking
  h.eq(T.number(0), "0"); h.eq(T.number(999), "999"); h.eq(T.number(1000), "1,000")
  h.eq(T.number(1234567), "1,234,567"); h.eq(T.number(-12345), "-12,345")
end)

h.test("theme carries the tracking colors and sizes", function()
  local T = load().Theme
  h.eq(T.trackingColors.xp, { 0.58, 0, 0.55 })
  h.eq(T.trackingColors.rested, { 0, 0.39, 0.88 })
  h.eq(T.trackingColors.reaction[3], { 0.75, 0.27, 0 })
  h.eq(T.sizes.tracking, { width = 500, height = 10, gap = 1, restedAlpha = 0.4, textFont = 10 })
end)
