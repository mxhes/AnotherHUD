local ADDON, ns = ...

-- The unit frame base the unit modules share: a SecureUnitButtonTemplate
-- button (left click targets, right click opens the unit menu) holding the
-- drawn parts (Units/Parts), the unit's events, the Edit Mode sample, fading
-- and hiding Blizzard's frames. Client values (health, power, name, level,
-- range, ...) only travel into the parts; flags are read only when plain.
-- Every change to the secure button (attributes, size, anchors, state
-- driver, show) goes through Combat.after, under keys made from frame.key.
-- A module builds one frame (spec.frame); a group builds several member
-- frames of one spec (o.member, each with its own key) and lays them out
-- with applyFrame / editModeFrame.
ns.Units = ns.Units or {}
local Base = {}

local THROTTLE = 0.2 -- targettarget refresh, seconds

local UNIT_EVENTS = {
  "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
  "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED",
  "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED", "UNIT_CONNECTION", "UNIT_FLAGS",
}

-- The event that says the unit itself changed: { event, unit for
-- RegisterUnitEvent or nil }.
local CHANGE = {
  target = { "PLAYER_TARGET_CHANGED" },
  focus = { "PLAYER_FOCUS_CHANGED" },
  targettarget = { "UNIT_TARGET", "target" }, -- plus PLAYER_TARGET_CHANGED (registerEvents)
  pet = { "UNIT_PET", "player" },
}

local PORTRAIT = { UNIT_PORTRAIT_UPDATE = true, UNIT_MODEL_CHANGED = true }
-- Frequent events: values and texts only (no colors, portrait, level).
local VALUES = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_POWER_UPDATE = true,
  UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true }
-- Role and leader changes: only the role badge and crown.
local ROLE = { PLAYER_ROLES_ASSIGNED = true, PARTY_LEADER_CHANGED = true }
-- Unit events that mean another unit in the frame: its cast as well.
local NEW_UNIT = { UNIT_TARGET = true, UNIT_PET = true, UNIT_TARGETABLE_CHANGED = true }
local CAST = {}
for _, ev in ipairs(ns.Units.Parts.CastBar.EVENTS) do CAST[ev] = true end

local SAMPLE_HEALTH = { cur = 72400, max = 100000, pct = 72 }
local SAMPLE_POWER = { cur = 55000, max = 100000, pct = 55 }

local hiddenParent
local hidden = {} -- Blizzard frame name -> true once hidden

local function opt(frame, key)
  return ns.Options.get(frame.id, key)
end

local function editing(frame)
  local glue = ns.EditMode and ns.EditMode.Glue
  return frame.sampling or (glue ~= nil and glue.inEditMode()) or false
end

local function maybe(fn, ...)
  if type(fn) == "function" then return fn(...) end
end

local function abbr(v)
  local f = _G.AbbreviateNumbers
  -- UNVERIFIED (check in client): AbbreviateNumbers accepts secret health /
  -- power values.
  if type(f) == "function" then return f(v) end
  return v
end

-- The text mode to use when the client may lack the percent API: no
-- percent, so "Percent" shows nothing and "Value + Percent" only the value
-- (plain logic on the mode string; SetFormattedText never gets a missing
-- argument).
local function textMode(mode, hasPercent)
  if hasPercent then return mode end
  if mode == "Percent" then return "None" end
  if mode == "Value + Percent" then return "Value" end
  return mode
end

-- The module is on and (for a group member) its slot is shown.
local function enabled(frame)
  return frame.slotOn ~= false and ns.Modules.isEnabled(frame.id)
end

local function plainBool(v)
  if ns.Util.isSecret(v) or type(v) ~= "boolean" then return nil end
  return v
end

local function isBoss(unit)
  return type(unit) == "string" and string.sub(unit, 1, 4) == "boss"
end

local function skinOf(frame)
  local id = opt(frame, "skin")
  local skins = ns.Theme.skins
  return (type(id) == "string" and skins[string.lower(id)]) or skins.classic
end
Base.skinOf = skinOf

local function castOn(frame)
  return frame.cast and opt(frame, "castBar") == true or false
