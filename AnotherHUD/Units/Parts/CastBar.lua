local ADDON, ns = ...

-- The unit cast bar: the spell icon (a square left of the bar with a 2 px
-- panelBorder edge), the bar's panel (Parts.Panel), a StatusBar the client
-- drives with a timer, a spark on the fill end, name / time texts, a shield
-- over the icon and a grey overlay on the fill for an uninterruptible cast.
-- Cast values (name, icon, duration, notInterruptible) may be secret: they
-- only travel to widget calls; notInterruptible is read only when plain.
-- Plain frames and textures, nothing secure.
ns.Units = ns.Units or {}
ns.Units.Parts = ns.Units.Parts or {}

local CastBar = {}
CastBar.__index = CastBar

-- The events the owner registers with RegisterUnitEvent and passes on to
-- cast:update(event, ...) with their payload.
CastBar.EVENTS = {
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
  "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local SAMPLE_FILL, SAMPLE_TIME = 0.62, "0.9"
local ALL_CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

local function tint(region, c, alpha)
  region:SetVertexColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

local function font(parent, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(ns.Theme.fonts.file, ns.Theme.sizes.unit.textFont, "OUTLINE")
  fs:SetWordWrap(false)
  fs:SetJustifyH(justify)
  return fs
end

-- One decimal from the client; whole seconds as the fallback; nil when
-- neither formatter exists.
local function timeFormatter()
  local util = _G.C_StringUtil
  if type(util) ~= "table" then return nil end
  local ok, fmt = pcall(util.CreateNumericRuleFormatter)
  if ok and fmt and pcall(fmt.SetBreakpoints, fmt, { { threshold = 0, format = "%.1f" } }) then
    return fmt
  end
  ok, fmt = pcall(util.CreateSecondsFormatter)
  if ok and fmt then return fmt end
  return nil
end

-- The time text: a client binding that counts the duration down by itself.
-- UNVERIFIED (check in client): C_DurationUtil.CreateDurationTextBinding with
-- SetFontString / SetFormatter / SetZeroDurationText / SetUpdateInterval /
-- Enable / SetDuration. Missing: no binding, the time text stays empty.
local function timeBinding(fs)
  local util = _G.C_DurationUtil
  if type(util) ~= "table" then return nil end
  local ok, binding = pcall(util.CreateDurationTextBinding)
  if not ok or not binding then return nil end
  pcall(binding.SetFontString, binding, fs)
  local fmt = timeFormatter()
  if fmt then pcall(binding.SetFormatter, binding, fmt) end
  pcall(binding.SetZeroDurationText, binding, "")
  pcall(binding.SetUpdateInterval, binding, 0.05)
  pcall(binding.Enable, binding)
  return binding
end

function CastBar.create(parent, unit)
  local base = parent:GetFrameLevel() or 0
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetFrameLevel(base + 1)
  local self = setmetatable({ frame = frame, parent = parent, unit = unit, token = 0 }, CastBar)

  self.iconEdge = frame:CreateTexture(nil, "BACKGROUND")
  self.icon = frame:CreateTexture(nil, "ARTWORK")

  local host = CreateFrame("Frame", nil, frame)
  host:SetFrameLevel(base + 1)
  self.host = host
  self.panel = ns.Units.Parts.Panel.create(host)

  local bar = CreateFrame("StatusBar", nil, host)
  bar:SetFrameLevel(base + 2)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(bar)
  self.bar = bar
  -- Over the fill: the grey for an uninterruptible cast (follows the fill),
  -- and the full interrupted bar.
  self.grey = bar:CreateTexture(nil, "ARTWORK", nil, 1)
  self.grey:SetAlpha(0)
  self.full = bar:CreateTexture(nil, "ARTWORK", nil, 2)
  self.full:SetAllPoints(bar)
  self.full:Hide()

  local top = CreateFrame("Frame", nil, frame)
  top:SetAllPoints(frame)
  top:SetFrameLevel(base + 3)
  self.top = top
  self.spark = top:CreateTexture(nil, "OVERLAY")
  self.spark:SetTexture(ns.Theme.textures.spark)
  self.spark:SetBlendMode("ADD")
  self.shield = top:CreateTexture(nil, "OVERLAY")
  self.shield:SetTexture(ns.Theme.textures.shield)
  self.shield:SetAlpha(0)
  self.name = font(top, "LEFT")
  self.time = font(top, "RIGHT")
  self.binding = timeBinding(self.time)

  frame:Hide()
  return self
end

local function setTexts(self, name, time)
  self.name:SetText(name)
  if time ~= nil then self.time:SetText(time) end
end

-- Paints the fill and its background in `color` (a Theme.unitColors entry).
function CastBar:paint(color)
  local T = ns.Theme
  self.color = color
  local r, g, b = T.barColor(color, self.texture)
  self.bar:SetStatusBarColor(r, g, b)
  self.bar.bg:SetVertexColor(r, g, b, T.sizes.unit.barBgAlpha)
  local gr, gg, gb = T.barColor(T.unitColors.uninterruptible, self.texture)
  self.grey:SetVertexColor(gr, gg, gb, 1)
  local ir, ig, ib = T.barColor(T.unitColors.interrupted, self.texture)
  self.full:SetVertexColor(ir, ig, ib, 1)
end

-- opts = { width, height, icon (false: no icon), skin, texture }.
function CastBar:layout(opts)
  local T = ns.Theme
  local U = T.sizes.unit
  local w, hgt = opts.width or 200, opts.height or 18
  local skin = opts.skin or T.skins.classic
  self.texture = opts.texture or "Smooth"
  local frame = self.frame
  frame:SetSize(w, hgt)

  -- The icon: a square as high as the bar, panelBorder behind, the spell
  -- texture inset by castIconEdge; the bar's panel starts 2 px past it.
  local ox = 0
  if opts.icon ~= false then
    local e = U.castIconEdge
    self.iconEdge:SetTexture(T.textures.line)
    tint(self.iconEdge, T.colors.panelBorder)
    self.iconEdge:ClearAllPoints()
    self.iconEdge:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    self.iconEdge:SetSize(hgt, hgt)
    self.icon:ClearAllPoints()
    self.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", e, -e)
    self.icon:SetSize(hgt - 2 * e, hgt - 2 * e)
    self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.shield:ClearAllPoints()
    self.shield:SetPoint("TOPLEFT", frame, "TOPLEFT", hgt * 0.15, -hgt * 0.1)
    self.shield:SetSize(hgt * 0.7, hgt * 0.8)
    self.iconEdge:Show(); self.icon:Show(); self.shield:Show()
    ox = hgt + 2
  else
    self.iconEdge:Hide(); self.icon:Hide(); self.shield:Hide()
  end

  local host = self.host
  host:ClearAllPoints()
  host:SetPoint("TOPLEFT", frame, "TOPLEFT", ox, 0)
  host:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  self.panel:layout({ studCorners = hgt >= 24 and ALL_CORNERS or {} }, { skin = skin })

  local e = ns.UnitLayout.edgeWidth(skin.border) + 1
  local bw, bh = w - ox - 2 * e, hgt - 2 * e
  local file = (T.barTextures[self.texture] or T.barTextures.Smooth).file
  local bar = self.bar
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", host, "TOPLEFT", e, -e)
  bar:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -e, e)
  bar:SetStatusBarTexture(file)
  bar.bg:SetTexture(file)
  self.grey:SetTexture(file)
  self.full:SetTexture(file)
  -- The grey and the spark follow the fill texture's right end.
  local fill = bar:GetStatusBarTexture()
  self.grey:ClearAllPoints()
  self.grey:SetAllPoints(fill or bar)
  self.spark:ClearAllPoints()
  if fill then
    self.spark:SetPoint("CENTER", fill, "RIGHT", 0, 0)
  else
    self.spark:SetPoint("CENTER", bar, "LEFT", 0, 0)
  end
  self.spark:SetSize(4, bh + 4)

  -- Texts (units.js cast): font max(9, min(10, h - 8)), 3 px inside the bar.
  local size = math.max(9, math.min(10, hgt - 8))
  self.name:SetFont(T.fonts.file, size, "OUTLINE")
  self.time:SetFont(T.fonts.file, size, "OUTLINE")
  self.name:ClearAllPoints()
  self.name:SetPoint("LEFT", bar, "LEFT", 3, 0)
  self.name:SetWidth(math.max(1, bw * U.castNameShare - 3))
  self.time:ClearAllPoints()
  self.time:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
  self:paint(self.color or T.unitColors.cast)
end

-- Ends an interrupted hold (a callback still pending sees a newer token).
local function endHold(self)
  self.token = self.token + 1
  self.holding = false
  self.full:Hide()
  self.spark:Show()
  self.time:Show()
end

local function hide(self)
  endHold(self)
  self.frame:Hide()
end

-- The full bar in the interrupted color with "Interrupted", hidden after
-- Theme.sizes.unit.interruptHold unless a new cast comes first.
function CastBar:interrupted()
  endHold(self)
  self.holding = true
  local token = self.token
  self:paint(ns.Theme.unitColors.interrupted)
  self.full:Show()
  self.spark:Hide()
  self.time:Hide()
  self.grey:SetAlpha(0)
  self.shield:SetAlpha(0)
  setTexts(self, ns.L["Interrupted"])
  self.frame:Show()
  local timer = _G.C_Timer
  local function done()
    if self.token == token then hide(self) end
  end
  if type(timer) == "table" and timer.After then
    timer.After(ns.Theme.sizes.unit.interruptHold, done)
  else
    done()
  end
end

-- Reads the current cast (by return count; values are never tested).
-- UnitCastingInfo: name, text, texture, startMs, endMs, isTradeSkill,
-- castID, notInterruptible, spellId. UnitChannelInfo: name, text, texture,
-- startMs, endMs, isTradeSkill, notInterruptible, spellId.
local function readCast(unit)
  local n = select("#", UnitCastingInfo(unit))
  if n > 0 then
    local name, _, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    return true, false, name, texture, notInterruptible
  end
  n = select("#", UnitChannelInfo(unit))
  if n > 0 then
    local name, _, texture, _, _, _, notInterruptible = UnitChannelInfo(unit)
    return true, true, name, texture, notInterruptible
  end
  return false
end

-- The shield and the grey overlay from notInterruptible: a plain flag picks
-- the color, a secret one drives the alphas.
local function showInterruptible(self, channel, flag)
  local C = ns.Theme.unitColors
  local base = channel and C.channel or C.cast
  if ns.Util.isSecret(flag) then
    self:paint(base)
    -- UNVERIFIED (check in client): SetAlphaFromBoolean with a secret flag.
    if not pcall(self.shield.SetAlphaFromBoolean, self.shield, flag, 1, 0) then self.shield:SetAlpha(0) end
    if not pcall(self.grey.SetAlphaFromBoolean, self.grey, flag, 1, 0) then self.grey:SetAlpha(0) end
    return
  end
  self.grey:SetAlpha(0)
  if flag == true then
    self:paint(C.uninterruptible)
    self.shield:SetAlpha(1)
  else
    self:paint(base)
    self.shield:SetAlpha(0)
  end
end

-- event and its payload (unit, castGUID, spellID, interruptedBy, ...).
function CastBar:update(event, ...)
  if self.sampling then return end
  local by = select(4, ...)
  local kicked = event == "UNIT_SPELLCAST_INTERRUPTED"
    -- (a kicked channel only says so through CHANNEL_STOP's interruptedBy; a
    -- secret one is set, a plain one is compared only once known plain)
    or (event == "UNIT_SPELLCAST_CHANNEL_STOP" and self.channel and (ns.Util.isSecret(by) or by ~= nil))
  if kicked and self.frame:IsShown() and not self.holding then
    self:interrupted()
    return
  end

  local unit = self.unit
  local casting, channel, name, texture, flag = readCast(unit)
  if not casting then
    -- The STOP after a kick: the hold ends by itself.
    if not self.holding then hide(self) end
    return
  end
  endHold(self)
  self.channel = channel
  local duration
  if channel then duration = UnitChannelDuration(unit) else duration = UnitCastingDuration(unit) end
  local E = _G.Enum
  local D, I = E and E.StatusBarTimerDirection, E and E.StatusBarInterpolation
  if D and I then
    -- UNVERIFIED (check in client): StatusBar:SetTimerDuration with a secret
    -- duration object (UnitCastingDuration / UnitChannelDuration).
    pcall(self.bar.SetTimerDuration, self.bar, duration, I.Immediate,
      channel and D.RemainingTime or D.ElapsedTime)
  end
  if self.binding then pcall(self.binding.SetDuration, self.binding, duration) end
  self.icon:SetTexture(texture)
  setTexts(self, name)
  showInterruptible(self, channel, flag)
  self.frame:Show()
end

-- Edit Mode: a static 62% bar in the cast color.
function CastBar:sample(on)
  if on then
    self.sampling = true
    endHold(self)
    -- UNVERIFIED (check in client): the binding's Disable stops it writing
    -- over the sample time (Enable again after).
    if self.binding then pcall(self.binding.Disable, self.binding) end
    self.bar:SetMinMaxValues(0, 1)
    self.bar:SetValue(SAMPLE_FILL)
    self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    setTexts(self, ns.L["Sample Spell"], SAMPLE_TIME)
    self.grey:SetAlpha(0)
    self.shield:SetAlpha(0)
    self:paint(ns.Theme.unitColors.cast)
    self.frame:Show()
  else
    self.sampling = false
    self.time:SetText("")
    if self.binding then pcall(self.binding.Enable, self.binding) end
    self:update("UNIT_SPELLCAST_START", self.unit)
  end
end

ns.Units.Parts.CastBar = CastBar
