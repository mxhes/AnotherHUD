local h = ...
local fakes = dofile("tests/fakes.lua")

local function load()
  return h.load({ "Core/Util.lua", "Core/Locale.lua", "Locales/deDE.lua", "Core/Theme.lua",
    "Core/UnitLayout.lua", "Core/Resource.lua", "Units/Parts/Panel.lua", "Bars/Segments.lua" })
end

local function withClient(fn)
  local client = fakes.client({})
  local ok, err = pcall(fn, load())
  client.restore()
  if not ok then error(err, 0) end
end

local function laid(ns, o)
  local seg = ns.Bars.Segments.create(fakes.frame())
  local opts = { w = 136, h = 18, count = 5, skin = ns.Theme.skin("classic"), texture = "Smooth",
    rgb = ns.Theme.resourceColors.holy }
  for k, v in pairs(o or {}) do opts[k] = v end
  seg:layout(opts)
  return seg, opts
end

h.test("layout splits the inner width into count slots", function()
  withClient(function(ns)
    local seg, o = laid(ns)
    local e = ns.UnitLayout.edgeWidth(o.skin.border)
    local total, shown, dividers = 0, 0, 0
    for i = 1, 5 do
      local s = seg.slots[i]
      h.eq(s.bg:IsShown(), true, "slot " .. i)
      shown = shown + 1
      total = total + s.bg._width
    end
    for i = 1, 4 do
      if seg.dividers[i]:IsShown() then dividers = dividers + 1 end
    end
    h.eq(shown, 5)
    h.eq(dividers, 4)
    h.eq(math.abs(total - (136 - 2 * e - 4)) < 1e-9, true, "widths add up")
    h.eq(seg.dividers[5], nil)
  end)
end)

h.test("layout hides slots past count", function()
  withClient(function(ns)
    local seg = laid(ns, { count = 6 })
    seg:layout({ w = 136, h = 18, count = 3, skin = ns.Theme.skin("classic"), texture = "Smooth",
      rgb = ns.Theme.resourceColors.holy })
    for i = 1, 3 do h.eq(seg.slots[i].bg:IsShown(), true) end
    for i = 4, 6 do
      h.eq(seg.slots[i].bg:IsShown(), false, "slot " .. i)
      h.eq(seg.slots[i].full:IsShown(), false)
      h.eq(seg.slots[i].partial:IsShown(), false)
      h.eq(seg.slots[i].text:IsShown(), false)
    end
    h.eq(seg.dividers[1]:IsShown() and seg.dividers[2]:IsShown(), true)
    for i = 3, 5 do h.eq(seg.dividers[i]:IsShown(), false, "divider " .. i) end
  end)
end)

h.test("colors follow the approved shades", function()
  withClient(function(ns)
    local T = ns.Theme
    local holy = T.resourceColors.holy
    local seg = laid(ns, { rgb = holy })
    local s = seg.slots[1]
    local r, g, b = T.barColor(holy, "Smooth")
    h.eq(s.bg._color, { r, g, b, 0.18 })
    h.eq(s.full._barColor, { r, g, b, nil })
    local pr, pg, pb = T.barColor(T.scaleColor(holy, 0.55), "Smooth")
    h.eq(s.partial._barColor, { pr, pg, pb, nil })
  end)
end)

h.test("setPoints passes a secret through", function()
  withClient(function(ns)
    local seg = laid(ns)
    local v = fakes.secret(3)
    seg:setPoints(v)
    for i = 1, 5 do
      h.eq(rawequal(seg.slots[i].full._value, v), true, "slot " .. i)
      h.eq({ seg.slots[i].full._min, seg.slots[i].full._max }, { i - 1, i })
    end
  end)
end)

h.test("setFragments ranges per slot", function()
  withClient(function(ns)
    local seg = laid(ns)
    seg:setFragments(23, 10)
    local p = seg.slots[3].partial
    h.eq({ p._min, p._max, p._value }, { 20, 30, 23 })
    local raw = fakes.secret(9)
    seg:setFragments(raw, 10)
    h.eq(rawequal(seg.slots[1].partial._value, raw), true)
  end)
end)

h.test("setSlot fills one slot with its timer", function()
  withClient(function(ns)
    local seg = laid(ns)
    seg:setSlot(2, 0.4, 3.2)
    local s = seg.slots[2]
    h.eq(s.partial._value, 0.4)
    h.eq({ s.partial._min, s.partial._max }, { 0, 1 })
    h.eq(s.text._text, "4")
    h.eq(s.full._value, 1)
    seg:setSlot(2, 1)
    h.eq(s.full._value, 2)
    h.eq(s.text._text, "")
    h.eq(s.partial._value, 0)
    seg:setPartial(3, 0.5, 1.2)
    h.eq(seg.slots[3].full._value, nil, "full untouched")
    h.eq(seg.slots[3].text._text, "2")
    seg:clearPartials()
    for i = 1, 5 do
      h.eq(seg.slots[i].partial._value, 0)
      h.eq(seg.slots[i].text._text, "")
    end
  end)
end)
