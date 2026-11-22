local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  return h.load({ "Core/Util.lua", "Core/Locale.lua", "Locales/deDE.lua", "Core/Theme.lua",
    "Core/UnitColor.lua", "Core/UnitLayout.lua", "Units/Parts/Panel.lua",
    "Units/Parts/CastBar.lua", "Units/Parts/Auras.lua" })
end

-- Runs fn(ns, client, units) with a fake client and unit API; restores units
-- first, then the client (reverse install order).
local function withUnits(map, fn)
  local client = fakes.client({})
  local units = fakes.units(map)
  local ok, err = pcall(fn, load(), client, units)
  units.restore()
  client.restore()
  if not ok then error(err, 0) end
end

local function castBar(ns)
  local cast = ns.Units.Parts.CastBar.create(fakes.frame(), "target")
  cast:layout({ width = 200, height = 18, icon = true })
  return cast
end

h.test("cast with secret duration and flags", function()
  local name, flag, duration = fakes.secret(1), fakes.secret(2), fakes.secret(3)
  withUnits({ target = { casting = { name = name, texture = 1, notInterruptible = flag, duration = duration } } },
    function(ns)
      local cast = castBar(ns)
      cast:update("UNIT_SPELLCAST_START", "target")
      h.eq(cast.frame:IsShown(), true, "shown")
      h.eq(rawequal(cast.bar._timer[1], duration), true, "timer takes the duration")
      h.eq(cast.bar._timer[2], Enum.StatusBarInterpolation.Immediate)
      h.eq(cast.bar._timer[3], Enum.StatusBarTimerDirection.ElapsedTime)
      h.eq(rawequal(cast.shield._alphaFrom[1], flag), true, "shield alpha from the flag")
      h.eq({ cast.shield._alphaFrom[2], cast.shield._alphaFrom[3] }, { 1, 0 })
      h.eq(rawequal(cast.grey._alphaFrom[1], flag), true, "grey overlay alpha from the flag")
      h.eq(rawequal(cast.name:GetText(), name), true, "name passed on")
      h.eq(cast.color, ns.Theme.unitColors.cast)
    end)
end)

h.test("cast info positions: notInterruptible slot for cast and channel", function()
  withUnits({ target = { casting = { name = "Bolt", notInterruptible = true, castID = "id", duration = 1 } },
    focus = { channel = { name = "Flay", notInterruptible = true, spellID = 99, duration = 2 } } },
    function(ns)
      local cast = castBar(ns)
      cast:update("UNIT_SPELLCAST_START", "target")
      h.eq(cast.color, ns.Theme.unitColors.uninterruptible, "cast: slot 8")
      local chan = ns.Units.Parts.CastBar.create(fakes.frame(), "focus")
      chan:layout({ width = 200, height = 18, icon = true })
      chan:update("UNIT_SPELLCAST_CHANNEL_START", "focus")
      h.eq(chan.color, ns.Theme.unitColors.uninterruptible, "channel: slot 7")
      h.eq(chan.bar._timer[3], Enum.StatusBarTimerDirection.RemainingTime)
      h.eq(chan.bar._timer[1], 2)
    end)
end)

h.test("plain uninterruptible cast is grey with the shield", function()
  withUnits({ target = { casting = { name = "Bolt", notInterruptible = true, duration = 1 } } }, function(ns)
    local cast = castBar(ns)
    cast:update("UNIT_SPELLCAST_START", "target")
    h.eq(cast.color, ns.Theme.unitColors.uninterruptible)
    h.eq(cast.shield:GetAlpha(), 1)
    h.eq(cast.grey:GetAlpha(), 0)
    h.eq(cast.name:GetText(), "Bolt")
  end)
end)

h.test("plain interruptible channel is green without the shield", function()
  withUnits({ target = { channel = { name = "Flay", notInterruptible = false, duration = 1 } } }, function(ns)
    local cast = castBar(ns)
    cast:update("UNIT_SPELLCAST_CHANNEL_START", "target")
    h.eq(cast.color, ns.Theme.unitColors.channel)
    h.eq(cast.shield:GetAlpha(), 0)
  end)
end)

