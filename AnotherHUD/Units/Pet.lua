local ADDON, ns = ...

-- The pet frame: no cast bar, no badge.
ns.Units.define({
  id = "pet", label = "Pet", unit = "pet", name = "AnotherHUDPetFrame", auras = true,
  parts = { "Size", "Text", "Look", "Auras", "Fading", portrait = true, power = true },
  defaults = { width = 120, height = 34, powerHeight = 6, fontSize = 10,
    healthText = "Percent", powerText = "None" },
  blizzard = { "PetFrame" },
  defaultPosition = { point = "CENTER", x = -300, y = -290 },
})
