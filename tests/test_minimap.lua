local h = ...
local fakes = dofile("tests/fakes.lua")

-- The minimap module (Map/Minimap.lua) loaded from the .toc and started
-- through Core.init with a fake client, a fake LibEditMode, a fake Blizzard
-- Minimap (mask, zoom, anchors) and a fake MinimapCluster.

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

-- Blizzard's map: inside the cluster, CENTER on the cluster's TOP, 140 px.
local function fakeMinimap(cluster)
  local m = fakes.frame("Minimap")
  m._parent, m._width, m._height, m._zoom = cluster, 140, 140, 0
  m.GetNumPoints = function() return 1 end
  m.GetPoint = function() return "CENTER", cluster, "TOP", 9, -92 end
  m.SetMaskTexture = function(self, p) self._mask = p end
  m.GetZoom = function(self) return self._zoom end
  m.SetZoom = function(self, z) self._zoom = z end
  m.GetZoomLevels = function() return 6 end
  -- Blizzard's children of the map (Minimap.xml): zoom buttons and their
  -- hover area; EnableMouse is recorded.
  for _, key in ipairs({ "ZoomIn", "ZoomOut", "ZoomHitArea" }) do
    local c = fakes.frame()
    c.EnableMouse = function(self, on) self._mouse = on end
    m[key] = c
  end
  return m
end

-- Blizzard's art and buttons on MinimapBackdrop (a child of the map).
local function fakeBackdrop()
  local backdrop = fakes.frame("MinimapBackdrop")
  backdrop.ExternalEventURLButton = fakes.frame()
  return {
    MinimapBackdrop = backdrop,
    MinimapCompassTexture = fakes.frame("MinimapCompassTexture"),
    MinimapCompassTextureUnderlay = fakes.frame("MinimapCompassTextureUnderlay"),
    ExpansionLandingPageMinimapButton = fakes.frame("ExpansionLandingPageMinimapButton"),
  }
end

-- Runs fn(ns, client, map, cluster) after Core.init. opts.shape: a
-- GetMinimapShape another addon defined first; opts.off: the module is
-- turned off in the saved profile before start.
local function withMap(opts, fn)
  opts = opts or {}
  local client = fakes.client({})
  local units = fakes.units({ player = { exists = true, name = "Me", class = "MAGE", level = 42,
    health = 100, healthMax = 100, isPlayer = true } })
  local cluster = fakes.frame("MinimapCluster")
  local map = fakeMinimap(cluster)
  if opts.wheel then map._scripts.OnMouseWheel = opts.wheel end
  local globals = {
    LibStub = fakes.libstub({ LibEditMode = fakeLem() }),
    AnotherHUDDB = fakes.NIL, AnotherHUDCharDB = fakes.NIL, EditModeManagerFrame = fakes.NIL,
    Minimap = map, MinimapCluster = cluster,
    GetMinimapShape = opts.shape or fakes.NIL,
  }
  local backdrop = fakeBackdrop()
  for k, v in pairs(backdrop) do globals[k] = v end
  if opts.off then
    globals.AnotherHUDDB = { profileKeys = {}, profiles = { Default = { modules = { minimap = { enabled = false } } } } }
  end
  for _, name in ipairs(BLIZZARD) do globals[name] = fakes.frame(name) end
  local ok, err = pcall(fakes.withGlobals, globals, function()
    local ns = h.load(h.toc())
    ns.Util.say = function() end
    ns.Core.init()
    fn(ns, client, map, cluster, backdrop)
  end)
  units.restore()
  client.restore()
  if not ok then error(err, 0) end
end

local function lastPoint(f)
  local p
  for _, c in ipairs(f.calls) do if c[1] == "SetPoint" then p = c end end
  return p
end

local function edge(ns)
  return ns.UnitLayout.edgeWidth(ns.Theme.skins.classic.border)
end