end

local function visibility(frame)
  return ns.UnitState.visibility(frame.unit, opt(frame, "showInVehicle"))
end

-- Opacity (SetAlpha is not protected: it may run in combat). With
-- frame.range a unit out of range fades to rangeAlpha: the client's range
-- answer may be secret, so it only travels into SetAlphaFromBoolean; only
-- `checked` is read, and only when plain. The player is never out of range.
function Base.fade(frame)
  local edit = editing(frame)
  local a = ns.UnitState.alpha({
    editMode = edit,
    inCombat = frame.combat or InCombatLockdown(),
    hover = frame.hover,
    outOfCombat = opt(frame, "outOfCombat"),
    mouseover = opt(frame, "mouseover"),
  })
  local far = a * ns.Theme.sizes.unit.rangeAlpha
  if not frame.range then
    frame:SetAlpha(a)
  elseif edit then
    local s = frame.sampleState
    frame:SetAlpha(s and s.far and far or a)
  elseif frame.unit == "player" or type(_G.UnitInRange) ~= "function" then
    frame:SetAlpha(a)
  else
    -- UNVERIFIED (check in client): UnitInRange(unit) answers inRange,
    -- checked (inRange secret in restricted contexts) and
    -- SetAlphaFromBoolean takes that secret boolean.
    local inRange, checked = UnitInRange(frame.unit)
    if not ns.Util.isSecret(checked) and checked ~= true then
      frame:SetAlpha(a)
    elseif not pcall(frame.SetAlphaFromBoolean, frame, inRange, a, far) then
      frame:SetAlpha(a)
    end
  end
end

-- Everything from the client into the parts (valuesOnly: bars and texts,
-- not the colors, portrait, level and role; the bar colors too when the
-- plain dead / offline flag changed). No unit: texts cleared, nothing else
-- read.
function Base.update(frame, valuesOnly)
  if frame.sampling then return end
  local unit, bars, ring = frame.unit, frame.bars, frame.ring
  if not UnitExists(unit) then
    bars:setTexts("", "", {}, "", {})
    ring:setLevel("", {})
    if frame.role then frame.role:setUnit(nil) end
    return
  end
  local CC = _G.CurveConstants
  local scale = CC and CC.ScaleTo100
  local dead = plainBool(UnitIsDeadOrGhost(unit)) == true
  local offline = plainBool(UnitIsConnected(unit)) == false

  local hp, hpMax = UnitHealth(unit), UnitHealthMax(unit)
  -- UNVERIFIED (check in client): UnitHealthPercent(unit, true,
  -- CurveConstants.ScaleTo100) / UnitPowerPercent(unit, type, false, ...)
  -- answer 0..100 (secret in combat).
  local hpPct = maybe(_G.UnitHealthPercent, unit, true, scale)
  bars:setHealth(hp, hpMax)
  local healthMode = textMode(opt(frame, "healthText") or "None", type(_G.UnitHealthPercent) == "function")
  local healthFmt, healthArgs = ns.UnitText.bar(healthMode,
    { cur = hp, max = hpMax, pct = hpPct, dead = dead, offline = offline }, abbr)

  local powerFmt, powerArgs, powerRGB = "", {}, nil
  if frame.hasPower then
    local pw, pwMax = UnitPower(unit), UnitPowerMax(unit)
    local ptype, token = UnitPowerType(unit)
    if ns.Util.isSecret(token) then token = nil end
    local pwPct = maybe(_G.UnitPowerPercent, unit, ptype, false, scale)
    -- A dead unit's power bar is empty.
    if dead then bars:setPower(0, 1) else bars:setPower(pw, pwMax) end
    local powerMode = textMode(opt(frame, "powerText") or "None", type(_G.UnitPowerPercent) == "function")
    powerFmt, powerArgs = ns.UnitText.bar(powerMode,
      { cur = pw, max = pwMax, pct = pwPct, dead = dead, offline = offline }, abbr)
    powerRGB = { ns.UnitColor.power(token) }
  end

  bars:setTexts((UnitName(unit)), healthFmt, healthArgs, powerFmt, powerArgs)
  -- UNIT_HEALTH is a values-only event, but it is the one a death or a rez
  -- arrives with: a changed dead / offline flag also repaints the bars.
  local changed = dead ~= frame.deadState or offline ~= frame.offlineState
  frame.deadState, frame.offlineState = dead, offline
  if valuesOnly and not changed then return end

  local r, g, b = ns.UnitColor.health({
    isPlayer = UnitIsPlayer(unit), class = select(2, UnitClass(unit)),
    reaction = UnitReaction(unit, "player"), classColor = opt(frame, "classColor"),
    dead = dead, offline = offline,
  })
  bars:setColors({ r, g, b }, powerRGB)
  if valuesOnly then return end

  ring:setColors(ns.UnitColor.ring(UnitClassification(unit)))
  ring:setUnit(unit)
  local level = type(_G.UnitEffectiveLevel) == "function" and _G.UnitEffectiveLevel or UnitLevel
  ring:setLevel(ns.UnitText.level(level(unit)))
  if frame.role then frame.role:setUnit(unit) end
