-- Tests for the client fakes in tests/fakes.lua.
local h = ...
local fakes = dofile("tests/fakes.lua")

h.test("secret value throws on arithmetic", function()
  local s = fakes.secret(5)
  h.eq(pcall(function() return s + 1 end), false)
  h.eq(pcall(function() return 1 - s end), false)
  h.eq(pcall(function() return s * 2 end), false)
  h.eq(pcall(function() return s / 2 end), false)
  h.eq(pcall(function() return s % 2 end), false)
  h.eq(pcall(function() return -s end), false)
end)

h.test("secret value throws on compare and concat", function()
  local s, t = fakes.secret(5), fakes.secret(6)
  h.eq(pcall(function() return s < 10 end), false)
  h.eq(pcall(function() return s <= 10 end), false)
  h.eq(pcall(function() return 10 < s end), false)
  h.eq(pcall(function() return s == t end), false)
  h.eq(pcall(function() return s .. "x" end), false)
  h.eq(fakes.isSecret(s), true)
  h.eq(fakes.isSecret(5), false)
end)

h.test("fake statusbar accepts secret", function()
  local client = fakes.client{}
  local bar = CreateFrame("StatusBar", "TestBar", UIParent)
  local s = fakes.secret(42)
  bar:SetValue(s)
  h.eq(rawequal(bar:GetValue(), s), true)
  local fs = bar:CreateFontString()
  fs:SetText(s)
  h.eq(rawequal(fs:GetText(), s), true)
  h.eq(issecretvalue(bar:GetValue()), true)
  client.restore()
end)

h.test("frame records calls and answers unset fields with no-ops", function()
  local f = fakes.frame("F")
  f:SetPoint("CENTER", 0, 0)
  f:Show()
  f:Hide()
  f:SetParent(nil)
  f:SomethingUnknown(1, 2)
  h.eq(#f.calls, 4)
  h.eq(f.calls[1][1], "SetPoint")
  h.eq(f.calls[1][2], "CENTER")
  h.eq(f.calls[4][1], "SetParent")
  h.eq(f:IsShown(), false)
end)

h.test("fire reaches registered handlers", function()
  local client = fakes.client{}
  local got = {}
  local a = CreateFrame("Frame")
  a:RegisterEvent("PLAYER_LOGIN")
  a:SetScript("OnEvent", function(_, event, x) got[#got + 1] = event .. ":" .. tostring(x) end)
  local b = CreateFrame("Frame")
  b:SetScript("OnEvent", function() got[#got + 1] = "unregistered" end)
  client.fire("PLAYER_LOGIN", 7)
  client.fire("OTHER_EVENT")
  h.eq(got, { "PLAYER_LOGIN:7" })
  client.restore()
end)

h.test("client combat, hooks, timer and restore", function()
  local client = fakes.client{ inCombat = true }
  h.eq(InCombatLockdown(), true)
  client.setCombat(false)
  h.eq(InCombatLockdown(), false)
  local ran = 0
  C_Timer.After(1, function() ran = ran + 1 end)
  h.eq(ran, 1) -- runs immediately
  local target = { Do = function(_, v) return v end }
  local seen
  hooksecurefunc(target, "Do", function(_, v) seen = v end)
  h.eq(target:Do(3), 3)
  h.eq(seen, 3)
  client.restore()
  h.eq(CreateFrame, nil)
  h.eq(InCombatLockdown, nil)
  h.eq(issecretvalue, nil)
end)
