local ADDON, ns = ...

-- The minimap: a plain frame (AnotherHUDMinimap on UIParent, the Edit Mode
-- frame) holding Blizzard's Minimap, inset by the skin border. Square shows
-- the skin panel around a square-masked map; Round masks the map round inside
-- the skin ring (Units/Parts/Ring). The mouse wheel zooms (Mouse wheel zoom). Blizzard's
-- MinimapCluster (border, zone text, clock, buttons) is hidden.
-- Every change to Blizzard's frames runs out of combat (Combat.after); hooks
-- on Minimap:SetParent / SetPoint put the map back when Blizzard moves it.
-- Turned off, the map goes back to where Blizzard had it.
local Rules = ns.MinimapRules
local unpack = unpack or rawget(table, "unpack")

local ID = "minimap"

local function opt(key)
  return ns.Options.get(ID, key)
end

local function blizzardMap()
  local m = _G.Minimap
  if type(m) == "table" then return m end
  return nil
end

-- Blizzard's parent, anchors and size of the map, once, before the first move.
local function remember(spec, m)
  if spec.original then return end
  local points = {}
  local n = m:GetNumPoints()
  if type(n) == "number" then
    for i = 1, n do points[i] = { m:GetPoint(i) } end
  end
  spec.original = { parent = m:GetParent(), points = points, width = m:GetWidth(), height = m:GetHeight() }
end

local function restore(spec, m)
  local o = spec.original
  if not o then return end
  m:SetParent(o.parent)
  m:ClearAllPoints()
  for _, p in ipairs(o.points) do m:SetPoint(unpack(p)) end
  if o.width and o.height then m:SetSize(o.width, o.height) end
  m:SetMaskTexture(Rules.mask("Round"))
end

-- UNVERIFIED (check in client): Minimap can be re-parented, anchored and
-- sized from addon code out of combat without taint, and keeps drawing,
-- clicking (pings) and tracking inside our frame.
local function place(spec)
  ns.Combat.after("minimap:map", function()
    local m, frame = blizzardMap(), spec.frame
    if not m or not frame then return end
    spec.placing = true
    local ok, err = pcall(function()
      if ns.Modules.isEnabled(ID) then
        remember(spec, m)
        local e = spec.edge or 0
        local inner = opt("size") - 2 * e
        m:SetParent(frame)
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", frame, "TOPLEFT", e, -e)
        m:SetSize(inner, inner)
      else
        restore(spec, m)
      end
    end)
    spec.placing = false
    if not ok then error(err, 0) end
  end)
end

-- UNVERIFIED (check in client): SetMaskTexture with Rules.mask's paths gives
-- a square / round map.
local function mask(spec)
  ns.Combat.after("minimap:mask", function()
    local m = blizzardMap()
    if not m or not spec.frame or not ns.Modules.isEnabled(ID) then return end
    spec.masking = true
    local ok, err = pcall(m.SetMaskTexture, m, Rules.mask(opt("shape")))
    spec.masking = false
    if not ok then error(err, 0) end
  end)
end

-- Blizzard's art and buttons that travel with the map (children of Minimap
-- and of MinimapBackdrop, Minimap.xml), seen on Forever 2026-11-28: the ring
-- (MinimapCompassTexture and its underlay), the zoom buttons and their hover
-- area, the expansion and event buttons.
-- The ring and the zoom buttons only go invisible and mouse-less: Blizzard's
-- wheel zooms through Minimap.ZoomIn:Click() / ZoomOut:Click().
-- UNVERIFIED (check in client): Click() on them still zooms at alpha 0.
local function keepHidden(f)
  if type(f) ~= "table" then return end
  f:Hide()
  local function hide(self) self:Hide() end
  hooksecurefunc(f, "Show", hide)
  hooksecurefunc(f, "SetShown", hide)
end

local function unseen(f)
  if type(f) ~= "table" then return end
  f:SetAlpha(0)
  if f.EnableMouse then f:EnableMouse(false) end
end

local function hideMapArt(m)
  ns.Combat.after("minimap:art", function()
    unseen(_G.MinimapCompassTexture)
    unseen(_G.MinimapCompassTextureUnderlay)
    unseen(m.ZoomIn)
    unseen(m.ZoomOut)
    unseen(m.ZoomHitArea)
    keepHidden(_G.ExpansionLandingPageMinimapButton)
    local backdrop = _G.MinimapBackdrop
    keepHidden(type(backdrop) == "table" and backdrop.ExternalEventURLButton or nil)
  end)
end

local function call(name, ...)
  local f = _G[name]
  if type(f) == "function" then return f(...) end
  return nil
end

local function flag(v)
  return not ns.Util.isSecret(v) and v == true
end

local function plainNumber(v)
  return not ns.Util.isSecret(v) and ns.Util.isNumber(v)
end