end

-- A group member's sample s = { name, class, role, leader, dead, offline,
-- far, dispel, healthPct, and optional reaction (no class color),
-- classification (ring color), level (nil: "??") }: plain values.
local function memberSample(frame, s)
  local bars, ring = frame.bars, frame.ring
  local pct = s.healthPct or 0
  local dead, offline = s.dead == true, s.offline == true
  bars:setHealth(pct, 100)
  local healthFmt, healthArgs = ns.UnitText.bar(opt(frame, "healthText") or "None",
    { cur = pct * 1000, max = 100000, pct = pct, dead = dead, offline = offline }, abbr)
  local powerFmt, powerArgs = "", {}
  if frame.hasPower then
    if dead then bars:setPower(0, 1) else bars:setPower(0.55, 1) end
    powerFmt, powerArgs = ns.UnitText.bar(opt(frame, "powerText") or "None",
      { cur = SAMPLE_POWER.cur, max = SAMPLE_POWER.max, pct = SAMPLE_POWER.pct, dead = dead, offline = offline },
      abbr)
  end
  local r, g, b = ns.UnitColor.health({ isPlayer = s.reaction == nil, class = s.class, reaction = s.reaction,
    classColor = opt(frame, "classColor"), dead = dead, offline = offline })
  bars:setColors({ r, g, b }, { ns.UnitColor.power("MANA") })
  bars:setTexts(s.name or "", healthFmt, healthArgs, powerFmt, powerArgs)
  ring:setColors(ns.UnitColor.ring(s.classification))
  ring:setUnit("player")
  ring:setLevel(ns.UnitText.level(s.level))
  if frame.role then
    frame.role:setRole(s.role)
    frame.role:setLeader(s.leader == true)
  end
end

