local h = ...
local fakes = dofile("tests/fakes.lua")

local FILES = { "Core/Util.lua", "Core/Theme.lua", "Core/DB.lua", "Core/Modules.lua", "Core/Combat.lua",
  "Core/Options.lua", "EditMode/Panel.lua", "EditMode/Snap.lua", "EditMode/Glue.lua",
  "EditMode/Checklist.lua" }

local function load()
  local ns = h.load(FILES)
  ns.db, ns.chardb = ns.DB.init(nil, nil)
  return ns
end

local function lastPoint(frame)
  for i = #frame.calls, 1, -1 do
    local c = frame.calls[i]
    if c[1] == "SetPoint" then return c end
  end
end

local function define(ns, id, extra)
  local spec = {
    id = id, label = "Label " .. id, kind = "misc",
    create = function(spec) spec.frame = CreateFrame("Frame", nil, UIParent) end,
  }
  for k, v in pairs(extra or {}) do spec[k] = v end
  return ns.Modules.define(spec)
end

-- Runs fn(ns, client) with a fake client (no LibStub: Glue works without
-- LibEditMode), restoring the globals even on failure.
local function withClient(fn)
  local client = fakes.client{}
  local ok, err = pcall(fakes.withGlobals, { LibStub = fakes.NIL }, function() fn(load(), client) end)
  client.restore()
  if not ok then error(err, 0) end
end

h.test("entries follow module order and enabled state", function()
  local ns = load()
  define(ns, "b")
  define(ns, "a")
  define(ns, "c")
  ns.Modules.setEnabled("a", false)
  h.eq(ns.EditMode.Checklist.entries(), {
    { id = "b", label = "Label b", checked = true },
    { id = "a", label = "Label a", checked = false },
    { id = "c", label = "Label c", checked = true },
  })
  ns.Modules.setEnabled("a", true)
  h.eq(ns.EditMode.Checklist.entries()[2].checked, true)
end)

h.test("entries are empty without modules", function()
  h.eq(load().EditMode.Checklist.entries(), {})
end)

h.test("toggle hides and shows the module frame", function()
  withClient(function(ns)
    local a = define(ns, "a")
    ns.EditMode.Glue.registerAll()
    h.eq(ns.EditMode.Checklist.toggle("a", false), false)
    h.eq(ns.Modules.isEnabled("a"), false)
    h.eq(a.frame:IsShown(), false)
    h.eq(ns.EditMode.Checklist.toggle("a", true), false)
    h.eq(ns.Modules.isEnabled("a"), true)
    h.eq(a.frame:IsShown(), true)
  end)
end)

h.test("toggle on creates a module that was off at login", function()
  withClient(function(ns)
    local a = define(ns, "a")
    ns.Modules.setEnabled("a", false)
    ns.EditMode.Glue.registerAll()
    h.eq(a.frame, nil)
    local said
    ns.Util.say = function(msg) said = msg end
    ns.EditMode.Checklist.toggle("a", true)
    h.eq(a.frame ~= nil, true)
    -- the library makes it selectable only from the next Edit Mode open
    h.eq(said, "Reopen Edit Mode to move it")
  end)
end)

h.test("toggle of a module hiding Blizzard frames asks for a reload", function()
  withClient(function(ns)
    define(ns, "a", { blizzard = { "PlayerFrame" } })
    ns.EditMode.Glue.registerAll()
    local said
    ns.Util.say = function(msg) said = msg end
    h.eq(ns.EditMode.Checklist.toggle("a", false), true)
    h.eq(said, "Type /reload to apply")
  end)
end)

