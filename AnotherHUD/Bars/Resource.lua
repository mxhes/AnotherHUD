local ADDON, ns = ...

-- The class resource bar (combo points, holy power, runes, soul shards, chi,
-- arcane charges, essence): a plain frame (AnotherHUDResourceBar) holding a
-- Bars/Segments widget. A child of `player` (off with it, not in the
-- checklist); its options are the Player's Resource Bar section.
-- Attached (the default): the bar hangs under the Player frame, right of the
-- portrait ring and as wide as the health / power column, and the Player
-- keeps that space free (Base.reserveBelow), so its cast bar and auras move
-- down. Detach resource bar: the bar sits on the holder
-- (AnotherHUDResourceBarHolder), which Edit Mode moves like any module; the
-- holder is hidden otherwise, so Edit Mode can't select it. Anchors, sizes,
-- parents and the holder's show go through Combat.after("bar:resource"); the
-- bar's own Show / Hide (Druid forms) runs at once, also in combat. Client
-- values: whole points and fragments only travel into the widget; rune
-- times, partial essence and the regeneration rate are read only when plain
-- (the rules in Core/Resource.lua).
local Resource = ns.Resource
local Util = ns.Util

local function plain(v)
  return not Util.isSecret(v) and Util.isNumber(v)
end

local function editing(spec)
  local glue = ns.EditMode and ns.EditMode.Glue
  return spec.sampling or (glue ~= nil and glue.inEditMode()) or false
end

-- The player's resource now (nil: none for this class / spec).
-- UNVERIFIED (check in client): GetSpecialization() answers the 1-based spec
-- index on Forever.
local function currentDef()
  local spec = type(_G.GetSpecialization) == "function" and _G.GetSpecialization() or nil
  return Resource.forPlayer(select(2, UnitClass("player")), spec)
end

local function powerType(def)
  local E = _G.Enum
  return E and E.PowerType and E.PowerType[def.power] or nil
end

local function powerToken()
  local _, token = UnitPowerType("player")
  if Util.isSecret(token) then return nil end
  return token
end

local function isOn(spec)
  return spec.def ~= nil and ns.Modules.isEnabled("resource")
    and ns.Options.get("player", "showResource") == true
end

local function segmentCount(def)
  local ptype = powerType(def)
  local max = ptype and UnitPowerMax("player", ptype) or nil
  return Resource.count(max, def.fallback)
end

-- The bar's own show: on and the resource active now (Druids: Cat Form), or
-- Edit Mode open. Not secure: also in combat.
-- UNVERIFIED (check in client): Show / Hide of the plain bar parented to the
-- secure Player frame is allowed in combat.
local function refreshShown(spec)
  local bar = spec.bar
  if isOn(spec) and (editing(spec) or Resource.active(spec.def, powerToken())) then
    bar:Show()
  else
    bar:Hide()
  end
end

-- The recharge ticker: an OnUpdate that refreshes every tick seconds while
-- a rune recharges or essence regenerates.
local update

local function setTicker(spec, busy)
  busy = busy and true or false
  if busy == spec.ticking then return end
  spec.ticking = busy
  if not busy then
    spec.bar:SetScript("OnUpdate", nil)
    return
  end
  spec.elapsed = 0
  spec.bar:SetScript("OnUpdate", function(_, elapsed)
    spec.elapsed = spec.elapsed + (elapsed or 0)
    if spec.elapsed < ns.Theme.sizes.resource.tick then return end
    spec.elapsed = 0
    update(spec)
  end)
end

-- UNVERIFIED (check in client): GetRuneCooldown(i) answers start, duration,
-- ready (GetTime seconds), any of them secret in restricted contexts.
local function runes(spec, seg, timers)
  local list = {}
  for i = 1, seg.count do
    local start, duration, ready = GetRuneCooldown(i)
    if not plain(start) then start = nil end
    if not plain(duration) then duration = nil end
    if Util.isSecret(ready) or type(ready) ~= "boolean" then ready = nil end
    list[i] = { start, duration, ready }
  end
  local busy = false
  for i, r in ipairs(Resource.runes(list, GetTime())) do
    seg:setSlot(i, r.fill, timers and r.left)
    if r.fill < 1 and r.left then busy = true end
  end
  return busy
end

-- UNVERIFIED (check in client): UnitPartialPower("player", Essence) answers
-- the next point's progress 0..1000 and GetPowerRegenForPowerType(Essence)
-- the points regenerated per second (first return).
local function essence(seg, ptype, timers)
  local points = UnitPower("player", ptype)
  seg:setPoints(points)
  seg:clearPartials()
  local e = Resource.essence(points, seg.count, UnitPartialPower("player", ptype),
    (GetPowerRegenForPowerType(ptype)))
  if not e then return false end
  seg:setPartial(e.index, e.fill, timers and e.left)
  return true
end

-- The client's values into the segments (not while the sample shows).
update = function(spec)
  local def, seg = spec.def, spec.seg
  if not def or spec.sampling or seg.count < 1 then
    setTicker(spec, false)
    return
  end
  local ptype = powerType(def)
  if not ptype then return end
  local timers = ns.Options.get("player", "resourceTimers") == true
  local busy = false
  if def.mode == "points" then
    seg:setPoints(UnitPower("player", ptype))
  elseif def.mode == "fragments" then
    seg:setPoints(UnitPower("player", ptype))
    -- UNVERIFIED (check in client): UnitPower("player", SoulShards, true)
    -- answers the unmodified fragments and UnitPowerDisplayMod(SoulShards)
    -- the fragments per shard (10).
    local mod = UnitPowerDisplayMod(ptype)
    if not plain(mod) or mod <= 0 then mod = 10 end
    seg:setFragments(UnitPower("player", ptype, true), mod)
  elseif def.mode == "runes" then
    busy = runes(spec, seg, timers)
  elseif def.mode == "essence" then
    busy = essence(seg, ptype, timers)
  end
  setTicker(spec, busy)