h.test("the minimap module registers with Edit Mode and the checklist", function()
  withMap({}, function(ns)
    local spec = ns.Modules.get("minimap")
    h.eq(spec.kind, "misc")
    h.eq(spec.label, "Minimap")
    h.eq(spec.defaultPosition, { point = "TOPRIGHT", x = -16, y = -40 })
    h.eq(spec.frame:GetName(), "AnotherHUDMinimap")
    h.eq({ spec.frame._width, spec.frame._height }, { 180, 180 })
    local listed = false
    for _, e in ipairs(ns.EditMode.Checklist.entries()) do if e.id == "minimap" then listed = true end end
    h.eq(listed, true, "listed in the checklist")
    h.eq(ns.Options.get("minimap", "shape"), "Square")
    h.eq(ns.Options.get("minimap", "wheelZoom"), true)
  end)
end)

h.test("Blizzard's map moves into our frame", function()
  withMap({}, function(ns, _, map)
    local frame, e = ns.Modules.get("minimap").frame, edge(ns)
    h.eq(map:GetParent(), frame)
    h.eq(lastPoint(map), { "SetPoint", "TOPLEFT", frame, "TOPLEFT", e, -e })
    h.eq({ map._width, map._height }, { 180 - 2 * e, 180 - 2 * e })
    ns.Options.set("minimap", "size", 240)
    h.eq({ frame._width, frame._height }, { 240, 240 })
    h.eq({ map._width, map._height }, { 240 - 2 * e, 240 - 2 * e })
  end)
end)

h.test("Blizzard's cluster is hidden", function()
  withMap({}, function(_, _, map, cluster)
    h.eq(cluster:IsShown(), false)
    h.eq(cluster:GetParent() ~= nil and cluster:GetParent() ~= UIParent, true, "parked")
    h.eq(map:GetParent() ~= cluster, true, "map moved out first")
  end)
end)

h.test("the shape sets the mask", function()
  withMap({}, function(ns, _, map)
    local spec = ns.Modules.get("minimap")
    h.eq(map._mask, "Interface\\Buttons\\WHITE8x8")
    h.eq(spec.panel.frame:IsShown(), true, "square panel")
    ns.Options.set("minimap", "shape", "Round")
    h.eq(map._mask, "Textures\\MinimapMask")
    h.eq(spec.panel.frame:IsShown(), false, "no square panel when round")
  end)
end)

h.test("Blizzard setting its own mask is undone", function()
  withMap({}, function(ns, client, map)
    map:SetMaskTexture("ui-hud-minimap-frame-generic-mask")
    h.eq(map._mask, "Interface\\Buttons\\WHITE8x8", "ours again at once")
    client.setCombat(true)
    map:SetMaskTexture("ui-hud-minimap-frame-generic-mask")
    h.eq(map._mask, "ui-hud-minimap-frame-generic-mask", "nothing in combat")
    client.setCombat(false)
    client.fire("PLAYER_REGEN_ENABLED")
    h.eq(map._mask, "Interface\\Buttons\\WHITE8x8", "ours after combat")
    ns.EditMode.Checklist.toggle("minimap", false)
    map:SetMaskTexture("ui-hud-minimap-frame-generic-mask")
    h.eq(map._mask, "ui-hud-minimap-frame-generic-mask", "off: Blizzard's stays")
  end)
end)

