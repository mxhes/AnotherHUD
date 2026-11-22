-- Test fakes for the client (helper module, not a test file; load it with
-- dofile("tests/fakes.lua")). Lua 5.1-compatible.
local fakes = {}

local unpack = unpack or table.unpack
local function noop() end

-- Secret values: stand-ins for the client's restricted health / power / cast
-- numbers. Anything but storing or passing them on throws.
local secrets = setmetatable({}, { __mode = "k" })
local secretMeta = {}
for _, op in ipairs({ "add", "sub", "mul", "div", "mod", "pow", "unm", "lt", "le", "eq", "concat", "len" }) do
  secretMeta["__" .. op] = function() error("secret value: " .. op, 2) end
end
secretMeta.__tostring = function() return "secret" end

-- `n` is kept only so a test can tell secrets apart in a failure message.
function fakes.secret(n)
  local s = setmetatable({}, secretMeta)
  secrets[s] = n or true
  return s
end

function fakes.isSecret(v)
  return type(v) == "table" and secrets[v] ~= nil
end

-- Fake frames: any unset field answers with a no-op function (fields starting
-- with "_" and "calls" answer nil). Create* returns another fake frame.
-- SetPoint / Show / Hide / SetParent are recorded in frame.calls as
-- { "Name", args... }. SetValue / SetText store the value as given.
local methods = {}
local function record(name, after)
  methods[name] = function(self, ...)
    self.calls[#self.calls + 1] = { name, ... }
    if after then after(self, ...) end
  end
end
record("SetPoint")
record("Show", function(self) self._shown = true end)
record("Hide", function(self) self._shown = false end)
record("SetParent", function(self, p) self._parent = p end)
function methods.IsShown(self) return self._shown end
function methods.GetParent(self) return self._parent end
function methods.GetName(self) return self._name end
function methods.SetValue(self, v) self._value = v end
function methods.GetValue(self) return self._value end
function methods.SetText(self, t) self._text = t end
function methods.GetText(self) return self._text end
function methods.SetScript(self, ev, fn) self._scripts[ev] = fn end
-- HookScript chains: the earlier handler (if any) runs first, then fn.
function methods.HookScript(self, ev, fn)
  local prev = self._scripts[ev]
  if not prev then self._scripts[ev] = fn; return end
  self._scripts[ev] = function(...) prev(...); fn(...) end
end
function methods.GetScript(self, ev) return self._scripts[ev] end
function methods.RegisterEvent(self, ev) self._events[ev] = true end
function methods.RegisterUnitEvent(self, ev) self._events[ev] = true end
-- SetFormattedText keeps the format and the arguments as given (they may be
-- secret values) and clears _text.
function methods.SetFormattedText(self, fmt, ...)
  self._fmt, self._args, self._text = fmt, { ... }, nil
end
function methods.SetAttribute(self, k, v) self._attrs[k] = v end
function methods.GetAttribute(self, k) return self._attrs[k] end
function methods.SetAlpha(self, a) self._alpha = a end
function methods.GetAlpha(self) return self._alpha or 1 end
function methods.SetAlphaFromBoolean(self, b, yes, no) self._alphaFrom = { b, yes, no } end
function methods.SetTimerDuration(self, d, interp, dir) self._timer = { d, interp, dir } end
function methods.SetTexture(self, file) self._texture = file end
function methods.SetTextureSliceMargins(self, l, t, r, b) self._slice = { l, t, r, b } end
function methods.SetSize(self, w, h) self._width, self._height = w, h end
-- SetVertexColor / SetTextColor keep { r, g, b, a } (a as given, may be nil).
function methods.SetVertexColor(self, r, g, b, a) self._color = { r, g, b, a } end
function methods.SetTextColor(self, r, g, b, a) self._textColor = { r, g, b, a } end
function methods.SetFont(self, file, size, flags) self._font = { file, size, flags } end
function methods.SetWidth(self, w) self._width = w end
function methods.SetHeight(self, h) self._height = h end
function methods.UnregisterEvent(self, ev) self._events[ev] = nil end
function methods.UnregisterAllEvents(self) self._events = {} end
-- Geometry: a test places a frame by setting _left / _bottom / _width /
-- _height (UIParent units; SetPoint does not move it). _scale defaults to 1.
function methods.GetLeft(self) return self._left end
function methods.GetBottom(self) return self._bottom end
function methods.GetWidth(self) return self._width end
function methods.GetHeight(self) return self._height end
function methods.GetScale(self) return self._scale or 1 end

function fakes.frame(name)
  local f = { calls = {}, _scripts = {}, _events = {}, _attrs = {}, _shown = true, _name = name }
  setmetatable(f, { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) ~= "string" or k:sub(1, 1) == "_" then return nil end
    if k:match("^Create") then return function() return fakes.frame() end end
    return noop
  end })
  return f
