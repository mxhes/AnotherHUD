local ADDON, ns = ...

-- The focus frame: as Target, smaller, with the small badge.
ns.Units.define({
  id = "focus", label = "Focus", unit = "focus", name = "AnotherHUDFocusFrame",
  castBar = true, auras = true, badge = ns.Theme.sizes.unit.focusBadge,
  parts = { "Size", "Text", "Look", "Behaviour", "Cast Bar", "Auras", "Fading",
    portrait = true, power = true },
  defaults = { width = 160, height = 40, powerHeight = 8, fontSize = 10,
    healthText = "Percent", powerText = "None" },
  blizzard = { "FocusFrame" },
  defaultPosition = { point = "CENTER", x = -420, y = 40 },
})
