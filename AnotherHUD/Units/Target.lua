local ADDON, ns = ...

-- The target frame (mirrored: ring on the right).
ns.Units.define({
  id = "target", label = "Target", unit = "target", name = "AnotherHUDTargetFrame",
  mirror = true, castBar = true, auras = true, badge = ns.Theme.sizes.unit.badge,
  parts = { "Size", "Text", "Look", "Behaviour", "Cast Bar", "Auras", "Fading",
    portrait = true, power = true },
  defaults = { healthText = "Percent", powerText = "None" },
  blizzard = { "TargetFrame" },
  defaultPosition = { point = "CENTER", x = 260, y = -200 },
})