-- UNVERIFIED (check in client): GetMinimapZoneText() answers the zone /
-- subzone name the minimap shows; C_PvP.GetZonePVPInfo() (or the older
-- GetZonePVPInfo()) answers the PvP type first ("sanctuary", "friendly",
-- "hostile", "contested", "arena", "combat" or nil).
local function updateZone(spec)
  spec.zone:SetText(ns.Util.plainString(call("GetMinimapZoneText")) or "")
  local pvp
  local C = _G.C_PvP
  if type(C) == "table" and type(C.GetZonePVPInfo) == "function" then
    pvp = C.GetZonePVPInfo()
  else
    pvp = call("GetZonePVPInfo")
  end
  local c = Rules.zoneColor(ns.Util.plainString(pvp))
  spec.zone:SetTextColor(c[1], c[2], c[3])
end

-- UNVERIFIED (check in client): Blizzard's clock settings are the CVars
-- timeMgrUseLocalTime and timeMgrUseMilitaryTime (GetCVarBool); realm time
-- from GetGameTime() (hour, minute).
local function updateClock(spec)
  local hour, minute
  if flag(call("GetCVarBool", "timeMgrUseLocalTime")) then
    local t = date("*t")
    hour, minute = t.hour, t.min
  else
    hour, minute = call("GetGameTime")
  end
  spec.clock:SetText(Rules.clockText(hour, minute, flag(call("GetCVarBool", "timeMgrUseMilitaryTime"))))
end

-- UNVERIFIED (check in client): C_Map.GetBestMapForUnit("player") and
-- C_Map.GetPlayerMapPosition(id, "player") (nil in instances) with :GetXY().
local function updateCoords(spec)
  local text = ""
  local C = _G.C_Map
  if type(C) == "table" and type(C.GetBestMapForUnit) == "function" then
    local id = C.GetBestMapForUnit("player")
    local pos = id ~= nil and C.GetPlayerMapPosition(id, "player") or nil
    if type(pos) == "table" and type(pos.GetXY) == "function" then
      text = Rules.coordText(pos:GetXY())
    end
  end
  spec.coords:SetText(text)
end

-- UNVERIFIED (check in client): C_Calendar.GetNumPendingInvites() answers
-- the number of invites waiting.
local function updateCalendar(spec)
  local C = _G.C_Calendar
  local n = type(C) == "table" and type(C.GetNumPendingInvites) == "function" and C.GetNumPendingInvites() or nil
  spec.calendar:setGlow(plainNumber(n) and n > 0)
end

local function updateAll(spec)
  updateZone(spec)
  updateClock(spec)
  updateCoords(spec)
  updateCalendar(spec)
end

-- One OnUpdate for the clock and the coordinates, only while one of them shows.
local function ticker(spec, on)
  if not on then
    spec.elements:SetScript("OnUpdate", nil)
    return
  end
  local S = ns.Theme.sizes.minimap
  spec.clockAcc, spec.coordAcc = 0, 0
  spec.elements:SetScript("OnUpdate", function(_, elapsed)
    if opt("showClock") == true then
      spec.clockAcc = spec.clockAcc + elapsed
      if spec.clockAcc >= S.clockTick then
        spec.clockAcc = 0
        updateClock(spec)
      end
    end
    if opt("showCoords") == true then
      spec.coordAcc = spec.coordAcc + elapsed
      if spec.coordAcc >= S.coordTick then
        spec.coordAcc = 0
        updateCoords(spec)
      end
    end
  end)
end

local function showIf(on, ...)
  for i = 1, select("#", ...) do
    local f = select(i, ...)
    if on then f:Show() else f:Hide() end
  end
end

-- The elements around the map: anchors on the frame edges, fixed sizes
-- (mockup 7); each shown by its option.
local function layoutElements(spec, skin)
  local T = ns.Theme
  local S = T.sizes.minimap
  local frame = spec.frame
  spec.zone:ClearAllPoints()
  spec.zone:SetPoint("BOTTOM", frame, "TOP", 0, S.textGap)
  spec.zone:SetFont(T.fonts.file, S.zoneFont, "OUTLINE")
  spec.clock:ClearAllPoints()
  spec.clock:SetPoint("TOP", frame, "BOTTOM", -S.clockShift, -S.textGap)
  spec.clock:SetFont(T.fonts.file, S.clockFont, "OUTLINE")
  spec.coords:ClearAllPoints()
  spec.coords:SetPoint("TOP", frame, "BOTTOM", 0, -S.coordDrop)
  spec.coords:SetFont(T.fonts.file, S.coordFont, "OUTLINE")
  spec.calendar:layout(S.calendarBadge, skin)
  spec.calendar.button:ClearAllPoints()
  spec.calendar.button:SetPoint("CENTER", frame, "BOTTOM", S.calendarShift, -S.calendarDrop)
  showIf(opt("showZone") == true, spec.zone, spec.zoneButton)
  showIf(opt("showClock") == true, spec.clock, spec.clockButton)
  showIf(opt("showCalendar") == true, spec.calendar.button)
  showIf(opt("showCoords") == true, spec.coords)
  updateAll(spec)
  ticker(spec, opt("showClock") == true or opt("showCoords") == true)
