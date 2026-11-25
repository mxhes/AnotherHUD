local h = ...
local fakes = dofile("tests/fakes.lua")

-- The unit modules (Units/Player.lua ... Units/Pet.lua) loaded from the
-- .toc and started through Core.init with a fake client, fake unit API and
-- a fake LibEditMode.

local BLIZZARD = { "PlayerFrame", "PlayerCastingBarFrame", "TargetFrame", "FocusFrame", "PetFrame",
  "PartyFrame", "CompactPartyFrame", "BossTargetFrameContainer" }

local function fakeLem()
  local lem = { SettingType = { Checkbox = 1, Slider = 2, Dropdown = 3, Divider = 4 }, frames = 0, labels = {} }
  function lem:AddFrame(frame, onMove, default, label)
    self.frames = self.frames + 1
    self.labels[#self.labels + 1] = label
  end
  function lem:AddFrameSettings() end
  function lem:AddFrameSettingsButtons() end
  lem.callbacks = {}
  function lem:RegisterCallback(name, fn) self.callbacks[name] = fn end
  function lem:GetActiveLayoutName() return "Modern" end
  return lem
end

-- Runs fn(ns, client, lem, blizzard, units) after Core.init; restores the unit API
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
    -- some XP, so the XP / Reputation bar has a row to show
    UnitXP = function() return 10 end, UnitXPMax = function() return 100 end,
  }
  for _, name in ipairs(BLIZZARD) do
    blizzard[name] = fakes.frame(name)
    globals[name] = blizzard[name]
  end
  local ok, err = pcall(fakes.withGlobals, globals, function()
    local ns = h.load(h.toc())
    ns.Util.say = function() end
    ns.Core.init()
    fn(ns, client, lem, blizzard, units)
  end)
  units.restore()
  client.restore()
  if not ok then error(err, 0) end
end

h.test("all ten modules register with Edit Mode", function()
  withInit({}, function(ns, _, lem)
    h.eq(lem.frames, 10)
    for _, id in ipairs({ "player", "playercast", "resource", "tracking", "target", "targettarget", "focus", "pet",
      "party", "boss" }) do
      h.eq(ns.Modules.get(id) ~= nil and ns.Modules.get(id).frame ~= nil, true, id .. " frame")
      local bar = id == "resource" or id == "tracking"
      h.eq(ns.Modules.get(id).kind, bar and "bar" or "unit", id .. " kind")
    end
    h.eq(ns.Modules.get("resource").frame:GetName(), "AnotherHUDResourceBarHolder")
    h.eq(ns.Modules.get("tracking").frame:GetName(), "AnotherHUDTrackingBar")
    h.eq(ns.Modules.get("spike"), nil, "no spike module")
    h.eq(ns.Modules.get("player").frame:GetName(), "AnotherHUDPlayerFrame")
    h.eq(ns.Modules.get("playercast").frame:GetName(), "AnotherHUDPlayerCastBarHolder")
    h.eq(ns.Modules.get("party").frame:GetName(), "AnotherHUDParty")
    h.eq(ns.Modules.get("boss").frame:GetName(), "AnotherHUDBoss")
    h.eq(ns.Modules.get("targettarget").frame:GetName(), "AnotherHUDTargetTargetFrame")
  end)
end)