h.test("interrupted holds then hides", function()
  withUnits({ target = { casting = { name = "Bolt", duration = 1 } } }, function(ns, client, units)
    local pending = {}
    _G.C_Timer = { After = function(t, fn) pending[#pending + 1] = { t, fn } end }
    local cast = castBar(ns)
    cast:update("UNIT_SPELLCAST_START", "target")
    units.set("target", "casting", nil)
    cast:update("UNIT_SPELLCAST_INTERRUPTED", "target")
    h.eq(cast.frame:IsShown(), true, "still shown")
    h.eq(cast.name:GetText(), "Interrupted")
    h.eq(cast.color, ns.Theme.unitColors.interrupted)
    h.eq(cast.full:IsShown(), true, "full bar")
    h.eq(#pending, 1)
    h.eq(pending[1][1], ns.Theme.sizes.unit.interruptHold)
    cast:update("UNIT_SPELLCAST_STOP", "target")
    h.eq(cast.frame:IsShown(), true, "the STOP after the kick keeps the hold")
    pending[1][2]()
    h.eq(cast.frame:IsShown(), false, "hidden after the hold")

    -- A new cast before the callback cancels the hide.
    units.set("target", "casting", { name = "Bolt", duration = 1 })
    cast:update("UNIT_SPELLCAST_START", "target")
    units.set("target", "casting", nil)
    cast:update("UNIT_SPELLCAST_INTERRUPTED", "target")
    units.set("target", "casting", { name = "Fireball", duration = 2 })
    cast:update("UNIT_SPELLCAST_START", "target")
    h.eq(cast.full:IsShown(), false, "the new cast ends the hold")
    pending[2][2]()
    h.eq(cast.frame:IsShown(), true, "the old hold does not hide the new cast")
    h.eq(cast.name:GetText(), "Fireball")
  end)
end)

h.test("a kicked channel holds on interruptedBy", function()
  withUnits({ target = { channel = { name = "Flay", duration = 1 } } }, function(ns, client, units)
    local pending = {}
    _G.C_Timer = { After = function(t, fn) pending[#pending + 1] = fn end }
    local cast = castBar(ns)
    cast:update("UNIT_SPELLCAST_CHANNEL_START", "target")
    units.set("target", "channel", nil)
    cast:update("UNIT_SPELLCAST_CHANNEL_STOP", "target", nil, 5, fakes.secret(9))
    h.eq(cast.name:GetText(), "Interrupted")
    h.eq(#pending, 1)
    -- A plain stop (no interruptedBy) just hides.
    units.set("target", "channel", { name = "Flay", duration = 1 })
    cast:update("UNIT_SPELLCAST_CHANNEL_START", "target")
    units.set("target", "channel", nil)
    cast:update("UNIT_SPELLCAST_CHANNEL_STOP", "target", nil, 5, nil)
    h.eq(cast.frame:IsShown(), false)
  end)
end)

h.test("no cast hides the bar", function()
  withUnits({ target = {} }, function(ns)
    local cast = castBar(ns)
    cast.frame:Show()
    cast:update("UNIT_SPELLCAST_STOP", "target")
    h.eq(cast.frame:IsShown(), false)
  end)
end)

h.test("cast sample is a static bar", function()
  withUnits({ target = {} }, function(ns)
    local cast = castBar(ns)
    cast:sample(true)
    h.eq(cast.frame:IsShown(), true)
    h.eq(cast.bar:GetValue(), 0.62)
    h.eq(cast.name:GetText(), "Sample Spell")
    h.eq(cast.time:GetText(), "0.9")
    h.eq(cast.color, ns.Theme.unitColors.cast)
    cast:update("UNIT_SPELLCAST_STOP", "target")
    h.eq(cast.frame:IsShown(), true, "events leave the sample alone")
    cast:sample(false)
    h.eq(cast.frame:IsShown(), false, "no cast after the sample")
  end)
end)

h.test("cast events list", function()
  withUnits({}, function(ns)
    local seen = {}
    for _, e in ipairs(ns.Units.Parts.CastBar.EVENTS) do seen[e] = true end
    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_INTERRUPTED",
      "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
      h.eq(seen[e], true, e)
    end
  end)
end)

h.test("auras without the template stay quiet", function()
  withUnits({}, function(ns)
    local create = _G.CreateFrame
    _G.CreateFrame = function(kind, ...)
      if kind == "AuraContainer" then error("no template") end
      return create(kind, ...)
    end
    local auras = ns.Units.Parts.Auras.create(fakes.frame(), "target")
    h.eq(auras.available, false)
    auras:layout({ size = 22, rows = 1, width = 200, buffs = true, debuffs = true, onlyMine = false })
    auras:sample(true)
    auras:sample(false)
  end)
end)

-- A fake AuraContainer recording groups and flow layout calls.
local function fakeContainer()
  local c = fakes.frame()
  c.groups = {}
  function c:AddAuraGroup(key, filter, opts) self.groups[key] = { filter = filter, opts = opts, enabled = true } end
  function c:SetAuraGroupEnabled(key, on) self.groups[key].enabled = on end
  function c:SetAuraGroupMaxFrameCount(key, n) self.groups[key].max = n end
  function c:SetAuraGroupLayout(key, layout) self.groups[key].layout = layout end
  function c:SetFlowLayoutAxis() end
  function c:SetFlowLayoutAnchorPoint(p) self.anchor = p end
  function c:SetFlowLayoutGrowthDirection(x, y) self.growth = { x, y } end
  function c:SetFlowLayoutMaximumLineSize(n) self.lineSize = n end
  return c
end

local function withContainer(fn)
  withUnits({}, function(ns)
    local container = fakeContainer()
    local create = _G.CreateFrame
    _G.CreateFrame = function(kind, ...)
      if kind == "AuraContainer" then return container end
      return create(kind, ...)
    end
    _G.AnchorUtil = { FlowLayoutAxis = { Horizontal = "H" }, FlowDirection = { Left = "L", Right = "R", Down = "D" } }
    local ok, err = pcall(fn, ns, container)
    _G.AnchorUtil = nil
    if not ok then error(err, 0) end
  end)
end

h.test("aura groups follow the options", function()
  withContainer(function(ns, c)
    local auras = ns.Units.Parts.Auras.create(fakes.frame(), "target")
    h.eq(auras.available, true)
    h.eq(c.groups.debuffMine.filter, "HARMFUL|PLAYER")
    h.eq(c.groups.debuffOther.filter, "HARMFUL|!PLAYER")
    h.eq(c.groups.buffMine.filter, "HELPFUL|PLAYER")
    h.eq(c.groups.buffOther.filter, "HELPFUL|!PLAYER")
    auras:layout({ size = 22, rows = 2, width = 200, buffs = true, debuffs = true, onlyMine = true })
    h.eq(c.groups.debuffMine.enabled, true)
    h.eq(c.groups.debuffOther.enabled, false, "only mine: others off")
    h.eq(c.groups.buffMine.enabled, true)
    h.eq(c.groups.buffOther.enabled, false)
    h.eq(c.groups.debuffMine.max, 16, "8 per row x 2 rows")
    h.eq(c.lineSize, 200)
    h.eq(c.anchor, "TOPLEFT")
    h.eq(c.growth, { "R", "D" })
    h.eq(c.groups.buffMine.layout.forceNewLine, true, "buffs start a new line")
    auras:layout({ size = 22, rows = 1, width = 200, buffs = false, debuffs = true, onlyMine = false, mirror = true })
    h.eq(c.groups.debuffOther.enabled, true)
    h.eq(c.groups.buffMine.enabled, false)
    h.eq(c.anchor, "TOPRIGHT", "portrait on the right: start right")
    h.eq(c.growth, { "L", "D" })
  end)
end)

h.test("aura sample draws placeholders", function()
  withContainer(function(ns, c)
    local auras = ns.Units.Parts.Auras.create(fakes.frame(), "target")
    auras:layout({ size = 22, rows = 1, width = 200, buffs = true, debuffs = true, onlyMine = false })
    auras:sample(true)
    local n = 0
    for _, s in ipairs(auras.samples) do if s.icon:IsShown() then n = n + 1 end end
    h.eq(n, 6, "4 debuffs + 2 buffs")
    h.eq(c:IsShown(), false, "container hidden under the sample")
    auras:sample(false)
    h.eq(c:IsShown(), true)
    for _, s in ipairs(auras.samples) do h.eq(s.icon:IsShown(), false) end
  end)
end)
