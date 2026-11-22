local ADDON, ns = ...

-- The player frame. Its cast bar hangs under the frame, or (Detach cast bar)
-- sits on the `playercast` holder (Units/PlayerCastBar.lua); apply re-applies
-- the holder so both follow the option.
ns.Units.define({
  id = "player", label = "Player", unit = "player", name = "AnotherHUDPlayerFrame",
  castBar = true, auras = true, badge = ns.Theme.sizes.unit.badge,
  parts = { "Size", "Text", "Look", "Behaviour", "Cast Bar", "Auras", "Fading",
    portrait = true, power = true, detach = true },
  blizzard = { "PlayerFrame", "PlayerCastingBarFrame" },
  defaultPosition = { point = "CENTER", x = -260, y = -200 },
  apply = function(spec)
    ns.Units.Base.apply(spec)
    local holder = ns.Modules.get("playercast")
    if holder and holder.frame then
      holder.apply(holder)
    elseif spec.frame then
      ns.Units.Base.anchorCast(spec.frame, nil)
    end
  end,
})