h.test("checklist shows the unit frames and the XP / Reputation bar", function()
  withInit({}, function(ns)
    local ids = {}
    for _, entry in ipairs(ns.EditMode.Checklist.entries()) do ids[#ids + 1] = entry.id end
    h.eq(ids, { "player", "target", "targettarget", "focus", "pet", "party", "boss", "tracking" })
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
    h.eq(ns.L[spec.label] ~= spec.label or spec.label == "Boss", true, spec.label .. " translated") -- "Boss" is the same word in German
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

h.test("a frame turned off stays off until turned on", function()
  withInit({}, function(ns, client, lem, _, units)
    local spec = ns.Modules.get("targettarget")
    local frame = spec.frame
    h.eq(client.drivers[frame] ~= nil, true, "driver at login")
    lem.callbacks.enter()
    ns.EditMode.Checklist.toggle("targettarget", false)
    h.eq(frame:IsShown(), false, "hidden at once")
    h.eq(client.drivers[frame], nil, "no driver")
    lem.callbacks.exit()
    h.eq(frame:IsShown(), false, "still hidden after Edit Mode")
    h.eq(client.drivers[frame], nil, "no driver after Edit Mode")
    units.set("targettarget", "exists", true)
    units.set("targettarget", "name", "Tank")
    client.fire("UNIT_TARGET", "target")
    client.fire("PLAYER_TARGET_CHANGED")
    h.eq(frame:IsShown(), false, "unit change keeps it hidden")
    h.eq(client.drivers[frame], nil)
    lem.callbacks.enter()
    h.eq(frame:IsShown(), false, "no sample while off")
    h.eq(frame.sampling, false)
    h.eq(frame.bars.name:GetText() ~= ns.L["Target of Target"], true, "no sample name")
    lem.callbacks.exit()
    ns.EditMode.Checklist.toggle("targettarget", true)
    h.eq(client.drivers[frame] ~= nil, true, "driver back")
    h.eq(frame.bars.name:GetText(), "Tank", "frame updates")
  end)
end)

h.test("a frame turned on in Edit Mode shows its sample", function()
  withInit({}, function(ns, client, lem)
    local frame = ns.Modules.get("focus").frame
    lem.callbacks.enter()
    ns.EditMode.Checklist.toggle("focus", false)
    h.eq(frame:IsShown(), false)
    h.eq(frame.sampling, false)
    ns.EditMode.Checklist.toggle("focus", true)
    h.eq(frame:IsShown(), true, "shown again")
    h.eq(frame.sampling, true, "sample again")
    h.eq(client.drivers[frame], nil, "no driver while editing")
    lem.callbacks.exit()
    h.eq(client.drivers[frame] ~= nil, true, "driver after Edit Mode")
  end)
end)

h.test("player off hides its detached cast bar", function()
  withInit({}, function(ns, client)
    local player, holder = ns.Modules.get("player").frame, ns.Modules.get("playercast").frame
    ns.Options.set("player", "castDetach", true)
    h.eq(holder:IsShown(), true)
    ns.EditMode.Checklist.toggle("player", false)
    h.eq(player:IsShown(), false, "player hidden")
    h.eq(holder:IsShown(), false, "holder hidden")
    h.eq(client.drivers[player], nil)
    ns.EditMode.Checklist.toggle("player", true)
    h.eq(holder:IsShown(), true, "holder back")
    h.eq(castParent(ns), holder)
    h.eq(client.drivers[player] ~= nil, true, "driver back")
  end)
end)

h.test("party hides both Blizzard party frames", function()
  withInit({}, function(ns, _, _, blizzard)
    h.eq(ns.Modules.get("party").blizzard, { "PartyFrame", "CompactPartyFrame" })
    for _, name in ipairs({ "PartyFrame", "CompactPartyFrame" }) do
      h.eq(blizzard[name]:IsShown(), false, name .. " hidden")
    end
    h.eq(ns.Modules.get("party").members[2]._events.GROUP_ROSTER_UPDATE, true, "members follow the roster")
  end)
end)

h.test("boss hides the Blizzard boss container", function()
  withInit({}, function(ns, _, _, blizzard)
    h.eq(ns.Modules.get("boss").blizzard, { "BossTargetFrameContainer" })
    h.eq(blizzard.BossTargetFrameContainer:IsShown(), false)
    h.eq(ns.Modules.get("boss").members[1]._events.GROUP_ROSTER_UPDATE, nil, "no roster event")
  end)
end)

local function sectionsOf(spec)
  local out = {}
  for _, entry in ipairs(spec.settings) do
    if out[#out] ~= entry.section then out[#out + 1] = entry.section end
  end
  return out
end

h.test("Player lists Resource Bar after Cast Bar", function()
  withInit({}, function(ns)
    h.eq(sectionsOf(ns.Modules.get("player")),
      { "Size", "Text", "Look", "Behaviour", "Cast Bar", "Resource Bar", "Auras", "Fading" })
    h.eq(ns.Options.get("player", "showResource"), true)
    h.eq(ns.Options.get("target", "showResource"), nil, "only the Player has it")
  end)
end)

h.test("party panel sections in spec order", function()
  withInit({}, function(ns)
    h.eq(sectionsOf(ns.Modules.get("party")),
      { "Group", "Size", "Text", "Look", "Behaviour", "Auras", "Fading" })
  end)
end)

h.test("boss panel sections", function()
  withInit({}, function(ns)
    h.eq(sectionsOf(ns.Modules.get("boss")), { "Group", "Size", "Text", "Look", "Cast Bar", "Auras" })
  end)
end)

h.test("party and boss samples and defaults", function()
  withInit({}, function(ns)
    local get = ns.Options.get
    h.eq({ get("party", "width"), get("party", "height"), get("party", "powerHeight"), get("party", "auraSize") },
      { 160, 40, 5, 20 })
    h.eq({ get("boss", "width"), get("boss", "height"), get("boss", "castWidth"), get("boss", "gap") },
      { 180, 42, 180, 12 })
    h.eq(ns.Modules.get("party").defaultPosition, { point = "LEFT", x = 40, y = 120 })
    h.eq(ns.Modules.get("boss").defaultPosition, { point = "RIGHT", x = -120, y = 120 })
    ns.EditMode.Glue.inEditMode = function() return true end
    local party, boss = ns.Modules.get("party"), ns.Modules.get("boss")
    party.onEditMode(party, true)
    boss.onEditMode(boss, true)
    h.eq(party.members[1].bars.name:GetText(), "Arthelis")
    h.eq(party.members[5].bars.name:GetText(), "Torvald")
    h.eq(boss.members[1].bars.name:GetText(), "Vyrastra")
    h.eq(boss.members[3].bars.name:GetText(), "The Hollow King")
  end)
end)

h.test("every module's apply honors isEnabled", function()
  withInit({}, function(ns, client)
    local checked = 0
    for _, spec in ipairs(ns.Modules.list()) do
      if spec.frame and type(spec.apply) == "function" then
        checked = checked + 1
        ns.Modules.setEnabled(spec.id, false)
        spec.apply(spec)
        h.eq(spec.frame:IsShown(), false, spec.id .. " hidden when off")
        h.eq(client.drivers[spec.frame], nil, spec.id .. " no driver when off")
        ns.Modules.setEnabled(spec.id, true)
        spec.apply(spec)
        if not spec.parent then -- a child holder (playercast) shows only with its parent's setting
          local on = spec.frame:IsShown() or client.drivers[spec.frame] ~= nil
          h.eq(on, true, spec.id .. " shown or driven when on")
        end
      end
    end
    h.eq(checked >= 8, true, "all modules checked")
  end)
end)
