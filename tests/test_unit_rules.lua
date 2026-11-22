local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  return h.load({ "Core/Util.lua", "Core/Locale.lua", "Locales/deDE.lua", "Core/Theme.lua",
    "Core/UnitText.lua", "Core/UnitColor.lua", "Core/UnitState.lua" })
end

-- Runs fn with the client's secret check installed.
local function withSecrets(fn, extra)
  local g = { issecretvalue = fakes.isSecret }
  for k, v in pairs(extra or {}) do g[k] = v end
  fakes.withGlobals(g, fn)
end

h.test("bar text passes secrets through", function()
  withSecrets(function()
    local UnitText = load().UnitText
    local cur, max, pct = fakes.secret(1), fakes.secret(2), fakes.secret(3)
    local function abbr(v) return { wrapped = v } end
    local src = { cur = cur, max = max, pct = pct }

    local fmt, args = UnitText.bar("Percent", src, abbr)
    h.eq(fmt, "%.0f%%")
    h.eq(#args, 1)
    h.eq(rawequal(args[1], pct), true)

    fmt, args = UnitText.bar("Value", src, abbr)
    h.eq(fmt, "%s / %s")
    h.eq(rawequal(args[1].wrapped, cur), true)
    h.eq(rawequal(args[2].wrapped, max), true)

    fmt, args = UnitText.bar("Value + Percent", src, abbr)
    h.eq(fmt, "%s | %.0f%%")
    h.eq(rawequal(args[1].wrapped, cur), true)
    h.eq(rawequal(args[2], pct), true)
  end)
end)

h.test("bar text: dead and offline win, None stays empty", function()
  withSecrets(function()
    local UnitText = load().UnitText
    local function abbr(v) return v end
    local fmt, args = UnitText.bar("Percent", { dead = true, pct = 50 }, abbr)
    h.eq(fmt, "|cffbbbbbb%s|r")
    h.eq(args[1], "Dead")
    fmt, args = UnitText.bar("Value", { offline = true, cur = 1, max = 2 }, abbr)
    h.eq(fmt, "|cffbbbbbb%s|r")
    h.eq(args[1], "Offline")
    fmt, args = UnitText.bar("None", { dead = true }, abbr)
    h.eq(fmt, "")
    h.eq(#args, 0)
    fmt, args = UnitText.bar("None", {}, abbr)
    h.eq(fmt, "")
    h.eq(#args, 0)
    h.eq(UnitText.FORMATS[1], "None")
    h.eq(#UnitText.FORMATS, 4)
  end)
end)

h.test("level: secret, skull, number", function()
  withSecrets(function()
    local UnitText = load().UnitText
    local s = fakes.secret(1)
    local fmt, args = UnitText.level(s)
    h.eq(fmt, "%d")
    h.eq(rawequal(args[1], s), true)
    fmt, args = UnitText.level(-1)
    h.eq(fmt, "%s")
    h.eq(args[1], "??")
    fmt, args = UnitText.level(nil)
    h.eq(fmt, "%s")
    h.eq(args[1], "??")
    fmt, args = UnitText.level(80)
    h.eq(fmt, "%d")
    h.eq(args[1], 80)
  end)
end)

h.test("health color: class, reaction, secret, default", function()
  local paladin = { GetRGB = function() return 0.96, 0.55, 0.73 end }
  withSecrets(function()
    local ns = load()
    local UnitColor, C = ns.UnitColor, ns.Theme.unitColors
    local function same(c, r, g, b)
      h.near(r, c[1]); h.near(g, c[2]); h.near(b, c[3])
    end
    local r, g, b = UnitColor.health({ isPlayer = true, class = "PALADIN", classColor = true })
    h.near(r, 0.96); h.near(g, 0.55); h.near(b, 0.73)
    r, g, b = UnitColor.health({ isPlayer = true, class = "PALADIN", classColor = false })
    same(C.healthDefault, r, g, b)
    r, g, b = UnitColor.health({ isPlayer = true, class = "NOPE", classColor = true })
    same(C.healthDefault, r, g, b)
    r, g, b = UnitColor.health({ isPlayer = true, class = fakes.secret(1), classColor = true })
    same(C.healthDefault, r, g, b)
    r, g, b = UnitColor.health({ isPlayer = false, reaction = 2 })
    same(C.hostile, r, g, b)
    r, g, b = UnitColor.health({ isPlayer = false, reaction = 4 })
    same(C.neutral, r, g, b)
    r, g, b = UnitColor.health({ isPlayer = false, reaction = 5 })
    same(C.friendly, r, g, b)
    r, g, b = UnitColor.health({ isPlayer = false, reaction = fakes.secret(2) })
    same(C.neutral, r, g, b)
    r, g, b = UnitColor.health({ isPlayer = false })
    same(C.neutral, r, g, b)
    r, g, b = UnitColor.health({ isPlayer = fakes.secret(1), reaction = 2 })
    same(C.healthDefault, r, g, b)
  end, { C_ClassColor = { GetClassColor = function(c) if c == "PALADIN" then return paladin end end } })
end)

h.test("dead and offline colors win", function()
  local paladin = { GetRGB = function() return 0.96, 0.55, 0.73 end }
  withSecrets(function()
    local ns = load()
    local UnitColor, C = ns.UnitColor, ns.Theme.unitColors
    local base = { isPlayer = true, class = "PALADIN", classColor = true }
    local function with(extra)
      local i = {}
      for k, v in pairs(base) do i[k] = v end
      for k, v in pairs(extra) do i[k] = v end
      return i
    end
    local r, g, b = UnitColor.health(with({ dead = true }))
    h.near(r, C.dead[1]); h.near(g, C.dead[2]); h.near(b, C.dead[3])
    r, g, b = UnitColor.health(with({ offline = true }))
    h.near(r, C.offline[1]); h.near(g, C.offline[2]); h.near(b, C.offline[3])
    r, g, b = UnitColor.health(with({ dead = true, offline = true }))
    h.near(r, C.dead[1])
    r, g, b = UnitColor.health(with({ dead = fakes.secret(1), offline = fakes.secret(2) }))
    h.near(r, 0.96); h.near(g, 0.55); h.near(b, 0.73)
  end, { C_ClassColor = { GetClassColor = function() return paladin end } })
end)

h.test("dead text is grey", function()
  withSecrets(function()
    local UnitText = load().UnitText
    local fmt = UnitText.bar("Percent", { dead = true }, function(v) return v end)
    h.eq(fmt, "|cffbbbbbb%s|r")
  end)
end)

h.test("ring color by classification", function()
  withSecrets(function()
    local ns = load()
    local UnitColor, T = ns.UnitColor, ns.Theme
    local C, gold, border = T.unitColors, T.colors.gold, T.colors.panelBorder
    local ring, badge = UnitColor.ring("elite")
    h.eq(ring, gold); h.eq(badge, gold)
    ring, badge = UnitColor.ring("worldboss")
    h.eq(ring, gold); h.eq(badge, gold)
    ring, badge = UnitColor.ring("rare")
    h.eq(ring, C.rare); h.eq(badge, C.rare)
    ring, badge = UnitColor.ring("rareelite")
    h.eq(ring, C.rare); h.eq(badge, gold)
    ring, badge = UnitColor.ring("normal")
    h.eq(ring, border); h.eq(badge, border)
    ring, badge = UnitColor.ring(fakes.secret(1))
    h.eq(ring, border); h.eq(badge, border)
    ring, badge = UnitColor.ring(nil)
    h.eq(ring, border); h.eq(badge, border)
  end)
end)

h.test("power and cast colors", function()
  withSecrets(function()
    local ns = load()
    local UnitColor, C = ns.UnitColor, ns.Theme.unitColors
    local r, g, b = UnitColor.power("MANA")
    h.near(r, 0); h.near(g, 0.44); h.near(b, 0.87)
    h.eq(UnitColor.cast("cast"), C.cast)
    h.eq(UnitColor.cast("channel"), C.channel)
    h.eq(UnitColor.cast("interrupted"), C.interrupted)
    h.eq(UnitColor.cast("uninterruptible"), C.uninterruptible)
  end, { PowerBarColor = fakes.NIL })
  withSecrets(function()
    local UnitColor = load().UnitColor
    local r, g, b = UnitColor.power("RAGE")
    h.near(r, 1); h.near(g, 0); h.near(b, 0)
    r, g, b = UnitColor.power("MANA")
    h.near(r, 0); h.near(b, 0.87)
    r, g, b = UnitColor.power(fakes.secret("RAGE"))
    h.near(r, 0); h.near(b, 0.87)
  end, { PowerBarColor = { RAGE = { r = 1, g = 0, b = 0 } } })
end)

h.test("alpha rules", function()
  local UnitState = load().UnitState
  h.near(UnitState.alpha({ outOfCombat = 40 }), 0.4)
  h.eq(UnitState.alpha({ outOfCombat = 40, inCombat = true }), 1)
  h.eq(UnitState.alpha({ outOfCombat = 40, hover = true, mouseover = true }), 1)
  h.near(UnitState.alpha({ outOfCombat = 40, hover = true, mouseover = false }), 0.4)
  h.near(UnitState.alpha({ outOfCombat = 40, hover = false, mouseover = true }), 0.4)
  h.eq(UnitState.alpha({ outOfCombat = 40, editMode = true }), 1)
end)

h.test("visibility conditions", function()
  local UnitState = load().UnitState
  h.eq(UnitState.visibility("player", true), "[petbattle] hide; show")
  h.eq(UnitState.visibility("player", false), "[petbattle] hide; [vehicleui] hide; show")
  h.eq(UnitState.visibility("target", true), "[petbattle] hide; [@target,exists] show; hide")
  h.eq(UnitState.visibility("target", false),
    "[petbattle] hide; [vehicleui] hide; [@target,exists] show; hide")
end)
