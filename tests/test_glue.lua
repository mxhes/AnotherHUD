local h = ...
local fakes = dofile("tests/fakes.lua")

-- A fake LibEditMode that records what the glue registers.
local function fakeLem(active)
  local lem = {
    active = active, frames = {}, settings = {}, buttons = {}, callbacks = {}, events = {},
    SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2, ColorPicker = 10, Divider = "divider" },
  }
  function lem:AddFrame(frame, callback, default, name)
    self.frames[#self.frames + 1] = { frame = frame, default = default, name = name }
    self.callbacks[frame] = callback
  end
  function lem:AddFrameSettings(frame, settings) self.settings[frame] = settings end
  function lem:AddFrameSettingsButtons(frame, buttons) self.buttons[frame] = buttons end
  function lem:RegisterCallback(event, fn)
    self.events[event] = self.events[event] or {}
    table.insert(self.events[event], fn)
  end
  function lem:GetActiveLayoutName() return self.active end
  function lem:fire(event, ...)
    for _, fn in ipairs(self.events[event] or {}) do fn(...) end
  end
  return lem
end

-- Runs fn(ns, lem, client) with a fake client and a fake LibStub (no
-- LibEditMode when opts.noLem), then restores the globals even on failure.
local function with(opts, fn)
  local client = fakes.client{}
  local lem = not opts.noLem and fakeLem(opts.active or "Modern") or nil
  local prevStub = rawget(_G, "LibStub")
  _G.LibStub = function(name, silent)
    if name == "LibEditMode" and lem then return lem end
    if not silent then error("no library " .. tostring(name)) end
  end
  local ok, err = pcall(function()
    local ns = h.load({ "Core/Util.lua", "Core/Theme.lua", "Core/DB.lua", "Core/Modules.lua", "Core/Combat.lua",
      "Core/Options.lua", "EditMode/Panel.lua", "EditMode/Snap.lua", "EditMode/Glue.lua" })
    ns.db, ns.chardb = ns.DB.init(nil, nil)
    fn(ns, lem, client)
  end)
  client.restore()
  _G.LibStub = prevStub
  if not ok then error(err, 0) end
end

local function define(ns, id, extra)
  local spec = {
    id = id, label = "Label " .. id, kind = "unit",
    defaults = { width = 200 },
    settings = { { section = "Size", controls = {
      { key = "width", type = "slider", label = "Width", min = 80, max = 400, step = 1 },
    } } },
    defaultPosition = { point = "CENTER", x = 0, y = -100 },
    create = function(spec)
      spec.created = (spec.created or 0) + 1
      spec.frame = CreateFrame("Frame", "AnotherHUDTest_" .. spec.id, UIParent)
    end,
  }
  for k, v in pairs(extra or {}) do spec[k] = v end
  return ns.Modules.define(spec)
end

local function lastPoint(frame)
  for i = #frame.calls, 1, -1 do
    local c = frame.calls[i]
    if c[1] == "SetPoint" then return c end
  end
end

h.test("registers every enabled module", function()
  with({}, function(ns, lem)
    local a, b = define(ns, "a"), define(ns, "b")
    ns.EditMode.Glue.registerAll()
    h.eq(#lem.frames, 2)
    h.eq(lem.frames[1].frame, a.frame)
    h.eq(lem.frames[1].name, "Label a")
    h.eq(lem.frames[1].default, { point = "CENTER", x = 0, y = -100 })
    h.eq(lem.frames[2].frame, b.frame)
    h.eq(#lem.settings[a.frame], 2) -- header + width
    local texts = {}
    for _, button in ipairs(lem.buttons[a.frame]) do texts[#texts + 1] = button.text end
    -- only Settings: the library adds its own Reset Settings / Reset Position
    h.eq(texts, { "Settings" })
    h.eq(#lem.events.layout, 1)
    -- a second call registers nothing twice and creates nothing again
    ns.EditMode.Glue.registerAll()
    h.eq(#lem.frames, 2)
    h.eq(a.created, 1)
  end)
end)

h.test("skips disabled modules", function()
  with({}, function(ns, lem)
    define(ns, "a")
    local b = define(ns, "b")
    ns.Modules.setEnabled("b", false)
    ns.EditMode.Glue.registerAll()
    h.eq(#lem.frames, 1)
    h.eq(lem.frames[1].name, "Label a")
    h.eq(b.created, nil)
    h.eq(b.frame, nil)
  end)
end)

h.test("create waits for combat to end", function()
  with({}, function(ns, lem, client)
    local a = define(ns, "a")
    client.setCombat(true)
    ns.EditMode.Glue.registerAll()
    h.eq(a.frame, nil)
    h.eq(#lem.frames, 0)
    client.setCombat(false)
    client.fire("PLAYER_REGEN_ENABLED")
    h.eq(a.created, 1)
    h.eq(#lem.frames, 1)
  end)
end)

h.test("onMove saves per layout", function()
  with({}, function(ns, lem)
    local a = define(ns, "a")
    ns.EditMode.Glue.registerAll()
    -- far from the screen edges and centre lines (1920 x 1080): no snap
    a.frame._left, a.frame._bottom, a.frame._width, a.frame._height = 500, 500, 100, 50
    lem.callbacks[a.frame](a.frame, "Layout 2", "CENTER", -410, -15)
    h.eq(ns.db.positions["Layout 2"].a, { point = "CENTER", x = -410, y = -15 })
    h.eq(ns.db.positions.Modern, nil)
    -- no layout name from the library: the active one
    lem.callbacks[a.frame](a.frame, nil, "CENTER", -400, -15)
    h.eq(ns.db.positions.Modern.a, { point = "CENTER", x = -400, y = -15 })
  end)
end)

h.test("onMove snaps to the screen edge and other frames", function()
  with({}, function(ns, lem)
    local a, b = define(ns, "a"), define(ns, "b")
    ns.EditMode.Glue.registerAll()
    -- a: left edge 4 px from the screen's left edge
    a.frame._left, a.frame._bottom, a.frame._width, a.frame._height = 4, 300, 100, 50
    lem.callbacks[a.frame](a.frame, "Modern", "LEFT", 4, -215)
    h.eq(ns.db.positions.Modern.a, { point = "LEFT", x = 0, y = -215 })
    h.eq(lastPoint(a.frame), { "SetPoint", "LEFT", UIParent, "LEFT", 0, -215 })
    -- b: bottom edge 5 px above a's top edge (350)
    b.frame._left, b.frame._bottom, b.frame._width, b.frame._height = 300, 355, 100, 50
    lem.callbacks[b.frame](b.frame, "Modern", "BOTTOMLEFT", 300, 355)
    h.eq(ns.db.positions.Modern.b, { point = "BOTTOMLEFT", x = 300, y = 350 })
    -- the library's own Reset Position passes the default: kept as it is
    a.frame._left = 3
    lem.callbacks[a.frame](a.frame, "Modern", "CENTER", 0, -100)
    h.eq(ns.db.positions.Modern.a, { point = "CENTER", x = 0, y = -100 })
  end)
end)

h.test("arrow-key nudge leaves a snap line, a drag still snaps", function()
  with({}, function(ns, lem)
    local a = define(ns, "a")
    ns.EditMode.Glue.registerAll()
    a.frame._left, a.frame._bottom, a.frame._width, a.frame._height = 4, 300, 100, 50
    lem.callbacks[a.frame](a.frame, "Modern", "LEFT", 4, -215)
    h.eq(ns.db.positions.Modern.a, { point = "LEFT", x = 0, y = -215 })
    -- one arrow-key step (1 px on one axis) off the snapped edge: kept
    a.frame._left = 1
    lem.callbacks[a.frame](a.frame, "Modern", "LEFT", 1, -215)
    h.eq(ns.db.positions.Modern.a, { point = "LEFT", x = 1, y = -215 })
    -- the library re-reads the position from the frame: float noise on the
    -- other axis is still a nudge
    a.frame._left = 2
    lem.callbacks[a.frame](a.frame, "Modern", "LEFT", 2, -215.000001)
    h.eq(ns.db.positions.Modern.a, { point = "LEFT", x = 2, y = -215.000001 })
    -- a drag (both axes) within the threshold snaps again
    a.frame._left, a.frame._bottom = 5, 310
    lem.callbacks[a.frame](a.frame, "Modern", "LEFT", 5, -205)
    h.eq(ns.db.positions.Modern.a, { point = "LEFT", x = 0, y = -205 })
  end)
end)

h.test("snap distance comes from Theme.sizes", function()
  with({}, function(ns, lem)
    local a = define(ns, "a")
    ns.EditMode.Glue.registerAll()
    ns.Theme.sizes.snapDistance = 2
    a.frame._left, a.frame._bottom, a.frame._width, a.frame._height = 4, 300, 100, 50
    lem.callbacks[a.frame](a.frame, "Modern", "LEFT", 4, -215)
    h.eq(ns.db.positions.Modern.a, { point = "LEFT", x = 4, y = -215 })
  end)
end)

h.test("layout rename moves its positions, delete drops them", function()
  with({}, function(ns, lem)
    local a = define(ns, "a")
    ns.EditMode.Glue.registerAll()
    h.eq(#lem.events.rename, 1)
    h.eq(#lem.events.delete, 1)
    ns.db.positions["Layout 2"] = { a = { point = "LEFT", x = 20, y = 30 } }
    ns.db.positions.Other = { a = { point = "TOP", x = 1, y = 2 } }
    ns.db.lastLayout = "Layout 2"
    lem:fire("rename", "Layout 2", "Raid", 3)
    h.eq(ns.db.positions["Layout 2"], nil)
    h.eq(ns.db.positions.Raid, { a = { point = "LEFT", x = 20, y = 30 } })
    h.eq(ns.db.lastLayout, "Raid")
    -- renaming a layout that is not the last one seen keeps lastLayout
    lem:fire("rename", "Other", "Solo", 4)
    h.eq(ns.db.positions.Solo, { a = { point = "TOP", x = 1, y = 2 } })
    h.eq(ns.db.lastLayout, "Raid")
    -- a rename of a layout with nothing saved changes nothing
    lem:fire("rename", "Empty", "Still empty", 5)
    h.eq(ns.db.positions["Still empty"], nil)
    lem:fire("delete", "Solo")
    h.eq(ns.db.positions.Solo, nil)
    h.eq(ns.db.positions.Raid.a.x, 20)
    h.eq(a.frame ~= nil, true)
  end)
end)

h.test("Edit Mode name is translated", function()
  with({}, function(ns, lem)
    rawset(ns.L, "Label a", "Beschriftung a")
    define(ns, "a")
    ns.EditMode.Glue.registerAll()
    h.eq(lem.frames[1].name, "Beschriftung a")
  end)
end)

h.test("new layout uses default position", function()
  with({}, function(ns, lem)
    local a = define(ns, "a", { defaultPosition = { point = "TOP", x = 0, y = -100 } })
    ns.db.positions.Modern = { a = { point = "LEFT", x = 20, y = 30 } }
    ns.EditMode.Glue.registerAll()
    h.eq(lastPoint(a.frame), { "SetPoint", "LEFT", UIParent, "LEFT", 20, 30 })
    lem:fire("layout", "Layout 2", 3)
    h.eq(lastPoint(a.frame), { "SetPoint", "TOP", UIParent, "TOP", 0, -100 })
    lem:fire("layout", "Modern", 1)
    h.eq(lastPoint(a.frame), { "SetPoint", "LEFT", UIParent, "LEFT", 20, 30 })
    -- no defaultPosition at all: the screen centre
    local b = define(ns, "b", { defaultPosition = false })
    ns.EditMode.Glue.registerAll()
    lem:fire("layout", "Layout 3", 4)
    h.eq(lastPoint(b.frame), { "SetPoint", "CENTER", UIParent, "CENTER", 0, 0 })
  end)
end)

h.test("positions queue in combat", function()
  with({}, function(ns, lem, client)
    local a = define(ns, "a")
    ns.EditMode.Glue.registerAll()
    ns.db.positions["Layout 2"] = { a = { point = "LEFT", x = 5, y = 6 } }
    client.setCombat(true)
    lem:fire("layout", "Layout 2", 3)
    h.eq(lastPoint(a.frame), { "SetPoint", "CENTER", UIParent, "CENTER", 0, -100 })
    client.setCombat(false)
    client.fire("PLAYER_REGEN_ENABLED")
    h.eq(lastPoint(a.frame), { "SetPoint", "LEFT", UIParent, "LEFT", 5, 6 })
  end)
end)

h.test("settings button opens the settings window", function()
  with({}, function(ns, lem)
    local a = define(ns, "a")
    ns.EditMode.Glue.registerAll()
    local buttons = lem.buttons[a.frame]
    -- Settings: no Settings window yet, a chat line instead
    local said
    ns.Util.say = function(msg) said = msg end
    buttons[1].click()
    h.eq(said, "Settings window comes later")
    local opened
    ns.UI = { Settings = { open = function(id) opened = id end } }
    buttons[1].click()
    h.eq(opened, "a")
  end)
end)

h.test("library reset rows go through Options.set and onMove", function()
  with({}, function(ns, lem)
    local a = define(ns, "a")
    ns.EditMode.Glue.registerAll()
    -- the library's Reset Settings calls set(layout, default, true) per row
    ns.Options.set("a", "width", 300)
    for _, row in ipairs(lem.settings[a.frame]) do
      if row.set and row.default ~= nil then row.set("Modern", row.default, true) end
    end
    h.eq(ns.Options.get("a", "width"), 200)
    -- its Reset Position calls our move callback with the default
    ns.db.positions.Modern = { a = { point = "LEFT", x = 20, y = 30 } }
    a.frame._left, a.frame._bottom, a.frame._width, a.frame._height = 2, 2, 100, 50
    lem.callbacks[a.frame](a.frame, "Modern", "CENTER", 0, -100)
    h.eq(ns.db.positions.Modern.a, { point = "CENTER", x = 0, y = -100 })
  end)
end)

h.test("frames anchor to their parent", function()
  with({}, function(ns, lem)
    local holder = fakes.frame("Holder")
    local a = define(ns, "a", { create = function(spec)
      spec.frame = CreateFrame("Frame", "AnotherHUDTest_a", holder)
      spec.frame._parent = holder -- the fake CreateFrame ignores the parent
    end })
    ns.EditMode.Glue.registerAll()
    h.eq(lastPoint(a.frame), { "SetPoint", "CENTER", holder, "CENTER", 0, -100 })
  end)
end)

h.test("works without LibEditMode", function()
  with({ noLem = true }, function(ns)
    local a = define(ns, "a")
    local b = define(ns, "b")
    ns.db.lastLayout = "Modern"
    ns.db.positions.Modern = { b = { point = "LEFT", x = 20, y = 30 } }
    ns.EditMode.Glue.registerAll()
    h.eq(lastPoint(a.frame), { "SetPoint", "CENTER", UIParent, "CENTER", 0, -100 })
    h.eq(lastPoint(b.frame), { "SetPoint", "LEFT", UIParent, "LEFT", 20, 30 })
  end)
  -- and without LibStub at all
  local client = fakes.client{}
  local prevStub = rawget(_G, "LibStub")
  _G.LibStub = nil
  local ok, err = pcall(function()
    local ns = h.load({ "Core/Util.lua", "Core/Theme.lua", "Core/DB.lua", "Core/Modules.lua", "Core/Combat.lua",
      "Core/Options.lua", "EditMode/Panel.lua", "EditMode/Snap.lua", "EditMode/Glue.lua" })
    ns.db, ns.chardb = ns.DB.init(nil, nil)
    local a = define(ns, "a")
    ns.EditMode.Glue.registerAll()
    h.eq(lastPoint(a.frame), { "SetPoint", "CENTER", UIParent, "CENTER", 0, -100 })
  end)
  client.restore()
  _G.LibStub = prevStub
  if not ok then error(err, 0) end
end)

h.test("Core.init loads saved state and registers", function()
  with({}, function(ns, lem)
    local core = h.load({ "Core/Util.lua", "Core/Theme.lua", "Core/DB.lua", "Core/Modules.lua", "Core/Combat.lua",
      "Core/Options.lua", "EditMode/Panel.lua", "EditMode/Snap.lua", "EditMode/Glue.lua", "Core/Core.lua" })
    define(core, "a")
    local prevDB, prevChar = rawget(_G, "AnotherHUDDB"), rawget(_G, "AnotherHUDCharDB")
    _G.AnotherHUDDB, _G.AnotherHUDCharDB = nil, nil
    local ok, err = pcall(core.Core.init)
    local db, chardb = _G.AnotherHUDDB, _G.AnotherHUDCharDB
    _G.AnotherHUDDB, _G.AnotherHUDCharDB = prevDB, prevChar
    if not ok then error(err, 0) end
    h.eq(type(db.positions), "table")
    h.eq(chardb.profile, "Default")
    h.eq(core.db, db)
    h.eq(#lem.frames, 1)
  end)
end)

h.test("Boot starts the addon on its ADDON_LOADED", function()
  local client = fakes.client{}
  local prevStub = rawget(_G, "LibStub")
  local prevDB, prevChar = rawget(_G, "AnotherHUDDB"), rawget(_G, "AnotherHUDCharDB")
  _G.LibStub, _G.AnotherHUDDB, _G.AnotherHUDCharDB = nil, nil, nil
  local ok, err = pcall(function()
    local ns = h.load(h.toc())
    client.fire("ADDON_LOADED", "SomeOtherAddon")
    h.eq(ns.db, nil)
    client.fire("ADDON_LOADED", "AnotherHUD")
    h.eq(type(ns.db), "table")
    h.eq(ns.db, _G.AnotherHUDDB)
  end)
  client.restore()
  _G.LibStub, _G.AnotherHUDDB, _G.AnotherHUDCharDB = prevStub, prevDB, prevChar
  if not ok then error(err, 0) end
end)

h.test("German button label fits 24 glyphs", function()
  local prevLocale = rawget(_G, "GetLocale")
  _G.GetLocale = function() return "deDE" end
  local ok, ns = pcall(h.load, h.toc())
  _G.GetLocale = prevLocale
  assert(ok, ns)
  for _, text in ipairs({ "Settings" }) do
    h.eq(ns.L[text] ~= text, true, text .. " translated")
    h.eq(ns.Options.glyphs(ns.L[text]) <= 24, true, ns.L[text])
  end
end)