-- A fake LibEditMode that records system settings (AnotherHUD adds none).
local function fakeLem()
  local lem = { SettingType = { Checkbox = 1 }, added = {} }
  function lem:AddSystemSettings(system, settings, sub)
    self.added[#self.added + 1] = { system = system, settings = settings, sub = sub }
  end
  return lem
end

h.test("checklist attach waits for Blizzard's Edit Mode window", function()
  withClient(function(ns)
    define(ns, "a")
    -- no Edit Mode window in this client
    fakes.withGlobals({ EditModeManagerFrame = fakes.NIL }, function()
      h.eq(ns.EditMode.Checklist.attach(), false)
    end)
    local manager = fakes.frame("EditModeManagerFrame")
    manager._shown = false
    local hooked = {}
    manager.HookScript = function(self, ev, fn) hooked[ev] = fn end
    -- record what the box is parented to
    local made = {}
    local create = _G.CreateFrame
    local wrapped = function(kind, name, parent, template)
      local f = create(kind, name, parent, template)
      made[#made + 1] = { frame = f, parent = parent, template = template }
      return f
    end
    fakes.withGlobals({ EditModeManagerFrame = manager, CreateFrame = wrapped }, function()
      h.eq(ns.EditMode.Checklist.attach(), true)
      h.eq(#made, 0) -- window not shown yet: nothing built
      h.eq(type(hooked.OnShow), "function")
      h.eq(type(hooked.OnHide), "function")
      hooked.OnShow(manager)
      local box = made[1]
      h.eq(box.template, "BackdropTemplate")
      -- parented to UIParent (not Blizzard's window), anchored under it
      h.eq(box.parent, UIParent)
      h.eq(rawget(box.frame, "ignoreInLayout"), nil)
      h.eq(lastPoint(box.frame), { "SetPoint", "TOPLEFT", manager, "BOTTOMLEFT", 0, -4 })
      h.eq(box.frame:IsShown(), true)
      hooked.OnHide(manager)
      h.eq(box.frame:IsShown(), false)
      local count = #made
      hooked.OnShow(manager) -- built once, shown and refreshed after
      h.eq(#made, count)
      h.eq(box.frame:IsShown(), true)
      h.eq(ns.EditMode.Checklist.attach(), false)
    end)
  end)
end)

h.test("Core.init attaches the checklist and adds no action bar setting", function()
  local client = fakes.client{}
  local lem = fakeLem()
  lem.frames = 0
  function lem:AddFrame() self.frames = self.frames + 1 end
  function lem:AddFrameSettings() end
  function lem:AddFrameSettingsButtons() end
  function lem:RegisterCallback() end
  function lem:GetActiveLayoutName() return "Modern" end
  local manager = fakes.frame("EditModeManagerFrame")
  local hooked = false
  manager.HookScript = function() hooked = true end
  local ok, err = pcall(fakes.withGlobals, {
    LibStub = fakes.libstub({ LibEditMode = lem }),
    Enum = { EditModeSystem = { ActionBar = 0 }, EditModeActionBarSystemIndices = { MainBar = 1 } },
    AnotherHUDDB = fakes.NIL, AnotherHUDCharDB = fakes.NIL,
    EditModeManagerFrame = manager,
  }, function()
    -- inside withGlobals: the unit API keeps this test's Enum and adds its own
    local units = fakes.units({})
    local ok2, err2 = pcall(function()
      local ns = h.load(h.toc())
      ns.Core.init()
      h.eq(lem.frames, 9) -- the unit frames, the player cast bar and resource bar holders, Party and Boss
      h.eq(ns.Modules.get("player").frame ~= nil, true)
      h.eq(#lem.added, 0) -- action bars are another addon's
      h.eq(hooked, true)
    end)
    units.restore()
    if not ok2 then error(err2, 0) end
  end)
  client.restore()
  if not ok then error(err, 0) end
end)

h.test("German checklist texts fit 24 glyphs", function()
  local ns
  fakes.withGlobals({ GetLocale = function() return "deDE" end }, function() ns = h.load(h.toc()) end)
  for _, text in ipairs({ "Width", "Height",
    "Size", "Look", "Type /reload to apply" }) do
    h.eq(ns.L[text] ~= text, true, text .. " translated")
    h.eq(ns.Options.glyphs(ns.L[text]) <= 24, true, ns.L[text])
  end
end)

h.test("children are not listed", function()
  local ns = load()
  define(ns, "a")
  define(ns, "b", { parent = "a" })
  local entries = ns.EditMode.Checklist.entries()
  h.eq(#entries, 1)
  h.eq(entries[1].id, "a")
end)