h.test("Blizzard's ring and buttons on the map are hidden", function()
  withMap({}, function(_, _, map, _, b)
    h.eq(b.MinimapCompassTexture._alpha, 0, "ring art")
    h.eq(b.MinimapCompassTextureUnderlay._alpha, 0, "ring underlay")
    -- the zoom buttons stay shown (Blizzard's wheel clicks them) but unseen
    -- and not clickable
    for _, key in ipairs({ "ZoomIn", "ZoomOut", "ZoomHitArea" }) do
      h.eq(map[key]._alpha, 0, key .. " unseen")
      h.eq(map[key]._mouse, false, key .. " no mouse")
    end
    for _, f in ipairs({ b.ExpansionLandingPageMinimapButton, b.MinimapBackdrop.ExternalEventURLButton }) do
      h.eq(f:IsShown(), false, "button hidden")
      f:Show()
      h.eq(f:IsShown(), false, "stays hidden")
      f:SetShown(true)
      h.eq(f:IsShown(), false, "stays hidden after SetShown")
    end
  end)
end)

h.test("a shape change in combat waits", function()
  withMap({}, function(ns, client, map)
    client.setCombat(true)
    ns.Options.set("minimap", "shape", "Round")
    h.eq(map._mask, "Interface\\Buttons\\WHITE8x8")
    client.setCombat(false)
    client.fire("PLAYER_REGEN_ENABLED")
    h.eq(map._mask, "Textures\\MinimapMask")
  end)
end)

h.test("Blizzard re-parenting the map is undone", function()
  withMap({}, function(ns, client, map)
    local frame, e = ns.Modules.get("minimap").frame, edge(ns)
    map:SetParent(UIParent)
    h.eq(map:GetParent(), frame, "back at once out of combat")
    map:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    h.eq(lastPoint(map), { "SetPoint", "TOPLEFT", frame, "TOPLEFT", e, -e })
    client.setCombat(true)
    map:SetParent(UIParent)
    h.eq(map:GetParent(), UIParent, "nothing in combat")
    client.setCombat(false)
    client.fire("PLAYER_REGEN_ENABLED")
    h.eq(map:GetParent(), frame, "back after combat")
  end)
end)

h.test("the wheel zooms within range", function()
  withMap({}, function(ns, _, map)
    local wheel = map._scripts.OnMouseWheel
    h.eq(type(wheel), "function", "wheel script")
    wheel(map, 1)
    h.eq(map._zoom, 1)
    wheel(map, -1)
    h.eq(map._zoom, 0)
    wheel(map, -1)
    h.eq(map._zoom, 0, "not below 0")
    map._zoom = 5
    wheel(map, 1)
    h.eq(map._zoom, 5, "not past the last level")
    ns.Options.set("minimap", "wheelZoom", false)
    map._zoom = 2
    wheel(map, 1)
    h.eq(map._zoom, 2, "off: nothing")
  end)
end)

h.test("Blizzard's own wheel handler zooms instead of ours", function()
  local calls = 0
  withMap({ wheel = function() calls = calls + 1 end }, function(ns, _, map)
    local wheel = map._scripts.OnMouseWheel
    wheel(map, 1)
    h.eq(calls, 1, "Blizzard's handler ran")
    h.eq(map._zoom, 0, "no second step of ours")
    ns.Options.set("minimap", "wheelZoom", false)
    wheel(map, 1)
    h.eq(calls, 1, "off: nothing")
    ns.Options.set("minimap", "wheelZoom", true)
    ns.EditMode.Checklist.toggle("minimap", false)
    wheel(map, 1)
    h.eq(calls, 2, "module off: Blizzard's wheel as before")
  end)
end)

h.test("GetMinimapShape answers the shape and is not overwritten", function()
  withMap({}, function(ns, client)
    client.fire("PLAYER_LOGIN")
    h.eq(GetMinimapShape(), "SQUARE")
    ns.Options.set("minimap", "shape", "Round")
    h.eq(GetMinimapShape(), "ROUND")
  end)
  local theirs = function() return "CORNER-TOPLEFT" end
  withMap({ shape = theirs }, function(_, client)
    client.fire("PLAYER_LOGIN")
    h.eq(GetMinimapShape, theirs)
  end)
end)

h.test("turned off, the map goes back to Blizzard", function()
  withMap({}, function(ns, _, map, cluster)
    local spec = ns.Modules.get("minimap")
    ns.EditMode.Checklist.toggle("minimap", false)
    h.eq(spec.frame:IsShown(), false)
    h.eq(map:GetParent(), cluster)
    h.eq(lastPoint(map), { "SetPoint", "CENTER", cluster, "TOP", 9, -92 })
    h.eq({ map._width, map._height }, { 140, 140 })
    h.eq(map._mask, "Textures\\MinimapMask")
    map:SetParent(UIParent)
    h.eq(map:GetParent(), UIParent, "no re-parenting while off")
  end)
  withMap({ off = true }, function(ns, _, map, cluster)
    h.eq(ns.Modules.get("minimap").frame, nil, "not built when off at login")
    h.eq(cluster:IsShown(), true, "cluster stays")
    h.eq(map:GetParent(), cluster, "map stays")
  end)
end)
