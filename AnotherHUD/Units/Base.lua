local ADDON, ns = ...

-- The unit frame base the unit modules share: a SecureUnitButtonTemplate
-- button (left click targets, right click opens the unit menu) holding the
-- drawn parts (Units/Parts), the unit's events, the Edit Mode sample, fading
-- and hiding Blizzard's frames. Client values (health, power, name, level,
-- ...) only travel into the parts; flags are read only when plain. Every
-- change to the secure button (attributes, size, anchors, state driver,
-- show) goes through Combat.after.
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
  targettarget = { "UNIT_TARGET", "target" },
  pet = { "UNIT_PET", "player" },
}

local PORTRAIT = { UNIT_PORTRAIT_UPDATE = true, UNIT_MODEL_CHANGED = true }
-- Frequent events: values and texts only (no colors, portrait, level).
local VALUES = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_POWER_UPDATE = true,
  UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true }
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
  if type(f) == "function" then return f(v) end
  return v
end

local function plainBool(v)
  if ns.Util.isSecret(v) or type(v) ~= "boolean" then return nil end
  return v
end

local function skinOf(frame)
  local id = opt(frame, "skin")
  local skins = ns.Theme.skins
  return (type(id) == "string" and skins[string.lower(id)]) or skins.classic
end

local function castOn(frame)
  return frame.cast and opt(frame, "castBar") == true or false
end

local function visibility(frame)
  return ns.UnitState.visibility(frame.unit, opt(frame, "showInVehicle"))
end

-- Opacity (SetAlpha is not protected: it may run in combat).
function Base.fade(frame)
  frame:SetAlpha(ns.UnitState.alpha({
    editMode = editing(frame),
    inCombat = frame.combat or InCombatLockdown(),
    hover = frame.hover,
    outOfCombat = opt(frame, "outOfCombat"),
    mouseover = opt(frame, "mouseover"),
  }))
end

-- Everything from the client into the parts (valuesOnly: bars and texts,
-- not the colors, portrait and level). No unit: texts cleared, nothing else
-- read.
function Base.update(frame, valuesOnly)
  if frame.sampling then return end
  local unit, bars, ring = frame.unit, frame.bars, frame.ring
  if not UnitExists(unit) then
    bars:setTexts("", "", {}, "", {})
    ring:setLevel("", {})
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
  local healthFmt, healthArgs = ns.UnitText.bar(opt(frame, "healthText") or "None",
    { cur = hp, max = hpMax, pct = hpPct, dead = dead, offline = offline }, abbr)

  local powerFmt, powerArgs, powerRGB = "", {}, nil
  if frame.hasPower then
    local pw, pwMax = UnitPower(unit), UnitPowerMax(unit)
    local ptype, token = UnitPowerType(unit)
    if ns.Util.isSecret(token) then token = nil end
    local pwPct = maybe(_G.UnitPowerPercent, unit, ptype, false, scale)
    bars:setPower(pw, pwMax)
    powerFmt, powerArgs = ns.UnitText.bar(opt(frame, "powerText") or "None",
      { cur = pw, max = pwMax, pct = pwPct, dead = dead, offline = offline }, abbr)
    powerRGB = { ns.UnitColor.power(token) }
  end

  bars:setTexts((UnitName(unit)), healthFmt, healthArgs, powerFmt, powerArgs)
  if valuesOnly then return end

  local r, g, b = ns.UnitColor.health({
    isPlayer = UnitIsPlayer(unit), class = select(2, UnitClass(unit)),
    reaction = UnitReaction(unit, "player"), classColor = opt(frame, "classColor"),
  })
  bars:setColors({ r, g, b }, powerRGB)

  ring:setColors(ns.UnitColor.ring(UnitClassification(unit)))
  ring:setUnit(unit)
  local level = type(_G.UnitEffectiveLevel) == "function" and _G.UnitEffectiveLevel or UnitLevel
  ring:setLevel(ns.UnitText.level(level(unit)))
end

-- The Edit Mode sample: plain values into the parts (cast bar and auras
-- draw their own).
local function sample(frame, on)
  if castOn(frame) then frame.cast:sample(on) end
  if frame.auras then frame.auras:sample(on) end
  if not on then return end
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

-- Places the auras: under an attached cast bar (auraBelowCast between), else
-- L.below under the frame. Plain frames, but anchored to the secure button:
-- callers run it inside Combat.after.
local function placeAuras(frame)
  local auras, L = frame.auras, frame.L
  if not auras or not L then return end
  local mirror = frame.mirror
  local top, bottom = mirror and "TOPRIGHT" or "TOPLEFT", mirror and "BOTTOMRIGHT" or "BOTTOMLEFT"
  auras.frame:ClearAllPoints()
  if castOn(frame) and not frame.castHolder then
    auras.frame:SetPoint(top, frame.cast.frame, bottom, 0, -ns.Theme.sizes.unit.auraBelowCast)
  else
    auras.frame:SetPoint(top, frame, bottom, 0, -L.below)
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
    cast.frame:SetPoint(top, frame, bottom, 0, -L.below)
  end
  placeAuras(frame)
