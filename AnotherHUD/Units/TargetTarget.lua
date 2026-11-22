local ADDON, ns = ...

-- The target of target frame (mirrored, no power bar, cast bar, auras or
-- badge). Blizzard's lives inside TargetFrame and goes with it.
ns.Units.define({
  id = "targettarget", label = "Target of Target", unit = "targettarget",
  name = "AnotherHUDTargetTargetFrame", mirror = true,
  parts = { "Size", "Text", "Look", "Fading", portrait = true },
  defaults = { width = 120, height = 26, fontSize = 10, healthText = "None" },
  defaultPosition = { point = "CENTER", x = 330, y = -300 },
})
