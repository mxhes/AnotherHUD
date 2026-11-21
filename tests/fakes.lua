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
function methods.GetScript(self, ev) return self._scripts[ev] end
function methods.RegisterEvent(self, ev) self._events[ev] = true end
function methods.UnregisterEvent(self, ev) self._events[ev] = nil end
function methods.UnregisterAllEvents(self) self._events = {} end

function fakes.frame(name)
  local f = { calls = {}, _scripts = {}, _events = {}, _shown = true, _name = name }
  setmetatable(f, { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) ~= "string" or k:sub(1, 1) == "_" then return nil end
    if k:match("^Create") then return function() return fakes.frame() end end
    return noop
  end })
  return f
end

local GLOBALS = { "CreateFrame", "UIParent", "InCombatLockdown", "hooksecurefunc",
  "C_Timer", "issecretvalue" }

-- Installs the client globals into _G. C_Timer.After runs its callback
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
  _G.InCombatLockdown = function() return inCombat end
  _G.issecretvalue = fakes.isSecret
  _G.C_Timer = { After = function(_, fn) fn() end }
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

  local handle = {}
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

return fakes
