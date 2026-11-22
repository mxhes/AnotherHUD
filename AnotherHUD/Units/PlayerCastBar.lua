local ADDON, ns = ...

-- The detached player cast bar's holder: a plain frame of the cast bar's
-- size that Edit Mode moves like any module (child of `player`: off with
-- it, not in the checklist; its options are the Player's Cast Bar
-- section). Detach cast bar on (and the cast bar on): the Player's cast bar
-- is parented and anchored to the holder and the holder is shown. Off: the
-- holder stays hidden, so Edit Mode can't select it, and the bar hangs
-- under the Player frame. Shown and moved together through Combat.after.
local function detached()
  local get = ns.Options.get
  return get("player", "castBar") == true and get("player", "castDetach") == true
end

local function apply(spec)
  local holder = spec.frame
  if not holder then return end
  local on = detached()
  ns.Combat.after("unit:playercast", function()
    local get = ns.Options.get
    holder:SetSize(get("player", "castWidth"), get("player", "castHeight"))
    -- UNVERIFIED (check in client): LibEditMode does not show or select a
    -- registered frame while it is hidden.
    if on then holder:Show() else holder:Hide() end
  end)
  local player = ns.Modules.get("player")
  if player and player.frame then ns.Units.Base.anchorCast(player.frame, on and holder or nil) end
end

ns.Modules.define({
  id = "playercast", label = "Player Cast Bar", kind = "unit", parent = "player",
  defaults = {}, settings = {},
  defaultPosition = { point = "CENTER", x = 0, y = -280 },
  create = function(spec)
    local holder = CreateFrame("Frame", "AnotherHUDPlayerCastBarHolder", UIParent)
    holder:Hide()
    spec.frame = holder
    apply(spec)
  end,
  apply = function(spec) apply(spec) end,
})
