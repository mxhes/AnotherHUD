local ADDON, ns = ...

-- Spike (Plan 1, Task 7): a plain test frame that goes through the whole
-- module path (Edit Mode frame, panel sections, buttons, checklist toggle).
-- It stays until Plan 3's Player module replaces it; then delete the
-- Spike/ folder and its .toc line, nothing else names it.
local L = ns.L

local function apply(spec)
  local frame = spec.frame
  if not frame then return end
  local T, get = ns.Theme, ns.Options.get
  frame:SetSize(get(spec.id, "width"), get(spec.id, "height"))
  -- Round border on, else the flat fill alone (Theme's edge-less backdrop).
  frame:SetBackdrop(T.backdropSpec(get(spec.id, "border") and "round" or "thin"))
  local fill, edge = T.colors.panelTint, T.colors.panelBorder
  frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
  frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
end

ns.Modules.define{
  id = "spike", label = "AnotherHUD Test", kind = "misc",
  defaults = { width = 200, height = 60, border = true },
  settings = {
    { section = "Size", controls = {
      { key = "width", type = "slider", label = "Width", tooltip = "Width of the test frame.",
        min = 80, max = 400, step = 1 },
      { key = "height", type = "slider", label = "Height", tooltip = "Height of the test frame.",
        min = 20, max = 200, step = 1 },
    } },
    { section = "Look", controls = {
      { key = "border", type = "checkbox", label = "Show border", tooltip = "Draw the frame's border." },
    } },
  },
  defaultPosition = { point = "CENTER", x = 0, y = 200 },
  -- UNVERIFIED (check in client): BackdropTemplate on a plain Frame.
  create = function(spec)
    local frame = CreateFrame("Frame", "AnotherHUDSpikeFrame", UIParent, "BackdropTemplate")
    local label = frame:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.title)
    label:SetPoint("CENTER", frame, "CENTER", 0, 0)
    label:SetText(L["AnotherHUD Test"])
    spec.frame = frame
    apply(spec)
  end,
  apply = function(spec) apply(spec) end,
}
