local ADDON, ns = ...

-- Module toggles in Blizzard's Edit Mode window: one checkbox per module in
-- a small box under the window. `entries` and `toggle` are plain Lua;
-- `attach` builds the box on the window's first show.
-- Taint: only our own frames are touched. The box hangs off
-- EditModeManagerFrame through HookScript("OnShow") and its own anchor;
-- nothing is written into Blizzard's tables.
ns.EditMode = ns.EditMode or {}
local Checklist = {}

local L = ns.L

local ROW_HEIGHT = 22
local BOX_WIDTH = 220

-- { { id, label, checked } } in module define order; label translated.
function Checklist.entries()
  local out = {}
  for _, spec in ipairs(ns.Modules.list()) do
    out[#out + 1] = { id = spec.id, label = L[spec.label], checked = ns.Modules.isEnabled(spec.id) }
  end
  return out
end

-- Turns a module on or off: stores the flag, shows / hides its frame (out
-- of combat), creates and registers it when it was off at login. Says
-- when a /reload is needed (the module hides Blizzard frames). Returns
-- whether a reload is needed.
function Checklist.toggle(id, on)
  local needsReload = ns.Modules.setEnabled(id, on)
  local spec = ns.Modules.get(id)
  if spec and spec.frame then
    local frame = spec.frame
    ns.Combat.after("show:" .. id, function()
      if on then frame:Show() else frame:Hide() end
    end)
  elseif spec and on then
    -- UNVERIFIED (check in client): registerAll -> LibEditMode AddFrame
    -- while Edit Mode is open (the frame appears, is selectable and drags,
    -- no taint).
    ns.EditMode.Glue.registerAll()
  end
  if needsReload then ns.Util.say(L["Type /reload to apply"]) end
  return needsReload
end

local box
local buttons = {} -- id -> CheckButton

local function refresh()
  for _, entry in ipairs(Checklist.entries()) do
    local button = buttons[entry.id]
    if button then button:SetChecked(entry.checked) end
  end
end

-- UNVERIFIED (check in client): a BackdropTemplate box parented to and
-- anchored under EditModeManagerFrame, with UICheckButtonTemplate rows.
local function build(manager)
  local T = ns.Theme
  local entries = Checklist.entries()
  box = CreateFrame("Frame", nil, manager, "BackdropTemplate")
  -- Our own frame's field: Blizzard's layout code skips it, so the window
  -- keeps its size. UNVERIFIED (check in client).
  box.ignoreInLayout = true
  box:SetPoint("TOPLEFT", manager, "BOTTOMLEFT", 0, -4)
  box:SetSize(BOX_WIDTH, T.sizes.padding * 2 + ROW_HEIGHT * (#entries + 1))
  box:SetBackdrop(T.backdropSpec("round"))
  local fill, edge = T.colors.panelTint, T.colors.panelBorder
  box:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
  box:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])

  local title = box:CreateFontString(nil, "OVERLAY", T.fonts.title)
  title:SetPoint("TOPLEFT", box, "TOPLEFT", T.sizes.padding, -T.sizes.padding)
  title:SetText("AnotherHUD")

  for i, entry in ipairs(entries) do
    local button = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
    button:SetSize(ROW_HEIGHT, ROW_HEIGHT)
    button:SetPoint("TOPLEFT", box, "TOPLEFT", T.sizes.padding, -T.sizes.padding - ROW_HEIGHT * i)
    local label = box:CreateFontString(nil, "OVERLAY", T.fonts.body)
    label:SetPoint("LEFT", button, "RIGHT", 2, 0)
    label:SetText(entry.label)
    local id = entry.id
    button:SetScript("OnClick", function(self)
      Checklist.toggle(id, self:GetChecked() and true or false)
    end)
    buttons[id] = button
  end
end

local attached = false

-- Hooks Blizzard's Edit Mode window; the box is built the first time the
-- window shows and its checkboxes re-read the profile on every show.
-- Returns whether it hooked (false: no window, or already attached).
-- UNVERIFIED (check in client): EditModeManagerFrame exists at ADDON_LOADED
-- and HookScript("OnShow") on it does not taint Edit Mode.
function Checklist.attach()
  local manager = EditModeManagerFrame
  if attached or not manager then return false end
  attached = true
  local function onShow()
    if not box then build(manager) end
    refresh()
  end
  manager:HookScript("OnShow", onShow)
  if manager:IsShown() then onShow() end
  return true
end

ns.EditMode.Checklist = Checklist