end

-- Moves the cast bar onto `holder` (a detached cast bar's frame), or back
-- under the frame (holder nil).
function Base.anchorCast(frame, holder)
  frame.castHolder = holder or false
  ns.Combat.after("unit:" .. frame.id .. ":cast", function() placeCast(frame) end)
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
  Base.update(frame, VALUES[event] or false)
  if VALUES[event] then return end
  -- A new unit (or the world): its cast, if any.
  local unitEvent = string.sub(event, 1, 5) == "UNIT_"
  if castOn(frame) and (not unitEvent or event == "UNIT_TARGET" or event == "UNIT_PET") then
    frame.cast:update(event, frame.unit)
  end
end

local function registerEvents(frame, unit, castBar)
  if unit ~= "targettarget" then
    for _, ev in ipairs(UNIT_EVENTS) do frame:RegisterUnitEvent(ev, unit) end
    if castBar then
      for _, ev in ipairs(ns.Units.Parts.CastBar.EVENTS) do frame:RegisterUnitEvent(ev, unit) end
    end
  end
  local change = CHANGE[unit]
  if change then
    if change[2] then frame:RegisterUnitEvent(change[1], change[2]) else frame:RegisterEvent(change[1]) end
  end
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:SetScript("OnEvent", onEvent)
end

-- o = { unit, name (global frame name), mirror, castBar, auras, badge (px or nil) }.
function Base.create(spec, o)
  local unit = o.unit
  -- UNVERIFIED (check in client): "*type2" = "togglemenu" opens the unit
  -- menu on Forever.
  local frame = CreateFrame("Button", o.name, UIParent, "SecureUnitButtonTemplate")
  frame.id, frame.spec, frame.unit = spec.id, spec, unit
  -- Every field set (false for "none"), so a lookup never reaches the
  -- frame's own methods.
  frame.mirror, frame.badge = o.mirror and true or false, o.badge or false
  frame.combat = InCombatLockdown() and true or false
  frame.hover, frame.sampling, frame.castHolder = false, false, false
  frame.L, frame.hasPower, frame.cast, frame.auras = false, false, false, false
  spec.frame = frame
  ns.Combat.after("unit:" .. spec.id .. ":init", function()
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    frame:RegisterForClicks("AnyUp")
  end)

  frame.panel = ns.Units.Parts.Panel.create(frame)
  frame.ring = ns.Units.Parts.Ring.create(frame)
  frame.bars = ns.Units.Parts.Bars.create(frame)
  if o.castBar then frame.cast = ns.Units.Parts.CastBar.create(frame, unit) end
  if o.auras then frame.auras = ns.Units.Parts.Auras.create(frame, unit) end

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

  registerEvents(frame, unit, o.castBar)
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

-- Reads every option and lays the frame out (out of combat), then the
-- values and the opacity.
function Base.apply(spec)
  local frame = spec.frame
  if not frame then return end
  ns.Combat.after("unit:" .. spec.id, function()
    local skin = skinOf(frame)
    local w, h = opt(frame, "width"), opt(frame, "height")
    local L = ns.UnitLayout.frame({
      w = w, h = h, powerH = opt(frame, "powerHeight") or 0,
      portraitScale = opt(frame, "portraitScale") or 100, mirror = frame.mirror,
      edge = ns.UnitLayout.edgeWidth(skin.border), badge = frame.badge or nil,
    })
    frame.L = L
    frame.hasPower = L.power ~= nil
    frame:SetSize(w, h)
    frame.panel:layout(L, { skin = skin })
    frame.ring:layout(L, { skin = skin })
    frame.bars:layout(L, { texture = opt(frame, "barTexture"), fontSize = opt(frame, "fontSize"),
      showName = opt(frame, "showName"), mirror = frame.mirror, skin = skin })

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
      frame.auras:layout({ size = opt(frame, "auraSize"), rows = opt(frame, "auraRows"), width = w,
        buffs = opt(frame, "buffs"), debuffs = opt(frame, "debuffs"), onlyMine = opt(frame, "onlyMine"),
        mirror = frame.mirror })
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

-- Edit Mode open (true) / closed (false): the frame shows a sample while
-- open; on close the state driver and the real values come back.
function Base.editMode(spec, active)
  local frame = spec.frame
  if not frame then return end
  local key = "unit:" .. spec.id .. ":edit"
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