-- The Edit Mode sample: plain values into the parts (cast bar and auras
-- draw their own). A member's sample function answers its slot's table
-- (nil: the frame's own sample below).
local function sample(frame, on)
  if castOn(frame) then frame.cast:sample(on) end
  if frame.auras then frame.auras:sample(on) end
  local s = on and frame.sampleFn and frame.sampleFn(frame) or nil
  frame.sampleState = s or false
  if frame.dispel then
    frame.dispel:sample(s and s.dispel and ns.Theme.unitColors.debuff[s.dispel] or nil)
  end
  if not on then return end
  if s then
    memberSample(frame, s)
    return
  end
  local bars, ring = frame.bars, frame.ring
  local name
  if frame.unit == "player" then name = UnitName("player") else name = ns.L[frame.spec.label] end
  bars:setHealth(0.72, 1)
  local healthFmt, healthArgs = ns.UnitText.bar(opt(frame, "healthText") or "None", SAMPLE_HEALTH, abbr)
  local powerFmt, powerArgs = "", {}
  if frame.hasPower then
    bars:setPower(0.55, 1)
    powerFmt, powerArgs = ns.UnitText.bar(opt(frame, "powerText") or "None", SAMPLE_POWER, abbr)
  end
  local r, g, b = ns.UnitColor.health({ isPlayer = true, class = select(2, UnitClass("player")),
    classColor = opt(frame, "classColor") })
  bars:setColors({ r, g, b }, { ns.UnitColor.power("MANA") })
  bars:setTexts(name, healthFmt, healthArgs, powerFmt, powerArgs)
  ring:setColors(ns.UnitColor.ring(nil))
  ring:setUnit("player")
  ring:setLevel(ns.UnitText.level(UnitLevel("player")))
end

-- Places the auras: beside the frame (auraSide "right": partyAuraGap right
-- of it; "left": bossAuraGap left of it; vertically centered), else under an
-- attached cast bar (auraBelowCast between) or L.below under the frame.
-- Plain frames, but anchored to the secure button: callers run it inside
-- Combat.after.
local function placeAuras(frame)
  local auras, L = frame.auras, frame.L
  if not auras or not L then return end
  local U = ns.Theme.sizes.unit
  local mirror = frame.mirror
  local top, bottom = mirror and "TOPRIGHT" or "TOPLEFT", mirror and "BOTTOMRIGHT" or "BOTTOMLEFT"
  auras.frame:ClearAllPoints()
  if frame.auraSide == "right" then
    auras.frame:SetPoint("LEFT", frame, "RIGHT", U.partyAuraGap, 0)
  elseif frame.auraSide == "left" then
    auras.frame:SetPoint("RIGHT", frame, "LEFT", -U.bossAuraGap, 0)
  elseif castOn(frame) and not frame.castHolder then
    auras.frame:SetPoint(top, frame.cast.frame, bottom, 0, -U.auraBelowCast)
  else
    auras.frame:SetPoint(top, frame, bottom, 0, -math.max(L.below, frame.reserved))
  end
end

local function placeCast(frame)
  local cast, L = frame.cast, frame.L
  if not cast or not L then return end
  local holder = frame.castHolder
  cast.frame:ClearAllPoints()
  if holder then
    cast.frame:SetParent(holder)
    cast.frame:SetPoint("CENTER", holder, "CENTER", 0, 0)
  else
    cast.frame:SetParent(frame)
    local mirror = frame.mirror
    local top, bottom = mirror and "TOPRIGHT" or "TOPLEFT", mirror and "BOTTOMRIGHT" or "BOTTOMLEFT"
    cast.frame:SetPoint(top, frame, bottom, 0, -math.max(frame.castGap or L.below, frame.reserved))
  end
  placeAuras(frame)
end

-- Keeps `px` free under the frame (the Player's resource bar sits there): the
-- cast bar and the auras directly under the frame move down to at least that
-- far. 0 / nil: today's placement. Queued, as it anchors to a secure frame.
function Base.reserveBelow(frame, px)
  frame.reserved = px or 0
  ns.Combat.after("unit:" .. frame.key .. ":cast", function() placeCast(frame) end)
end

-- Moves the cast bar onto `holder` (a detached cast bar's frame), or back
-- under the frame (holder nil).
function Base.anchorCast(frame, holder)
  frame.castHolder = holder or false
  ns.Combat.after("unit:" .. frame.key .. ":cast", function() placeCast(frame) end)
end

local function onEvent(frame, event, ...)
  if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    frame.combat = event == "PLAYER_REGEN_DISABLED"
    Base.fade(frame)
    return
  end
  if frame.sampling then return end
  if CAST[event] then
    if castOn(frame) then frame.cast:update(event, ...) end
    return
  end
  if PORTRAIT[event] then
    frame.ring:setUnit(frame.unit)
    return
  end
  if ROLE[event] then
    if frame.role then frame.role:setUnit(frame.unit) end
    return
  end
  Base.update(frame, VALUES[event] or false)
  if VALUES[event] then return end
  -- A new unit (or the world): its cast, if any.
  local unitEvent = string.sub(event, 1, 5) == "UNIT_"
  if castOn(frame) and (not unitEvent or NEW_UNIT[event]) then
    frame.cast:update(event, frame.unit)
  end
end

-- o: the Base.create options (castBar, roster, role).
local function registerEvents(frame, unit, o)
  if unit ~= "targettarget" then
    for _, ev in ipairs(UNIT_EVENTS) do frame:RegisterUnitEvent(ev, unit) end
    if o.castBar then
      for _, ev in ipairs(ns.Units.Parts.CastBar.EVENTS) do frame:RegisterUnitEvent(ev, unit) end
    end
  end
  local change = CHANGE[unit]
  if change then
    if change[2] then frame:RegisterUnitEvent(change[1], change[2]) else frame:RegisterEvent(change[1]) end
  end
  -- A new target is a new target of target at once (no stale name until
  -- the next throttled refresh).
  if unit == "targettarget" then frame:RegisterEvent("PLAYER_TARGET_CHANGED") end
  -- Group members: a roster change may put another unit behind the token.
  if o.roster or o.role then frame:RegisterEvent("GROUP_ROSTER_UPDATE") end
  if o.role then
    frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    frame:RegisterEvent("PARTY_LEADER_CHANGED")
  end
  if isBoss(unit) then
    -- UNVERIFIED (check in client): INSTANCE_ENCOUNTER_ENGAGE_UNIT fires when
    -- boss1-5 change, UNIT_TARGETABLE_CHANGED as a unit event for a boss.
    frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    frame:RegisterUnitEvent("UNIT_TARGETABLE_CHANGED", unit)
  end
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:SetScript("OnEvent", onEvent)
end

-- o = { unit, name (global frame name), mirror, castBar, auras, badge (px or
-- nil), and for group members: key (combat key, default spec.id), parent
-- (default UIParent), member (spec.frame is not set), sample (function(frame)
-- -> sample table or nil), castGap (px, default L.below), auraMode ("rows" |
-- "line"), auraSide (nil | "right" | "left"), range, role, dispel, roster
-- (the unit changes with the group roster) }. Boss units (boss1-5) take the
-- encounter events.
function Base.create(spec, o)
  local unit = o.unit
  local key = o.key or spec.id
  -- UNVERIFIED (check in client): "*type2" = "togglemenu" opens the unit
  -- menu on Forever.
  local frame = CreateFrame("Button", o.name, o.parent or UIParent, "SecureUnitButtonTemplate")
  frame.id, frame.spec, frame.unit, frame.key = spec.id, spec, unit, key
  -- Every field set (false for "none"), so a lookup never reaches the
  -- frame's own methods.
  frame.mirror, frame.badge = o.mirror and true or false, o.badge or false
  frame.combat = InCombatLockdown() and true or false
  frame.hover, frame.sampling, frame.castHolder = false, false, false
  -- Pixels kept free under the frame (Base.reserveBelow).
  frame.reserved = 0
  frame.L, frame.hasPower, frame.cast, frame.auras = false, false, false, false
  frame.slotOn, frame.range = true, o.range and true or false
  frame.castGap, frame.auraSide = o.castGap or false, o.auraSide or false
  frame.sampleFn, frame.sampleState = o.sample or false, false
  frame.role, frame.dispel = false, false
  -- The plain dead / offline flags of the last update (Base.update).
  frame.deadState, frame.offlineState = false, false
  if not o.member then spec.frame = frame end
  ns.Combat.after("unit:" .. key .. ":init", function()
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    frame:RegisterForClicks("AnyUp")
  end)

  local Parts = ns.Units.Parts
  frame.panel = Parts.Panel.create(frame)
  frame.ring = Parts.Ring.create(frame)
  frame.bars = Parts.Bars.create(frame)
  if o.castBar then frame.cast = Parts.CastBar.create(frame, unit) end
  if o.auras then frame.auras = Parts.Auras.create(frame, unit, o.auraMode) end
  -- Frame levels: Ring +5, Role +6 (badge and crown over the ring), Dispel
  -- +7 (the glow over the panel and bars).
  if o.role then frame.role = Parts.Role.create(frame) end
  if o.dispel then frame.dispel = Parts.Dispel.create(frame, unit) end

  frame:HookScript("OnEnter", function(self)
    self.hover = true
    Base.fade(self)
    if editing(self) then return end
    local tip = _G.GameTooltip
    if tip then
      if type(_G.GameTooltip_SetDefaultAnchor) == "function" then GameTooltip_SetDefaultAnchor(tip, self) end
      tip:SetUnit(self.unit)
    end
  end)
  frame:HookScript("OnLeave", function(self)
    self.hover = false
    Base.fade(self)
    local tip = _G.GameTooltip
    if tip and type(tip.IsOwned) == "function" and tip:IsOwned(self) then tip:Hide() end
  end)

  -- Shown by the state driver (a new unit): its values at once, not from
  -- the last unit it showed.
  frame:HookScript("OnShow", function(self) Base.update(self) end)

  registerEvents(frame, unit, o)
  if unit == "targettarget" then
    -- No unit events for targettarget: a refresh every THROTTLE s while
    -- shown; values only while the GUID stays the same (a secret or missing
    -- GUID counts as new).
    frame.elapsed, frame.guid = 0, false
    frame:HookScript("OnUpdate", function(self, elapsed)
      self.elapsed = self.elapsed + (elapsed or 0)
      if self.elapsed < THROTTLE then return end
      self.elapsed = 0
      local guid = maybe(_G.UnitGUID, self.unit)
      if guid == nil or ns.Util.isSecret(guid) then
        self.guid = false
        Base.update(self)
      elseif guid ~= self.guid then
        self.guid = guid
        Base.update(self)
      else
        Base.update(self, true)
      end
    end)
  end
  return frame
end

-- A frame turned off (Edit Mode checklist, or its group slot hidden): sample
-- off, state driver gone, hidden (out of combat; under both secure keys, so
-- a queued apply or Edit Mode show can't bring it back).
local function turnOff(frame)
  if frame.sampling then sample(frame, false) end
  frame.sampling = false
  local function off()
    UnregisterStateDriver(frame, "visibility")
    frame:Hide()
  end
  ns.Combat.after("unit:" .. frame.key, off)
  ns.Combat.after("unit:" .. frame.key .. ":edit", off)
end

-- Reads every option and lays one frame out (out of combat), then the
-- values and the opacity. A frame turned off only hides.
function Base.applyFrame(frame)
  if not enabled(frame) then
    turnOff(frame)
    return
  end
  local key = "unit:" .. frame.key
  if editing(frame) then
    -- Turned back on while Edit Mode is open: the sample, as on enter.
    if not frame.sampling then Base.editModeFrame(frame, true) end
  else
    -- A turn-off queued earlier in this combat also waits under ":edit";
    -- replace it, so it can't hide the frame after this apply.
    ns.Combat.after(key .. ":edit", function() end)
  end
  ns.Combat.after(key, function()
    local skin = skinOf(frame)
    local w, h = opt(frame, "width"), opt(frame, "height")
    local L = ns.UnitLayout.frame({
      w = w, h = h, powerH = opt(frame, "powerHeight") or 0,
      portraitScale = opt(frame, "portraitScale") or 100, mirror = frame.mirror,
      edge = ns.UnitLayout.edgeWidth(skin.border), badge = frame.badge or nil,
      role = frame.role and true or nil,
    })
    frame.L = L
    frame.hasPower = L.power ~= nil
    frame:SetSize(w, h)
    frame.panel:layout({ skin = skin })
    frame.ring:layout(L, { skin = skin })
    frame.bars:layout(L, { texture = opt(frame, "barTexture"), fontSize = opt(frame, "fontSize"),
      showName = opt(frame, "showName"), mirror = frame.mirror, skin = skin })
    if frame.role then frame.role:layout(L, { skin = skin }) end
    if frame.dispel then frame.dispel:layout() end

    local cast = frame.cast
    if cast then
      if castOn(frame) then
        cast:layout({ width = opt(frame, "castWidth"), height = opt(frame, "castHeight"),
          icon = opt(frame, "castIcon"), skin = skin, texture = opt(frame, "barTexture") })
        if frame.sampling and not cast.sampling then cast:sample(true) end
      else
        if cast.sampling then cast:sample(false) end
        cast.frame:Hide()
      end
      placeCast(frame)
    end
    if frame.auras then
      -- Beside the frame on the left the auras grow leftward; on the right
      -- rightward; under it they follow the portrait side.
      local side = frame.auraSide
      frame.auras:layout({ size = opt(frame, "auraSize"), rows = opt(frame, "auraRows"), width = w,
        buffs = opt(frame, "buffs"), debuffs = opt(frame, "debuffs"), onlyMine = opt(frame, "onlyMine"),
        mirror = side == "left" or (not side and frame.mirror) })
      placeAuras(frame)
    end

    if frame.sampling then
      sample(frame, true)
    else
      -- UNVERIFIED (check in client): the [petbattle] / [vehicleui] state
      -- driver conditions on a SecureUnitButtonTemplate frame.
      RegisterStateDriver(frame, "visibility", visibility(frame))
      Base.update(frame)
    end
  end)
  Base.fade(frame)
end

function Base.apply(spec)
  if spec.frame then Base.applyFrame(spec.frame) end
end

-- Edit Mode open (true) / closed (false): the frame shows a sample while
-- open; on close the state driver and the real values come back.
function Base.editModeFrame(frame, active)
  if not enabled(frame) then
    turnOff(frame)
    return
  end
  local key = "unit:" .. frame.key .. ":edit"
  if active then
    frame.sampling = true
    ns.Combat.after(key, function()
      UnregisterStateDriver(frame, "visibility")
      frame:Show()
    end)
    sample(frame, true)
  else
    sample(frame, false)
    frame.sampling = false
    ns.Combat.after(key, function()
      if not frame.sampling then RegisterStateDriver(frame, "visibility", visibility(frame)) end
    end)
    Base.update(frame)
    -- A cast that started while the sample showed.
    if castOn(frame) then frame.cast:update("PLAYER_ENTERING_WORLD", frame.unit) end
  end
  Base.fade(frame)
end

function Base.editMode(spec, active)
  if spec.frame then Base.editModeFrame(spec.frame, active) end
end

local function hiddenFrame()
  if not hiddenParent then
    hiddenParent = CreateFrame("Frame")
    hiddenParent:Hide()
  end
  return hiddenParent
end

-- The child bars of Blizzard unit frames that register their own events.
local CHILDREN = { "healthbar", "manabar", "spellbar", "totFrame", "powerBarAlt" }

-- Hides `f` now unless it is protected and we are in combat (then after).
local function hideNow(f, key)
  local protected = type(f.IsProtected) == "function" and f:IsProtected()
  if not protected or not InCombatLockdown() then
    f:Hide()
  else
    ns.Combat.after(key, function() f:Hide() end)
  end
end

-- Hides Blizzard frames by name, once each, out of combat: events off (also
-- on their child bars), reparented to our hidden frame, hidden again
-- whenever they show and parked again whenever something reparents them
-- (Edit Mode layout switches, "lock to player frame"). A frame that does
-- not exist yet is tried again by a later call.
-- UNVERIFIED (check in client): hiding PlayerFrame / TargetFrame / FocusFrame
-- / PetFrame / PlayerCastingBarFrame this way causes no taint.
function Base.hideBlizzard(names)
  for _, name in ipairs(names) do
    local key = "hide:" .. name
    ns.Combat.after(key, function()
      local f = _G[name]
      if hidden[name] or type(f) ~= "table" then return end
      hidden[name] = true
      local parent = hiddenFrame()
      f:UnregisterAllEvents()
      for _, child in ipairs(CHILDREN) do
        local c = rawget(f, child)
        if type(c) == "table" and type(c.UnregisterAllEvents) == "function" then
          pcall(c.UnregisterAllEvents, c)
        end
      end
      f:SetParent(parent)
      f:Hide()
      hooksecurefunc(f, "Show", function(self) hideNow(self, key .. ":show") end)
      local parking = false
      hooksecurefunc(f, "SetParent", function(self, p)
        if parking or p == parent then return end
        ns.Combat.after(key .. ":parent", function()
          parking = true
          self:SetParent(parent)
          parking = false
        end)
      end)
    end)
  end
end

ns.Units.Base = Base
