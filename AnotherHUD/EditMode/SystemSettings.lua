local ADDON, ns = ...

-- Spike: one checkbox ("AnotherHUD look") in Blizzard's Action Bar 1 Edit
-- Mode panel through LibEditMode:AddSystemSettings. It only tests whether
-- adding a setting to a Blizzard system taints; its value is stored in
-- profile.spike.abLook and changes nothing but a chat line.
ns.EditMode = ns.EditMode or {}
local SystemSettings = {}

local L = ns.L

local function spikeState()
  local profile = ns.DB.profile()
  if type(profile.spike) ~= "table" then profile.spike = {} end
  return profile.spike
end

local function lookSetting(types)
  return {
    name = L["AnotherHUD look"],
    desc = L["Test setting, changes nothing yet."],
    kind = types.Checkbox,
    default = false,
    get = function(layoutName) return spikeState().abLook == true end,
    set = function(layoutName, value)
      local on = value and true or false
      spikeState().abLook = on
      ns.Util.say(L["AnotherHUD look"] .. ": " .. (on and L["on"] or L["off"]))
    end,
  }
end

local attached = false

-- Adds the checkbox once. `lib` (optional, tests) replaces the LibStub
-- lookup. Returns whether it was added (false: no library, no client
-- enums, or already added).
-- UNVERIFIED (check in client): Enum.EditModeSystem.ActionBar and
-- Enum.EditModeActionBarSystemIndices.MainBar exist on Forever, and the
-- extra panel shows next to Action Bar 1's panel without tainting it.
function SystemSettings.attach(lib)
  local lem = lib or ns.EditMode.Glue.lib()
  if attached or not lem or type(lem.AddSystemSettings) ~= "function" then return false end
  local types = lem.SettingType or {}
  local enum = Enum
  local systems = type(enum) == "table" and enum.EditModeSystem
  local bars = type(enum) == "table" and enum.EditModeActionBarSystemIndices
  if not (systems and bars and systems.ActionBar and bars.MainBar and types.Checkbox) then return false end
  attached = true
  lem:AddSystemSettings(systems.ActionBar, { lookSetting(types) }, bars.MainBar)
  return true
end

ns.EditMode.SystemSettings = SystemSettings