end

-- A click opens a Blizzard panel, out of combat only.
-- UNVERIFIED (check in client): ToggleWorldMap(), ToggleCalendar() and,
-- after C_AddOns.LoadAddOn("Blizzard_TimeManager"), TimeManager_Toggle()
-- open their panels from addon code without taint.
local function onClick(open)
  return function()
    if InCombatLockdown() then return end
    open()
  end
end

local function openClock()
  local C = _G.C_AddOns
  if type(C) == "table" and type(C.LoadAddOn) == "function" then pcall(C.LoadAddOn, "Blizzard_TimeManager") end
  call("TimeManager_Toggle")
end

local function createElements(spec)
  local T = ns.Theme
  local frame = spec.frame
  local el = CreateFrame("Frame", nil, frame)
  el:SetAllPoints(frame)
  -- above the map (it sits one level over our frame)
  el:SetFrameLevel((frame:GetFrameLevel() or 0) + 10)
  spec.elements = el
  local function text(color)
    local fs = el:CreateFontString(nil, "OVERLAY")
    -- a font before any SetText: the client errors on a font string without one
    fs:SetFont(T.fonts.file, T.sizes.minimap.clockFont, "OUTLINE")
    fs:SetText("")
    fs:SetTextColor(color[1], color[2], color[3], color[4])
    return fs
  end
  spec.zone = text(T.colors.gold)
  spec.zone:SetWordWrap(false)
  spec.clock = text(T.colors.ink)
  spec.coords = text(T.colors.coords)
  local function clickArea(fs, open)
    local b = CreateFrame("Button", nil, el)
    b:SetAllPoints(fs)
    b:SetScript("OnClick", onClick(open))
    return b
  end
  spec.zoneButton = clickArea(spec.zone, function() call("ToggleWorldMap") end)
  spec.clockButton = clickArea(spec.clock, openClock)
  spec.calendar = ns.Map.Badge.create(el)
  spec.calendar:setIcon(T.textures.calendar)
  spec.calendar.button:SetScript("OnClick", onClick(function() call("ToggleCalendar") end))
end

local function apply(spec)
  local frame = spec.frame
  if not frame then return end
  if not ns.Modules.isEnabled(ID) then
    frame:Hide()
    ticker(spec, false)
    place(spec)
    return
  end
  local size = opt("size")
  frame:SetSize(size, size)
  local skin = ns.Units.Base.skinOf(frame)
  spec.edge = ns.UnitLayout.edgeWidth(skin.border)
  spec.panel:layout({ skin = skin })
  spec.ring:layout({ ring = { cx = size / 2, cy = size / 2, dia = size } }, { skin = skin })
  if opt("shape") == "Square" then
    spec.panel.frame:Show()
    spec.ring.frame:Hide()
  else
    spec.panel.frame:Hide()
    spec.ring.frame:Show()
  end
  layoutElements(spec, skin)
  frame:Show()
  place(spec)
  mask(spec)
end

-- UNVERIFIED (check in client): Minimap:GetZoom / SetZoom / GetZoomLevels
-- (levels 0 .. GetZoomLevels() - 1) and OnMouseWheel on the map. When
-- Blizzard's map already has a wheel handler (`own`), that one zooms and the
-- setting only turns it on or off; turned off, the module leaves it alone.
local function wheelHandler(own)
  return function(m, delta, ...)
    if not ns.Modules.isEnabled(ID) then
      if own then own(m, delta, ...) end
      return
    end
    if opt("wheelZoom") ~= true then return end
    if own then
      own(m, delta, ...)
      return
    end
    local z = Rules.zoom(m:GetZoom(), delta, m:GetZoomLevels())
    if z then m:SetZoom(z) end
  end
end

-- UNVERIFIED (check in client): libraries that place minimap buttons call
-- the global GetMinimapShape(); defined only when no other addon did.
local function defineShape()
  if _G.GetMinimapShape ~= nil then return end
  _G.GetMinimapShape = function()
    if not ns.Modules.isEnabled(ID) then return "ROUND" end
    return Rules.shapeName(opt("shape"))
  end
end

