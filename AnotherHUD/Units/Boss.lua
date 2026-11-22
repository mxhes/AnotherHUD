local ADDON, ns = ...

-- The boss frames: boss1-5, mirrored, each with an attached cast bar
-- (Units/Group.lua). Bosses fire neither roster event, so the holder
-- re-orders on INSTANCE_ENCOUNTER_ENGAGE_UNIT. The sample names are proper
-- names, so they do not go through ns.L.
local unit = ns.Theme.sizes.unit
local function boss(name, pct)
  return { name = name, healthPct = pct, reaction = 2, classification = "elite" }
end

ns.Units.defineGroup({
  id = "boss", label = "Boss", name = "AnotherHUDBoss",
  units = { "boss1", "boss2", "boss3", "boss4", "boss5" },
  visibility = ns.GroupLayout.bossVisibility,
  mirror = true, castBar = true, castGap = unit.bossCastGap,
  auras = true, auraSide = "left", badge = unit.focusBadge,
  orderEvents = { "INSTANCE_ENCOUNTER_ENGAGE_UNIT" },
  samples = {
    boss("Vyrastra", 62), boss("Ironmaw", 88), boss("The Hollow King", 31),
    boss("Grimscale", 54), boss("Sister Vexa", 77),
  },
  parts = { "Group", "Size", "Text", "Look", "Cast Bar", "Auras", portrait = true, power = true },
  defaults = { width = 180, height = 42, powerHeight = 6, fontSize = 10, healthText = "Percent",
    powerText = "None", castWidth = 180, castHeight = 16, buffs = false, onlyMine = true, gap = 12 },
  blizzard = { "BossTargetFrameContainer" },
  defaultPosition = { point = "RIGHT", x = -120, y = 120 },
})