end

-- Sentinel for withGlobals: set this global to nil.
fakes.NIL = {}

-- Sets every _G[k] = v from tbl (fakes.NIL clears one), runs fn(), restores
-- all of them even when fn throws, then rethrows.
function fakes.withGlobals(tbl, fn)
  local previous = {}
  for k, v in pairs(tbl) do
    previous[k] = rawget(_G, k)
    if v == fakes.NIL then _G[k] = nil else _G[k] = v end
  end
  local ok, err = pcall(fn)
  for k in pairs(tbl) do _G[k] = previous[k] end
  if not ok then error(err, 0) end
end

local GLOBALS = { "CreateFrame", "UIParent", "InCombatLockdown", "hooksecurefunc",
  "C_Timer", "issecretvalue", "RegisterStateDriver", "UnregisterStateDriver" }

-- Installs the client globals into _G (UIParent is opts.width x opts.height,
-- 1920 x 1080 by default). C_Timer.After runs its callback
-- immediately (no queue: tests assert right after the call). Returns a handle:
--   fire(event, ...)  calls OnEvent of every frame that registered `event`
--   setCombat(bool)   changes what InCombatLockdown answers
--   restore()         puts every installed global back (call it at the end of
--                     each test that uses client, so tests do not leak)
function fakes.client(opts)
  opts = opts or {}
  local inCombat = opts.inCombat and true or false
  local created = {}
  local previous = {}
  for _, k in ipairs(GLOBALS) do previous[k] = rawget(_G, k) end

  _G.CreateFrame = function(_, name)
    local f = fakes.frame(name)
    created[#created + 1] = f
    if name then _G[name] = f end
    return f
  end
  _G.UIParent = fakes.frame("UIParent")
  _G.UIParent._left, _G.UIParent._bottom = 0, 0
  _G.UIParent._width, _G.UIParent._height = opts.width or 1920, opts.height or 1080
  _G.InCombatLockdown = function() return inCombat end
  _G.issecretvalue = fakes.isSecret
  _G.C_Timer = { After = function(_, fn) fn() end }
  -- handle.drivers[frame] = { attr, cond } while a state driver is registered.
  local drivers = {}
  _G.RegisterStateDriver = function(frame, attr, cond) drivers[frame] = { attr = attr, cond = cond } end
  _G.UnregisterStateDriver = function(frame) drivers[frame] = nil end
  -- hooksecurefunc([tbl,] name, hook): wraps the original, runs the hook after.
  _G.hooksecurefunc = function(a, b, c)
    local tbl, name, hook = _G, a, b
    if type(a) == "table" then tbl, name, hook = a, b, c end
    local orig = tbl[name]
    tbl[name] = function(...)
      local r = { orig and orig(...) }
      hook(...)
      return unpack(r)
    end
  end

  local handle = { drivers = drivers }
  function handle.fire(event, ...)
    for _, f in ipairs(created) do
      local fn = f._scripts.OnEvent
      if f._events[event] and fn then fn(f, event, ...) end
    end
  end
  function handle.setCombat(v) inCombat = v and true or false end
  function handle.restore()
    for _, f in ipairs(created) do
      if f._name and rawget(_G, f._name) == f then _G[f._name] = nil end
    end
    for _, k in ipairs(GLOBALS) do _G[k] = previous[k] end
  end
  return handle
end

local UNIT_GLOBALS = { "UnitExists", "UnitName", "UnitClass", "UnitLevel", "UnitEffectiveLevel",
  "UnitClassification", "UnitReaction", "UnitIsPlayer", "UnitIsDeadOrGhost", "UnitIsConnected",
  "UnitHealth", "UnitHealthMax", "UnitHealthPercent", "UnitPower", "UnitPowerMax", "UnitPowerPercent",
  "UnitPowerType", "UnitCastingInfo", "UnitChannelInfo", "UnitCastingDuration", "UnitChannelDuration",
  "SetPortraitTexture", "RegisterStateDriver", "UnregisterStateDriver", "AbbreviateNumbers",
  "CurveConstants", "C_ClassColor", "PowerBarColor", "Enum", "GameTooltip",
  "UnitGroupRolesAssigned", "UnitIsGroupLeader", "UnitInRange" }

-- Installs the client's unit API globals reading from
-- map[unit] = { exists, name, class, level, classification, reaction, isPlayer,
--   dead, connected, health, healthMax, healthPct, power, powerMax, powerPct,
--   powerToken, casting = { name, texture, notInterruptible, duration,
--   startMs, endMs, castID, spellID, isTradeskill }, channel = { same } }.
-- Values are returned as given (secrets are never wrapped or unwrapped).
-- Retail return orders: UnitCastingInfo = name, text, texture, startTimeMs,
-- endTimeMs, isTradeSkill, castID, notInterruptible, spellId; UnitChannelInfo
-- = name, text, texture, startTimeMs, endTimeMs, isTradeSkill,
-- notInterruptible, spellId. Unknown units / missing fields answer nil
-- (UnitExists answers false). Handle: set(unit, field, value), calls[global]
-- (call counts), restore(). RegisterStateDriver / UnregisterStateDriver are
-- plain no-ops here (fakes.client records them).
function fakes.units(map)
  local handle = { calls = {}, map = map }
  local previous = {}
  for _, k in ipairs(UNIT_GLOBALS) do previous[k] = rawget(_G, k) end

  local function unit(u) return map[u] or {} end
  local function count(name) handle.calls[name] = (handle.calls[name] or 0) + 1 end
  local function field(name, key)
    _G[name] = function(u)
      count(name)
      return unit(u)[key]
    end
  end
  _G.UnitExists = function(u)
    count("UnitExists")
    return unit(u).exists and true or false
  end
  field("UnitName", "name")
  _G.UnitClass = function(u)
    count("UnitClass")
    local c = unit(u).class
    return c, c
  end
  field("UnitLevel", "level")
  field("UnitEffectiveLevel", "level")
  field("UnitClassification", "classification")
  field("UnitReaction", "reaction")
  field("UnitIsPlayer", "isPlayer")
  field("UnitIsDeadOrGhost", "dead")
  field("UnitIsConnected", "connected")
  field("UnitGroupRolesAssigned", "role")
  field("UnitIsGroupLeader", "leader")
  -- inRange, checked (checked = rangeChecked; false when the client cannot say).
  _G.UnitInRange = function(u)
    count("UnitInRange")
    local m = unit(u)
    return m.inRange, m.rangeChecked
  end
  field("UnitHealth", "health")
  field("UnitHealthMax", "healthMax")
  field("UnitHealthPercent", "healthPct")
  field("UnitPower", "power")
  field("UnitPowerMax", "powerMax")
  field("UnitPowerPercent", "powerPct")
  _G.UnitPowerType = function(u)
    count("UnitPowerType")
    return nil, unit(u).powerToken
  end
  _G.UnitCastingInfo = function(u)
    count("UnitCastingInfo")
    local c = unit(u).casting
    if not c then return end
    return c.name, c.name, c.texture, c.startMs, c.endMs, c.isTradeskill, c.castID,
      c.notInterruptible, c.spellID
  end
  _G.UnitChannelInfo = function(u)
    count("UnitChannelInfo")
    local c = unit(u).channel
    if not c then return end
    return c.name, c.name, c.texture, c.startMs, c.endMs, c.isTradeskill,
      c.notInterruptible, c.spellID
  end
  _G.UnitCastingDuration = function(u)
    count("UnitCastingDuration")
    local c = unit(u).casting
    return c and c.duration
  end
  _G.UnitChannelDuration = function(u)
    count("UnitChannelDuration")
    local c = unit(u).channel
    return c and c.duration
  end
  _G.SetPortraitTexture = function(tex, u) tex._portraitUnit = u end
  _G.RegisterStateDriver = previous.RegisterStateDriver or function() end
  _G.UnregisterStateDriver = previous.UnregisterStateDriver or function() end
  _G.AbbreviateNumbers = function(n) return n end
  _G.CurveConstants = { ScaleTo100 = "ScaleTo100", ZeroToOne = "ZeroToOne" }
  _G.C_ClassColor = { GetClassColor = function()
    return { r = 1, g = 1, b = 1, GetRGB = function() return 1, 1, 1 end }
  end }
  _G.PowerBarColor = {}
  -- Keep whatever Enum the test already installed and add the status bar enums.
  local enum = {}
  for k, v in pairs(previous.Enum or {}) do enum[k] = v end
  enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
  enum.StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 }
  _G.Enum = enum
  _G.GameTooltip = fakes.frame("GameTooltip")

  function handle.set(u, key, value)
    map[u] = map[u] or {}
    map[u][key] = value
  end
  function handle.restore()
    for _, k in ipairs(UNIT_GLOBALS) do _G[k] = previous[k] end
  end
  return handle
end

-- A LibStub shaped like the real one: a table (not a function) made callable
-- through __call, with GetLibrary(name, silent). `libs` maps name -> library.
function fakes.libstub(libs)
  local stub = { libs = libs or {}, minors = {} }
  function stub:GetLibrary(name, silent)
    local lib = self.libs[name]
    if not lib and not silent then error("Cannot find a library instance of " .. tostring(name), 2) end
    return lib, self.minors[name]
  end
  return setmetatable(stub, { __call = stub.GetLibrary })
end

return fakes
