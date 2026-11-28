-- luacheck config (https://github.com/lunarmodules/luacheck), run in GitHub Actions
-- (job `lint`) and locally with `luacheck AnotherHUD`. It checks the addon
-- code for leaked or misspelled globals, unused variables and overwritten
-- values. A new WoW API the code reads goes in `read_globals`; a global the
-- addon writes goes in `globals`.

std = "lua51"
max_line_length = false
exclude_files = { "AnotherHUD/Libs/" }

ignore = {
  "212",      -- unused argument (handlers keep the full event signature)
  "211/ADDON", -- `local ADDON, ns = ...` at the top of every file
  "211/ns",    -- `local ADDON, ns = ...` at the top of every file
  "421",      -- shadowing a local
  "431",      -- shadowing an upvalue
  "432",      -- shadowing an upvalue argument
}

-- Globals the addon sets: its saved variables.
globals = {
  "AnotherHUDDB", "AnotherHUDCharDB",
  -- defined by Map/Minimap.lua only when no other addon did
  "GetMinimapShape",
}

-- WoW API the addon reads.
read_globals = {
  "InCombatLockdown", "CreateFrame", "geterrorhandler",
  "LibStub", "UIParent", "CreateColor", "EditModeManagerFrame",
  "Enum", "C_ClassColor", "PowerBarColor", "SetPortraitTexture",
  "UnitCastingInfo", "UnitChannelInfo", "UnitCastingDuration", "UnitChannelDuration",
  "C_DurationUtil", "C_StringUtil", "C_AddOns", "C_Timer", "AnchorUtil",
  "UnitExists", "UnitName", "UnitClass", "UnitLevel", "UnitEffectiveLevel", "UnitClassification",
  "UnitReaction", "UnitIsPlayer", "UnitIsDeadOrGhost", "UnitIsConnected",
  "UnitHealth", "UnitHealthMax", "UnitHealthPercent", "UnitPower", "UnitPowerMax",
  "UnitPowerPercent", "UnitPowerType", "CurveConstants", "AbbreviateNumbers",
  "RegisterStateDriver", "UnregisterStateDriver", "hooksecurefunc",
  "GameTooltip", "GameTooltip_SetDefaultAnchor", "UnitGUID",
  "UnitGroupRolesAssigned", "UnitIsGroupLeader", "UnitInRange",
  "GetSpecialization", "GetRuneCooldown", "UnitPartialPower", "GetPowerRegenForPowerType",
  "UnitPowerDisplayMod", "GetTime", "BreakUpLargeNumbers", "FACTION_BAR_COLORS",
  "UnitXP", "UnitXPMax", "GetXPExhaustion", "IsXPUserDisabled", "IsPlayerAtEffectiveMaxLevel",
  "UnitHonor", "UnitHonorMax", "UnitHonorLevel", "GetCursorPosition",
  "C_Reputation", "GetWatchedFactionInfo",
  "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer",
  "Minimap", "MinimapCluster", "IsLoggedIn",
}
