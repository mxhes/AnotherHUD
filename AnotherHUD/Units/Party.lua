local ADDON, ns = ...

-- The party frames: the player plus party1-4 in one block (Units/Group.lua).
-- The names in `samples` are proper names for the Edit Mode preview, so they
-- do not go through ns.L.
ns.Units.defineGroup({
  id = "party", label = "Party", name = "AnotherHUDParty",
  units = { "player", "party1", "party2", "party3", "party4" },
  visibility = ns.GroupLayout.partyVisibility,
  auras = true, auraMode = "line", auraSide = "right",
  range = true, role = true, dispel = true, roles = true,
  samples = {
    { name = "Arthelis", class = "PALADIN", role = "TANK", leader = true, healthPct = 84 },
    { name = "Lunaria", class = "PRIEST", role = "HEALER", healthPct = 97 },
    { name = "Brakka", class = "WARRIOR", role = "DAMAGER", healthPct = 41, dispel = "Magic" },
    { name = "Ssylith", class = "MAGE", role = "DAMAGER", healthPct = 66, far = true },
    { name = "Torvald", class = "HUNTER", role = "DAMAGER", healthPct = 0, dead = true },
  },
  parts = { "Group", "Size", "Text", "Look", "Behaviour", "Auras", "Fading",
    orientation = true, roles = true, portrait = true, power = true },
  defaults = { width = 160, height = 40, portraitScale = 92, powerHeight = 5, fontSize = 10,
    healthText = "Percent", powerText = "None", auraSize = 20 },
  blizzard = { "PartyFrame", "CompactPartyFrame" },
  defaultPosition = { point = "LEFT", x = 40, y = 120 },
})
