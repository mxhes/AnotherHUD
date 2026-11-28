local h = ...
local fakes = dofile("tests/fakes.lua")

-- The minimap badge part (Map/Badge.lua): the level badge look with an icon.

local function load()
  return h.load({ "Core/Util.lua", "Core/Locale.lua", "Core/Theme.lua", "Core/UnitLayout.lua",
    "Units/Parts/Ring.lua", "Map/Badge.lua" })
end

local function withClient(fn)
  local client = fakes.client({})
  local ok, err = pcall(fn, load())
  client.restore()
  if not ok then error(err, 0) end
end

local function shown(list)
  local n = 0
  for _, t in ipairs(list) do if t:IsShown() then n = n + 1 end end
  return n
end

h.test("a badge has the ring lines, the fill and a gold icon", function()
  withClient(function(ns)
    local T = ns.Theme
    local parent = CreateFrame("Frame", nil, UIParent)
    local b = ns.Map.Badge.create(parent)
    b:layout(18, T.skins.classic)
    local n = #ns.Units.Parts.Ring.shadesOf(T.skins.classic.border)
    h.eq({ b.button._width, b.button._height }, { 18, 18 })
    h.eq(shown(b.lines), n)
    h.eq(b.lines[1]._width, 18)
    h.eq(b.fill._width, 18 - 2 * n)
    h.eq(b.icon._width, 18 * T.sizes.minimap.badgeIcon)
    h.eq(b.icon._color, T.colors.gold)
    b:setIcon("Interface\\Some\\Icon")
    h.eq(b.icon._texture, "Interface\\Some\\Icon")
  end)
end)

h.test("the glow follows setGlow", function()
  withClient(function(ns)
    local T = ns.Theme
    local b = ns.Map.Badge.create(CreateFrame("Frame", nil, UIParent))
    b:layout(18, T.skins.classic)
    h.eq(b.glow:IsShown(), false)
    b:setGlow(true)
    h.eq(b.glow:IsShown(), true)
    h.eq(b.glow._width, 18 + 2 * T.sizes.minimap.glow)
    b:setGlow(false)
    h.eq(b.glow:IsShown(), false)
  end)
end)
