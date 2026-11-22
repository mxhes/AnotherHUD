local h = ...
local fakes = dofile("tests/fakes.lua")

-- The unit modules (Units/Player.lua ... Units/Pet.lua) loaded from the
-- .toc and started through Core.init with a fake client, fake unit API and
-- a fake LibEditMode.

local BLIZZARD = { "PlayerFrame", "PlayerCastingBarFrame", "TargetFrame", "FocusFrame", "PetFrame" }

local function fakeLem()
  local lem = { SettingType = { Checkbox = 1, Slider = 2, Dropdown = 3, Divider = 4 }, frames = 0, labels = {} }
  function lem:AddFrame(frame, onMove, default, label)
    self.frames = self.frames + 1
    self.labels[#self.labels + 1] = label
  end
  function lem:AddFrameSettings() end
  function lem:AddFrameSettingsButtons() end
  function lem:RegisterCallback() end
  function lem:GetActiveLayoutName() return "Modern" end
  return lem
end

-- Runs fn(ns, client, lem, blizzard) after Core.init; restores the unit API
-- first, then the client, even on failure.
local function withInit(opts, fn)
  local client = fakes.client(opts)
  local units = fakes.units({ player = { exists = true, name = "Me", class = "MAGE", level = 60,
    health = 100, healthMax = 100, isPlayer = true } })
  local lem = fakeLem()
  local blizzard, globals = {}, {
    LibStub = fakes.libstub({ LibEditMode = lem }),
    AnotherHUDDB = fakes.NIL, AnotherHUDCharDB = fakes.NIL,
    EditModeManagerFrame = fakes.NIL,
  }
  for _, name in ipairs(BLIZZARD) do
    blizzard[name] = fakes.frame(name)
    globals[name] = blizzard[name]
  end
  local ok, err = pcall(fakes.withGlobals, globals, function()
    local ns = h.load(h.toc())
    ns.Util.say = function() end
    ns.Core.init()
    fn(ns, client, lem, blizzard)
  end)
  units.restore()
  client.restore()
  if not ok then error(err, 0) end
end

h.test("all six modules register with Edit Mode", function()
  withInit({}, function(ns, _, lem)
    h.eq(lem.frames, 6)
    for _, id in ipairs({ "player", "playercast", "target", "targettarget", "focus", "pet" }) do
      h.eq(ns.Modules.get(id) ~= nil and ns.Modules.get(id).frame ~= nil, true, id .. " frame")
      h.eq(ns.Modules.get(id).kind, "unit", id .. " kind")
    end
    h.eq(ns.Modules.get("spike"), nil, "no spike module")
    h.eq(ns.Modules.get("player").frame:GetName(), "AnotherHUDPlayerFrame")
    h.eq(ns.Modules.get("playercast").frame:GetName(), "AnotherHUDPlayerCastBarHolder")
    h.eq(ns.Modules.get("targettarget").frame:GetName(), "AnotherHUDTargetTargetFrame")
  end)
end)

h.test("checklist shows five unit frames", function()
  withInit({}, function(ns)
    local ids = {}
    for _, entry in ipairs(ns.EditMode.Checklist.entries()) do ids[#ids + 1] = entry.id end
    h.eq(ids, { "player", "target", "targettarget", "focus", "pet" })
  end)
end)

h.test("unit modules have their parts and defaults", function()
  withInit({}, function(ns)
    local get = ns.Options.get
    local player, target = ns.Modules.get("player").frame, ns.Modules.get("target").frame
    local tot, focus, pet = ns.Modules.get("targettarget").frame, ns.Modules.get("focus").frame,
      ns.Modules.get("pet").frame
    h.eq(player.unit, "player")
    h.eq(player.mirror, false)
    h.eq(target.mirror, true)
    h.eq(tot.mirror, true)
    h.eq(player.badge, 18)
    h.eq(target.badge, 18)
    h.eq(focus.badge, 14)
    h.eq(tot.badge, false)
    h.eq(pet.badge, false)
    h.eq(player.cast ~= false and target.cast ~= false and focus.cast ~= false, true, "cast bars")
    h.eq(tot.cast, false)
    h.eq(pet.cast, false)
    h.eq(tot.auras, false)
    h.eq(pet.auras ~= false, true, "pet auras")
    h.eq(get("player", "castDetach"), false)
    h.eq(get("target", "castDetach"), nil, "target cannot detach")
    h.eq({ get("target", "healthText"), get("target", "powerText") }, { "Percent", "None" })
    h.eq({ get("targettarget", "width"), get("targettarget", "height"), get("targettarget", "fontSize"),
      get("targettarget", "healthText"), get("targettarget", "powerHeight") }, { 120, 26, 10, "None", nil })
    h.eq({ get("focus", "width"), get("focus", "height"), get("focus", "powerHeight"), get("focus", "fontSize") },
      { 160, 40, 8, 10 })
    h.eq({ get("pet", "width"), get("pet", "height"), get("pet", "powerHeight"), get("pet", "showInVehicle") },
      { 120, 34, 6, nil })
    h.eq(ns.Modules.get("playercast").parent, "player")
    h.eq(ns.Modules.get("playercast").settings, {})
    h.eq(ns.Modules.get("targettarget").blizzard, nil, "ToT hides nothing of its own")
    h.eq(ns.Modules.get("focus").defaultPosition, { point = "CENTER", x = -420, y = 40 })
  end)
end)

h.test("labels and defaults fit", function()
  withInit({}, function(ns)
    h.eq(ns.Options.longLabels(ns.Modules.list(), ns.L, 24), {})
  end)
  local ns
  fakes.withGlobals({ GetLocale = function() return "deDE" end }, function() ns = h.load(h.toc()) end)
  h.eq(ns.Options.longLabels(ns.Modules.list(), ns.L, 24), {})
  for _, spec in ipairs(ns.Modules.list()) do
    h.eq(ns.L[spec.label] ~= spec.label, true, spec.label .. " translated")
  end
end)

local function castParent(ns)
  return ns.Modules.get("player").frame.cast.frame:GetParent()
end

h.test("detach moves the cast bar to its holder", function()
  withInit({}, function(ns)
    local player, holder = ns.Modules.get("player").frame, ns.Modules.get("playercast").frame
    h.eq(castParent(ns), player, "attached at login")
    h.eq(holder:IsShown(), false, "holder hidden while attached")
    h.eq(holder._width, 200)
    h.eq(holder._height, 18)
    ns.Options.set("player", "castDetach", true)
    h.eq(castParent(ns), holder, "on the holder")
    h.eq(holder:IsShown(), true, "holder shown while detached")
    ns.Options.set("player", "castWidth", 250)
    h.eq(holder._width, 250, "holder follows the cast bar size")
    ns.Options.set("player", "castDetach", false)
    h.eq(castParent(ns), player, "back under the player frame")
    h.eq(holder:IsShown(), false)
  end)
end)

h.test("detach in combat applies after combat", function()
  withInit({}, function(ns, client)
    local player, holder = ns.Modules.get("player").frame, ns.Modules.get("playercast").frame
    client.setCombat(true)
    ns.Options.set("player", "castDetach", true)
    h.eq(castParent(ns), player, "nothing moves in combat")
    h.eq(holder:IsShown(), false)
    client.setCombat(false)
    client.fire("PLAYER_REGEN_ENABLED")
    h.eq(castParent(ns), holder, "moved after combat")
    h.eq(holder:IsShown(), true)
  end)
end)

h.test("blizzard frames hidden at init", function()
  withInit({}, function(ns, _, _, blizzard)
    for _, name in ipairs(BLIZZARD) do
      local f = blizzard[name]
      h.eq(f:GetParent() ~= nil and f:GetParent() ~= UIParent, true, name .. " reparented")
      h.eq(f:IsShown(), false, name .. " hidden")
    end
  end)
end)
