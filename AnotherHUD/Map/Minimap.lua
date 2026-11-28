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

local function apply(spec)
  local frame = spec.frame
  if not frame then return end
  if not ns.Modules.isEnabled(ID) then
    frame:Hide()
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
  defaults = { size = ns.Theme.sizes.minimap.size, skin = "Classic", shape = "Square", wheelZoom = true },
  settings = {
    { section = "Size", controls = {
      slider("size", "Map size", "Width and height of the map.", 120, 320, 1),
    } },
    { section = "Look", controls = {
      dropdown("skin", "Skin", "Border and decoration style of the frame.", { "Classic", "Forge", "Slate" }),
      dropdown("shape", "Shape", "Square or round map.", { "Square", "Round" }),
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
    local m = blizzardMap()
    if m then
      hookMap(spec, m)
      hideMapArt(m)
    end
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_LOGIN" then defineShape() end
      place(spec)
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