local function hookMap(spec, m)
  local function moved(_, p)
    if spec.placing or not ns.Modules.isEnabled(ID) or p == spec.frame then return end
    place(spec)
  end
  hooksecurefunc(m, "SetParent", moved)
  hooksecurefunc(m, "SetPoint", function()
    if spec.placing or not ns.Modules.isEnabled(ID) then return end
    place(spec)
  end)
  -- Blizzard sets its own (round) mask on Forever after we set ours
  -- (MinimapCluster:UpdateMinimapConfig): ours goes back on.
  hooksecurefunc(m, "SetMaskTexture", function()
    if spec.masking or not ns.Modules.isEnabled(ID) then return end
    mask(spec)
  end)
  m:EnableMouseWheel(true)
  m:SetScript("OnMouseWheel", wheelHandler(m:GetScript("OnMouseWheel")))
end

-- UNVERIFIED (check in client): the zone events fire on zone / subzone /
-- indoor changes and CALENDAR_UPDATE_PENDING_INVITES when invites change.
local EVENTS = { "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
  "ZONE_CHANGED_NEW_AREA", "CALENDAR_UPDATE_PENDING_INVITES" }

local function slider(key, label, tooltip, min, max, step)
  return { key = key, type = "slider", label = label, tooltip = tooltip, min = min, max = max, step = step }
end

local function checkbox(key, label, tooltip)
  return { key = key, type = "checkbox", label = label, tooltip = tooltip }
end

local function dropdown(key, label, tooltip, values)
  return { key = key, type = "dropdown", label = label, tooltip = tooltip, values = values }
end

ns.Modules.define({
  id = ID, label = "Minimap", kind = "misc",
  defaults = { size = ns.Theme.sizes.minimap.size, skin = "Classic", shape = "Square", wheelZoom = true,
    showZone = true, showClock = true, showCalendar = true, showCoords = false },
  settings = {
    { section = "Size", controls = {
      slider("size", "Map size", "Width and height of the map.", 120, 320, 1),
    } },
    { section = "Look", controls = {
      dropdown("skin", "Skin", "Border and decoration style of the frame.", { "Classic", "Forge", "Slate" }),
      dropdown("shape", "Shape", "Square or round map.", { "Square", "Round" }),
    } },
    { section = "Elements", controls = {
      checkbox("showZone", "Zone name", "Show the zone name above the map."),
      checkbox("showClock", "Clock", "Show the clock below the map."),
      checkbox("showCalendar", "Calendar", "Show the calendar button below the map."),
      checkbox("showCoords", "Coordinates", "Show your coordinates below the map."),
    } },
    { section = "Behaviour", controls = {
      checkbox("wheelZoom", "Mouse wheel zoom", "Zoom the map with the mouse wheel."),
    } },
  },
  -- UNVERIFIED (check in client): Forever's minimap cluster (border, zone
  -- text, clock, calendar, mail, tracking, zoom and expansion buttons) is
  -- MinimapCluster, and hiding it after the map moved out leaves the map
  -- working.
  blizzard = { "MinimapCluster" },
  defaultPosition = { point = "TOPRIGHT", x = -16, y = -40 },
  create = function(spec)
    local frame = CreateFrame("Frame", "AnotherHUDMinimap", UIParent)
    frame.id = ID -- for Units.Base.skinOf
    -- UNVERIFIED (check in client): the map (strata LOW) draws above the
    -- panel when our frame is LOW too and the panel sits at our level.
    frame:SetFrameStrata("LOW")
    spec.frame = frame
    spec.panel = ns.Units.Parts.Panel.create(frame)
    spec.panel.frame:SetFrameLevel(frame:GetFrameLevel() or 0)
    -- Round: the skin ring (the portrait ring's lines, no portrait, no
    -- badge), below the map like the panel.
    spec.ring = ns.Units.Parts.Ring.create(frame)
    spec.ring.frame:SetFrameLevel(frame:GetFrameLevel() or 0)
    spec.ring.portrait:Hide()
    spec.placing = false
    createElements(spec)
    local m = blizzardMap()
    if m then
      hookMap(spec, m)
      hideMapArt(m)
    end
    for _, ev in ipairs(EVENTS) do frame:RegisterEvent(ev) end
    frame:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_LOGIN" then
        defineShape()
        place(spec)
      elseif event == "PLAYER_ENTERING_WORLD" then
        place(spec)
        if ns.Modules.isEnabled(ID) then updateAll(spec) end
      elseif not ns.Modules.isEnabled(ID) then
        return
      elseif event == "CALENDAR_UPDATE_PENDING_INVITES" then
        updateCalendar(spec)
      else
        updateZone(spec)
      end
    end)
    if type(_G.IsLoggedIn) == "function" and IsLoggedIn() then defineShape() end
    apply(spec)
    -- after the map moved out (both queued in this order in combat)
    ns.Units.Base.hideBlizzard(spec.blizzard)
  end,
  apply = function(spec) apply(spec) end,
  -- Edit Mode open or closed, a layout switch: the map goes back in place.
  onEditMode = function(spec)
    if spec.frame then place(spec) end
  end,
})
