local h = ...
local fakes = dofile("tests/fakes.lua")

-- The XP / Reputation module (Bars/Tracking.lua) loaded from the .toc and
-- started through Core.init with a fake client, fake units, a fake
-- LibEditMode and a fake XP / reputation API reading from a table the tests
-- change.

local BLIZZARD = { "PlayerFrame", "PlayerCastingBarFrame", "TargetFrame", "FocusFrame", "PetFrame",
  "PartyFrame", "CompactPartyFrame", "BossTargetFrameContainer",
  "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }

local function fakeLem()
  local lem = { SettingType = { Checkbox = 1, Slider = 2, Dropdown = 3, Divider = 4 }, callbacks = {}, frames = {} }
  function lem:AddFrame(frame) self.frames[#self.frames + 1] = frame end
  function lem:AddFrameSettings() end
  function lem:AddFrameSettingsButtons() end
  function lem:RegisterCallback(name, fn) self.callbacks[name] = fn end
  function lem:GetActiveLayoutName() return "Modern" end
  return lem
end

-- The watched faction in the modern shape.
local function faction(name, reaction, min, max, value)
  return { name = name, reaction = reaction, currentReactionThreshold = min, nextReactionThreshold = max,
    currentStanding = value }
end

-- r = { xp, max, rested, atMax, disabled, faction (modern table or nil),
-- legacy ({ name, reaction, min, max, value } or nil; with it C_Reputation is
-- missing) }: what the fake API answers. The player is level 42.
local function trackingGlobals(r)
  local g = {
    UnitXP = function() return r.xp end,
    UnitXPMax = function() return r.max end,
    GetXPExhaustion = function() return r.rested end,
    IsPlayerAtEffectiveMaxLevel = function() return r.atMax end,
    IsXPUserDisabled = function() return r.disabled end,
    UnitHonor = function() return r.honor end,
    UnitHonorMax = function() return r.honorMax end,
    UnitHonorLevel = function() return r.honorLevel end,
    ToggleCharacter = function(name) r.opened[#r.opened + 1] = "character:" .. tostring(name) end,
    TogglePVPUI = function() r.opened[#r.opened + 1] = "pvp" end,
    GetCursorPosition = function() return 0, r.cursorY end,
    C_Reputation = { GetWatchedFactionData = function() return r.faction end },
    GetWatchedFactionInfo = function()
      local l = r.legacy
      if not l then return nil end
      return l[1], l[2], l[3], l[4], l[5]
    end,
  }
  if r.legacy then g.C_Reputation = fakes.NIL end
  if r.noHonor then g.UnitHonor = fakes.NIL end
  return g
end

-- Runs fn(ns, r, client, lem, blizzard) after Core.init with r as the state.
local function withBar(state, fn)
  local r = { xp = 12345, max = 50000, rested = 3000, atMax = false, disabled = false,
    faction = faction("Argent Dawn", 5, 3000, 9000, 4200),
    honor = 1240, honorMax = 4000, honorLevel = 12, opened = {}, cursorY = 0 }
  for k, v in pairs(state or {}) do r[k] = v end
  if state and state.faction == false then r.faction = nil end
  local client = fakes.client({})
  local units = fakes.units({ player = { exists = true, name = "Me", class = "MAGE", level = 42,
    health = 100, healthMax = 100, isPlayer = true } })
  local lem = fakeLem()
  local globals = trackingGlobals(r)
  globals.LibStub = fakes.libstub({ LibEditMode = lem })
  globals.AnotherHUDDB, globals.AnotherHUDCharDB = fakes.NIL, fakes.NIL
  globals.EditModeManagerFrame = fakes.NIL
  local blizzard = {}
  for _, name in ipairs(BLIZZARD) do
    blizzard[name] = fakes.frame(name)
    globals[name] = blizzard[name]
  end
  local ok, err = pcall(fakes.withGlobals, globals, function()
    local ns = h.load(h.toc())
    ns.Util.say = function() end
    ns.Core.init()
    fn(ns, r, client, lem, blizzard)
  end)
  units.restore()
  client.restore()
  if not ok then error(err, 0) end
end

local function parts(ns)
  local spec = ns.Modules.get("tracking")
  return spec, spec.frame, spec.xp, spec.rep
end

local function lastPoint(f)
  local p
  for _, c in ipairs(f.calls) do if c[1] == "SetPoint" then p = c end end
  return p
end

local function edge(ns)
  return ns.UnitLayout.edgeWidth(ns.Theme.skins.classic.border)
end

h.test("the tracking module registers with Edit Mode and the checklist", function()
  withBar({}, function(ns, _, _, lem)
    local spec, frame = parts(ns)
    h.eq(spec.kind, "bar")
    h.eq(spec.label, "XP / Reputation")
    h.eq(spec.parent, nil)
    h.eq(spec.defaultPosition, { point = "BOTTOM", x = 0, y = 2 })
    h.eq(frame:GetName(), "AnotherHUDTrackingBar")
    h.eq(frame:GetParent() == nil or frame:GetParent() == UIParent, true, "child of UIParent")
    local found = false
    for _, f in ipairs(lem.frames) do if f == frame then found = true end end
    h.eq(found, true, "registered with LibEditMode")
    local listed = false
    for _, e in ipairs(ns.EditMode.Checklist.entries()) do if e.id == "tracking" then listed = true end end
    h.eq(listed, true, "listed in the checklist")
    h.eq(ns.Options.get("tracking", "text"), "Hover")
    h.eq(ns.Options.get("tracking", "width"), 500)
    h.eq(ns.Options.get("tracking", "height"), 10)
  end)
end)

h.test("XP and reputation stack with XP on top", function()
  withBar({}, function(ns)
    local spec, frame, xp, rep = parts(ns)
    local e = edge(ns)
    h.eq(frame:IsShown(), true, "frame shown")
    h.eq({ frame._width, frame._height }, { 500, 2 * 10 + 1 + 2 * e })
    h.eq(xp.bar:IsShown(), true, "xp shown")
    h.eq({ xp.bar._min, xp.bar._max, xp.bar._value }, { 0, 50000, 12345 })
    h.eq(xp.rested:IsShown(), true, "rested shown")
    h.eq({ xp.rested._min, xp.rested._max, xp.rested._value }, { 0, 50000, 15345 })
    h.eq({ rep.bar._min, rep.bar._max, rep.bar._value }, { 3000, 9000, 4200 })
    h.eq(lastPoint(xp.bar), { "SetPoint", "TOPLEFT", frame, "TOPLEFT", e, -e })
    h.eq(lastPoint(rep.bar), { "SetPoint", "TOPLEFT", frame, "TOPLEFT", e, -(e + 11) })
    h.eq({ xp.bar._width, xp.bar._height }, { 500 - 2 * e, 10 })
    h.eq(spec.divider:IsShown(), true, "divider shown")
    h.eq(xp.bar._barColor, { ns.Theme.barColor(ns.Theme.trackingColors.xp, "Smooth") })
    local rr, rg, rb = ns.Theme.barColor(ns.Theme.trackingColors.rested, "Smooth")
    h.eq(xp.rested._barColor, { rr, rg, rb, ns.Theme.sizes.tracking.restedAlpha })
    h.eq(rep.bar._barColor, { ns.Theme.barColor(ns.Theme.trackingColors.reaction[5], "Smooth") })
    h.eq(xp.bg._color[4], ns.Theme.sizes.unit.barBgAlpha)
    h.eq(xp.text._text, "Level 42  12,345 / 50,000 (24%)  +3,000 rested")
    h.eq(rep.text._text, "Argent Dawn  Friendly  1,200 / 6,000")
    h.eq(xp.text._font, { ns.Theme.fonts.file, 10, "OUTLINE" })
  end)
end)

h.test("reaching max level drops the XP bar", function()
  withBar({}, function(ns, r, client)
    local spec, frame, xp, rep = parts(ns)
    r.atMax = true
    client.fire("PLAYER_LEVEL_UP", 43)
    local e = edge(ns)
    h.eq(frame._height, 10 + 2 * e)
    h.eq(xp.bar:IsShown(), false, "xp hidden")
    h.eq(xp.rested:IsShown(), false, "rested hidden")
    h.eq(xp.text:IsShown(), false, "xp text hidden")
    h.eq(rep.bar:IsShown(), true, "rep shown")
    h.eq(lastPoint(rep.bar), { "SetPoint", "TOPLEFT", frame, "TOPLEFT", e, -e })
    h.eq(spec.divider:IsShown(), false, "divider hidden")
  end)
end)

h.test("no bar to show hides the frame", function()
  withBar({ atMax = true, faction = false }, function(ns, _, _, lem)
    local spec, frame, xp, rep = parts(ns)
    h.eq(frame:IsShown(), false, "hidden")
    lem.callbacks.enter()
    h.eq(frame:IsShown(), true, "Edit Mode shows the sample")
    h.eq(xp.bar:IsShown(), true)
    h.eq(rep.bar:IsShown(), true)
    h.eq(spec.divider:IsShown(), true)
    h.eq({ xp.bar._min, xp.bar._max, xp.bar._value }, { 0, 1000, 600 })
    h.eq(xp.rested._value, 800)
    h.eq(xp.text._text, "Level 42  600 / 1,000 (60%)  +200 rested")
    h.eq(rep.text._text, "Sample Faction  Friendly  3,000 / 6,000")
    h.eq({ rep.bar._min, rep.bar._max, rep.bar._value }, { 3000, 9000, 6000 })
    h.eq(xp.text:IsShown(), true, "texts show in Edit Mode")
    lem.callbacks.exit()
    h.eq(frame:IsShown(), false, "hidden again")
  end)
end)

h.test("watching a faction shows the reputation bar at once", function()
  withBar({ atMax = true, faction = false }, function(ns, r, client)
    local _, frame, _, rep = parts(ns)
    h.eq(frame:IsShown(), false)
    r.faction = faction("Stormwind", 6, 21000, 42000, 30000)
    client.fire("UPDATE_FACTION")
    h.eq(frame:IsShown(), true, "shown")
    h.eq(rep.bar:IsShown(), true, "rep row")
    h.eq({ rep.bar._min, rep.bar._max, rep.bar._value }, { 21000, 42000, 30000 })
    h.eq(rep.text._text, "Stormwind  Honored  9,000 / 21,000")
  end)
end)

h.test("secret XP fills the bar without text", function()
  withBar({}, function(ns, r, client)
    local _, _, xp = parts(ns)
    local s = fakes.secret(777)
    r.xp = s
    client.fire("PLAYER_XP_UPDATE", "player")
    h.eq(xp.bar._value, s)
    h.eq(xp.bar._max, 50000)
    h.eq(xp.text._text, "")
    h.eq(xp.rested:IsShown(), false, "rested hidden")
    r.max = fakes.secret(50000)
    client.fire("PLAYER_XP_UPDATE", "player")
    h.eq(xp.bar._max, r.max)
  end)
end)

h.test("text follows the Text option", function()
  withBar({}, function(ns)
    local _, frame, xp, rep = parts(ns)
    h.eq(xp.text:IsShown(), false, "hover: hidden")
    h.eq(rep.text:IsShown(), false, "hover: rep hidden")
    frame._scripts.OnEnter(frame)
    h.eq(xp.text:IsShown(), true, "hover: shown on enter")
    h.eq(rep.text:IsShown(), true)
    frame._scripts.OnLeave(frame)
    h.eq(xp.text:IsShown(), false, "hover: hidden on leave")
    ns.Options.set("tracking", "text", "Always")
    h.eq(xp.text:IsShown(), true, "always")
    ns.Options.set("tracking", "text", "Never")
    frame._scripts.OnEnter(frame)
    h.eq(xp.text:IsShown(), false, "never, even on hover")
    h.eq(rep.text:IsShown(), false)
  end)
end)

h.test("Show XP off leaves only reputation", function()
  withBar({}, function(ns)
    local spec, frame, xp, rep = parts(ns)
    ns.Options.set("tracking", "showXP", false)
    h.eq(xp.bar:IsShown(), false)
    h.eq(rep.bar:IsShown(), true)
    h.eq(spec.divider:IsShown(), false)
    h.eq(frame._height, 10 + 2 * edge(ns))
    ns.Options.set("tracking", "showReputation", false)
    h.eq(frame:IsShown(), false, "nothing left")
  end)
end)

h.test("the Edit Mode sample follows Show XP / Show reputation", function()
  withBar({}, function(ns, _, _, lem)
    local spec, frame, xp, rep = parts(ns)
    lem.callbacks.enter()
    ns.Options.set("tracking", "showXP", false)
    h.eq(xp.bar:IsShown(), false, "no xp sample")
    h.eq(rep.bar:IsShown(), true, "rep sample")
    h.eq(spec.divider:IsShown(), false)
    h.eq(frame._height, 10 + 2 * edge(ns))
    ns.Options.set("tracking", "showXP", true)
    ns.Options.set("tracking", "showReputation", false)
    h.eq(xp.bar:IsShown(), true, "xp sample")
    h.eq(rep.bar:IsShown(), false, "no rep sample")
    ns.Options.set("tracking", "showXP", false)
    h.eq(xp.bar:IsShown(), true, "both off: both samples")
    h.eq(rep.bar:IsShown(), true, "both off: both samples")
    h.eq(frame:IsShown(), true)
  end)
end)

h.test("a row's text gets the row's inner width", function()
  withBar({}, function(ns)
    local _, _, xp, rep = parts(ns)
    local iw = 500 - 2 * edge(ns)
    h.eq(xp.text._width, iw)
    h.eq(rep.text._width, iw)
  end)
end)

h.test("legacy reputation API works when C_Reputation is missing", function()
  withBar({ legacy = { "Darnassus", 7, 21000, 42000, 25000 } }, function(ns)
    local _, _, _, rep = parts(ns)
    h.eq(_G.C_Reputation, nil)
    h.eq(rep.bar:IsShown(), true)
    h.eq({ rep.bar._min, rep.bar._max, rep.bar._value }, { 21000, 42000, 25000 })
    h.eq(rep.text._text, "Darnassus  Revered  4,000 / 21,000")
  end)
end)

h.test("turned off, the frame hides", function()
  withBar({}, function(ns)
    local spec, frame = parts(ns)
    ns.Modules.setEnabled("tracking", false)
    spec.apply(spec)
    h.eq(frame:IsShown(), false)
    ns.Modules.setEnabled("tracking", true)
    spec.apply(spec)
    h.eq(frame:IsShown(), true)
  end)
end)

h.test("Blizzard's status tracking bars are hidden", function()
  withBar({}, function(_, _, _, _, blizzard)
    for _, name in ipairs({ "StatusTrackingBarManager", "MainStatusTrackingBarContainer",
      "SecondaryStatusTrackingBarContainer" }) do
      local f = blizzard[name]
      h.eq(f:GetParent() ~= nil and f:GetParent() ~= UIParent, true, name .. " reparented")
      h.eq(f:IsShown(), false, name .. " hidden")
    end
  end)
end)

h.test("fading follows combat and the mouse", function()
  withBar({}, function(ns, _, client)
    local _, frame = parts(ns)
    ns.Options.set("tracking", "outOfCombat", 40)
    h.eq(frame._alpha, 0.4)
    client.fire("PLAYER_REGEN_DISABLED")
    h.eq(frame._alpha, 1)
    client.fire("PLAYER_REGEN_ENABLED")
    h.eq(frame._alpha, 0.4)
    frame._scripts.OnEnter(frame)
    h.eq(frame._alpha, 1)
    frame._scripts.OnLeave(frame)
    h.eq(frame._alpha, 0.4)
  end)
end)

h.test("the divider uses the shared segment painter", function()
  withBar({}, function(ns)
    local spec = parts(ns)
    local Segments = ns.Bars.Segments
    local real, seen = Segments.paintDivider, nil
    Segments.paintDivider = function(d, groove, lines)
      seen = { d, groove, lines }
      return real(d, groove, lines)
    end
    ns.Options.set("tracking", "skin", "Forge")
    Segments.paintDivider = real
    h.eq(seen, { spec.divider, spec.groove, "groove" })
    h.eq(spec.groove:IsShown(), true, "Forge groove line")
  end)
end)

-- The honor row of the tracking spec.
local function honorRow(ns)
  return ns.Modules.get("tracking").honor
end

-- Clicks the middle of the i-th shown row (the frame's top at y = 100).
local function clickRow(ns, r, frame, i, button)
  local e = edge(ns)
  frame.GetTop = function() return 100 end
  frame.GetEffectiveScale = function() return 1 end
  r.cursorY = 100 - (e + (i - 1) * 11 + 5)
  frame._scripts.OnMouseUp(frame, button or "LeftButton")
end

h.test("Show honor is off by default", function()
  withBar({}, function(ns)
    local _, frame = parts(ns)
    h.eq(ns.Options.get("tracking", "showHonor"), false)
    h.eq(honorRow(ns).bar:IsShown(), false)
    h.eq(frame._height, 2 * 10 + 1 + 2 * edge(ns))
  end)
end)

h.test("Show honor adds a third row under reputation", function()
  withBar({}, function(ns)
    local _, frame = parts(ns)
    ns.Options.set("tracking", "showHonor", true)
    local e, hr = edge(ns), honorRow(ns)
    h.eq(frame._height, 3 * 10 + 2 * 1 + 2 * e)
    h.eq(hr.bar:IsShown(), true)
    h.eq(lastPoint(hr.bar), { "SetPoint", "TOPLEFT", frame, "TOPLEFT", e, -(e + 22) })
    h.eq({ hr.bar._min, hr.bar._max, hr.bar._value }, { 0, 4000, 1240 })
    h.eq(hr.bar._barColor, { ns.Theme.barColor(ns.Theme.trackingColors.honor, "Smooth") })
    h.eq(hr.text._text, "Honor level 12  1,240 / 4,000 (31%)")
  end)
end)

h.test("three rows get two dividers", function()
  withBar({}, function(ns)
    local spec, frame = parts(ns)
    ns.Options.set("tracking", "showHonor", true)
    local e = edge(ns)
    h.eq(spec.divider:IsShown(), true)
    h.eq(spec.divider2:IsShown(), true)
    h.eq(lastPoint(spec.divider), { "SetPoint", "TOPLEFT", frame, "TOPLEFT", e, -(e + 10) })
    h.eq(lastPoint(spec.divider2), { "SetPoint", "TOPLEFT", frame, "TOPLEFT", e, -(e + 21) })
    ns.Options.set("tracking", "showHonor", false)
    h.eq(spec.divider2:IsShown(), false)
  end)
end)

h.test("honor events update the honor row", function()
  withBar({}, function(ns, r, client)
    ns.Options.set("tracking", "showHonor", true)
    local hr = honorRow(ns)
    r.honor = 2000
    client.fire("HONOR_XP_UPDATE", "player")
    h.eq(hr.bar._value, 2000)
    r.honorLevel = 13
    client.fire("HONOR_LEVEL_UPDATE")
    h.eq(hr.text._text, "Honor level 13  2,000 / 4,000 (50%)")
  end)
end)

h.test("without UnitHonor there is no honor row", function()
  withBar({ noHonor = true }, function(ns)
    local _, frame = parts(ns)
    ns.Options.set("tracking", "showHonor", true)
    h.eq(honorRow(ns).bar:IsShown(), false)
    h.eq(frame._height, 2 * 10 + 1 + 2 * edge(ns))
  end)
end)

h.test("the Edit Mode sample follows Show honor", function()
  withBar({}, function(ns, _, _, lem)
    lem.callbacks.enter()
    local hr = honorRow(ns)
    h.eq(hr.bar:IsShown(), false, "no honor sample while off")
    ns.Options.set("tracking", "showHonor", true)
    h.eq(hr.bar:IsShown(), true, "honor sample")
    h.eq({ hr.bar._max, hr.bar._value }, { 4000, 1240 })
    h.eq(hr.text._text, "Honor level 12  1,240 / 4,000 (31%)")
  end)
end)

h.test("clicking a row opens its pane", function()
  withBar({}, function(ns, r)
    local _, frame = parts(ns)
    ns.Options.set("tracking", "showHonor", true)
    clickRow(ns, r, frame, 1)
    h.eq(r.opened, {}, "xp row opens nothing")
    clickRow(ns, r, frame, 2)
    h.eq(r.opened, { "character:ReputationFrame" })
    clickRow(ns, r, frame, 3)
    h.eq(r.opened, { "character:ReputationFrame", "pvp" })
  end)
end)

h.test("with reputation off the honor row is second and still opens PvP", function()
  withBar({}, function(ns, r)
    local _, frame = parts(ns)
    ns.Options.set("tracking", "showHonor", true)
    ns.Options.set("tracking", "showReputation", false)
    clickRow(ns, r, frame, 2)
    h.eq(r.opened, { "pvp" })
  end)
end)

h.test("no pane opens in combat, in Edit Mode, or on a right click", function()
  withBar({}, function(ns, r, client, lem)
    local _, frame = parts(ns)
    ns.Options.set("tracking", "showHonor", true)
    clickRow(ns, r, frame, 2, "RightButton")
    client.setCombat(true)
    clickRow(ns, r, frame, 2)
    client.setCombat(false)
    lem.callbacks.enter()
    clickRow(ns, r, frame, 2)
    h.eq(r.opened, {})
  end)
end)
