local ADDON, ns = ...

-- Edit Mode glue: registers every enabled module's frame with LibEditMode
-- (frame, settings panel, buttons), stores positions per Edit Mode layout
-- in db.positions[layoutName][moduleId] = { point, x, y } and snaps our own
-- frames in our own move callback. Without LibEditMode the frames are placed
-- at their saved (last layout seen) or default positions and nothing else
-- happens. Every reposition goes through Combat.after("pos:" .. id).
ns.EditMode = ns.EditMode or {}
local Glue = {}

local L = ns.L

local SNAP_THRESHOLD = 8
-- Positions saved while the library knows no layout name yet.
local FALLBACK_LAYOUT = "Default"
local CENTER = { point = "CENTER", x = 0, y = 0 }

local registered = {} -- id -> spec
local order = {}      -- specs in registration order
local byFrame = {}    -- frame -> spec
local lem             -- the library once registerAll found it
local layoutHooked = false

-- LibEditMode or nil (no LibStub, or the library is missing).
function Glue.lib()
  if type(LibStub) ~= "function" then return nil end
  return LibStub("LibEditMode", true)
end

local function activeLayout()
  local name = lem and lem:GetActiveLayoutName()
  if type(name) == "string" and name ~= "" then return name end
  if not lem and type(ns.db.lastLayout) == "string" then return ns.db.lastLayout end
  return FALLBACK_LAYOUT
end

local function defaultOf(spec)
  local d = spec.defaultPosition
  if type(d) == "table" and type(d.point) == "string" then return d end
  return CENTER
end

-- The saved position of `spec` in `layoutName`, else its default.
function Glue.position(spec, layoutName)
  local layout = ns.db.positions[layoutName]
  local saved = type(layout) == "table" and layout[spec.id]
  if type(saved) == "table" and type(saved.point) == "string"
      and ns.Util.isNumber(saved.x) and ns.Util.isNumber(saved.y) then
    return saved
  end
  return defaultOf(spec)
end

local function place(spec, pos)
  local frame = spec.frame
  ns.Combat.after("pos:" .. spec.id, function()
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
  end)
end

local function placeForLayout(spec, layoutName)
  place(spec, Glue.position(spec, layoutName))
end

-- Bottom-left rect of a frame in UIParent units, or nil when it has no
-- position yet.
local function rectOf(frame)
  local left, bottom, w, hgt = frame:GetLeft(), frame:GetBottom(), frame:GetWidth(), frame:GetHeight()
  if not (left and bottom and w and hgt) then return nil end
  local s = frame:GetScale() or 1
  return { x = left * s, y = bottom * s, w = w * s, h = hgt * s }
end

-- Blizzard's "Snap" checkbox in the Edit Mode window; on when unknown.
-- UNVERIFIED (check in client): EditModeManagerFrame:IsSnapEnabled on Forever.
local function snapEnabled()
  local manager = EditModeManagerFrame
  if not (manager and manager.IsSnapEnabled) then return true end
  local ok, on = pcall(manager.IsSnapEnabled, manager)
  return not ok or on ~= false
end