end

-- The Edit Mode sample: three points and, for runes / essence, the fourth
-- segment recharging (as the approved mockup).
local SAMPLE = { points = 3, partial = 4, fill = 0.55, left = 2 }

local function sample(spec)
  local seg = spec.seg
  if not spec.def or seg.count < 1 then return end
  setTicker(spec, false)
  seg:setPoints(SAMPLE.points)
  seg:clearPartials()
  local mode = spec.def.mode
  if (mode == "runes" or mode == "essence") and SAMPLE.partial <= seg.count then
    seg:setPartial(SAMPLE.partial, SAMPLE.fill, SAMPLE.left)
  end
end

local function skinOf()
  local id = ns.Options.get("player", "skin")
  return (type(id) == "string" and ns.Theme.skin(string.lower(id))) or ns.Theme.skins.classic
end

-- Reads every option: places the bar (attached / detached / off), lays the
-- segments out and keeps the space under the Player frame; then the values
-- and the bar's show.
local function apply(spec)
  local holder, bar, seg = spec.frame, spec.bar, spec.seg
  if not holder then return end
  local get = ns.Options.get
  local player = ns.Modules.get("player")
  local pframe = player and player.frame
  local on = isOn(spec) and pframe ~= nil
  local attached = on and get("player", "resourceDetach") ~= true
  local def = spec.def
  spec.count = def and segmentCount(def) or 0
  local count = spec.count
  ns.Combat.after("bar:resource", function()
    local w, h
    holder:SetSize(get("player", "resourceWidth"), get("player", "resourceHeight"))
    if attached and pframe.L then
      local box = Resource.attached(pframe.L)
      w, h = box.w, box.h
      bar:SetParent(pframe)
      bar:ClearAllPoints()
      bar:SetPoint("TOPLEFT", pframe, "BOTTOMLEFT", box.x, -ns.Theme.sizes.resource.gap)
      bar:SetSize(w, h)
      -- UNVERIFIED (check in client): LibEditMode does not show or select a
      -- registered frame while it is hidden.
      holder:Hide()
    elseif on and not attached then
      w, h = get("player", "resourceWidth"), get("player", "resourceHeight")
      bar:SetParent(holder)
      bar:ClearAllPoints()
      bar:SetAllPoints(holder)
      bar:SetSize(w, h)
      holder:Show()
    else
      holder:Hide()
      bar:Hide()
    end
    if w and count >= 1 then
      seg:layout({ w = w, h = h, count = count, skin = skinOf(), texture = get("player", "barTexture"),
        rgb = ns.Theme.resourceColors[def.color] })
    end
  end)
  if pframe then
    ns.Units.Base.reserveBelow(pframe, attached and Resource.reserve(ns.Theme.sizes.resource.attachedHeight) or 0)
  end
  if editing(spec) and on then sample(spec) else update(spec) end
  refreshShown(spec)
end

-- A new spec or the world: the resource may have changed.
local function refreshDef(spec)
  spec.def = currentDef()
  apply(spec)
end

local SHOWN = { UNIT_DISPLAYPOWER = true, UPDATE_SHAPESHIFT_FORM = true }

local function onEvent(spec, event)
  if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
    refreshDef(spec)
    return
  end
  if not spec.def then return end
  if event == "UNIT_MAXPOWER" and segmentCount(spec.def) ~= spec.count then
    apply(spec)
    return
  end
  if SHOWN[event] then refreshShown(spec) end
  update(spec)
end

local UNIT_EVENTS = { "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
  "PLAYER_SPECIALIZATION_CHANGED" }
-- UNVERIFIED (check in client): RUNE_POWER_UPDATE fires on Forever when a
-- rune starts or ends recharging.
local EVENTS = { "UPDATE_SHAPESHIFT_FORM", "RUNE_POWER_UPDATE", "PLAYER_ENTERING_WORLD" }

ns.Modules.define({
  id = "resource", label = "Player Resource Bar", kind = "bar", parent = "player",
  defaults = {}, settings = {},
  defaultPosition = { point = "CENTER", x = 0, y = -240 },
  create = function(spec)
    local holder = CreateFrame("Frame", "AnotherHUDResourceBarHolder", UIParent)
    holder:Hide()
    local bar = CreateFrame("Frame", "AnotherHUDResourceBar", UIParent)
    bar:Hide()
    spec.frame, spec.bar = holder, bar
    spec.seg = ns.Bars.Segments.create(bar)
    spec.sampling, spec.ticking, spec.elapsed, spec.count = false, false, 0, 0
    for _, ev in ipairs(UNIT_EVENTS) do bar:RegisterUnitEvent(ev, "player") end
    for _, ev in ipairs(EVENTS) do bar:RegisterEvent(ev) end
    bar:SetScript("OnEvent", function(_, event) onEvent(spec, event) end)
    spec.def = currentDef()
    apply(spec)
  end,
  apply = function(spec) apply(spec) end,
  -- Edit Mode open: the sample (also while the resource is inactive); closed:
  -- the real values and show come back.
  onEditMode = function(spec, active)
    if not spec.bar then return end
    spec.sampling = active and true or false
    if spec.sampling and isOn(spec) then
      sample(spec)
    else
      spec.seg:clearPartials()
      update(spec)
    end
    refreshShown(spec)
  end,
})