-- The x, y shift (UIParent units) that snaps `spec`'s frame.
local function snapShift(spec)
  local rect = rectOf(spec.frame)
  if not rect or not snapEnabled() then return 0, 0 end
  local targets = { { x = 0, y = 0, w = UIParent:GetWidth() or 0, h = UIParent:GetHeight() or 0 } }
  for _, other in ipairs(order) do
    if other ~= spec and other.frame and other.frame:IsShown() then
      local r = rectOf(other.frame)
      if r then targets[#targets + 1] = r end
    end
  end
  -- UNVERIFIED (check in client): no readable API for Blizzard's Edit Mode
  -- grid spacing is known, so there is no grid snap (opts.grid = nil).
  local x, y = ns.EditMode.Snap.snap(rect, targets, { grid = nil, threshold = SNAP_THRESHOLD })
  return x - rect.x, y - rect.y
end

local function isDefault(spec, point, x, y)
  local d = defaultOf(spec)
  return point == d.point and x == d.x and y == d.y
end

-- LibEditMode's move callback: the library has already placed the frame at
-- (point, x, y). Snap it (unless it is the default position, as the
-- library's own Reset Position passes), then save under the layout.
local function onMove(frame, layoutName, point, x, y)
  local spec = byFrame[frame]
  if not spec or type(point) ~= "string" or not ns.Util.isNumber(x) or not ns.Util.isNumber(y) then return end
  if type(layoutName) ~= "string" or layoutName == "" then layoutName = activeLayout() end
  local pos = { point = point, x = x, y = y }
  if not isDefault(spec, point, x, y) then
    local dx, dy = snapShift(spec)
    if dx ~= 0 or dy ~= 0 then
      local s = frame:GetScale() or 1
      pos.x, pos.y = x + dx / s, y + dy / s
      place(spec, pos)
    end
  end
  local positions = ns.db.positions
  if type(positions[layoutName]) ~= "table" then positions[layoutName] = {} end
  positions[layoutName][spec.id] = pos
  ns.db.lastLayout = layoutName
end

local function onLayout(layoutName)
  if type(layoutName) ~= "string" or layoutName == "" then return end
  ns.db.lastLayout = layoutName
  for _, spec in ipairs(order) do placeForLayout(spec, layoutName) end
end

local function openSettings(spec)
  local ui = ns.UI and ns.UI.Settings
  if ui and type(ui.open) == "function" then
    ui.open(spec.id)
    return
  end
  local say = ns.Util and ns.Util.say or print
  say(L["Settings window comes later"])
end

-- Back to the module's defaults; the on/off flag stays. apply(spec) with no
-- key redraws everything.
local function resetSettings(spec)
  local modules = ns.DB.profile().modules
  local saved = modules[spec.id]
  local fresh = {}
  if type(saved) == "table" then fresh.enabled = saved.enabled end
  modules[spec.id] = fresh
  if spec.apply then
    ns.Combat.after("apply:" .. spec.id, function() spec.apply(spec) end)
  end
  if lem and lem.RefreshFrameSettings then lem:RefreshFrameSettings(spec.frame) end
end

local function resetPosition(spec)
  local layout = ns.db.positions[activeLayout()]
  if type(layout) == "table" then layout[spec.id] = nil end
  place(spec, defaultOf(spec))
end

local function buttons(spec)
  return {
    { text = L["Settings"], click = function() openSettings(spec) end },
    { text = L["Reset Settings"], click = function() resetSettings(spec) end },
    { text = L["Reset To Default Position"], click = function() resetPosition(spec) end },
  }
end

local function register(spec)
  if registered[spec.id] or not spec.frame then return end
  registered[spec.id] = spec
  order[#order + 1] = spec
  byFrame[spec.frame] = spec
  if lem then
    lem:AddFrame(spec.frame, onMove, defaultOf(spec), spec.label)
    lem:AddFrameSettings(spec.frame, ns.EditMode.Panel.build(spec, lem.SettingType))
    lem:AddFrameSettingsButtons(spec.frame, buttons(spec))
  end
  placeForLayout(spec, activeLayout())
end

-- Registers every enabled module; creates missing frames first (out of
-- combat: Combat.after("create:" .. id)). Safe to call again: registered
-- modules are skipped. `lib` (optional, tests) replaces the LibStub lookup.
function Glue.registerAll(lib)
  lem = lib or lem or Glue.lib()
  for _, spec in ipairs(ns.Modules.list()) do
    if not registered[spec.id] and ns.Modules.isEnabled(spec.id) then
      if spec.frame then
        register(spec)
      elseif type(spec.create) == "function" then
        ns.Combat.after("create:" .. spec.id, function()
          if not spec.frame then spec.create(spec) end
          register(spec)
        end)
      end
    end
  end
  if lem and not layoutHooked then
    layoutHooked = true
    lem:RegisterCallback("layout", onLayout)
  end
end

ns.EditMode.Glue = Glue
