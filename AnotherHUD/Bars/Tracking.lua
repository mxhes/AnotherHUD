local ADDON, ns = ...

-- The XP / Reputation bar: a plain frame (AnotherHUDTrackingBar, child of
-- UIParent, the Edit Mode frame) holding the skin's panel and up to three
-- bars in the unit frame look: XP on top (with the rested band under its
-- fill), reputation, then honor (Show honor, off by default), a 1 px divider
-- in the skin's Lines pick between neighbours. Out of combat a left click
-- on the reputation / honor bar opens the reputation / PvP pane.
-- A bar shows while it has something to show (Core/Tracking.lua); with
-- none the frame hides, Edit Mode shows a sample of both. Texts show on
-- mouse-over by default. Client numbers only travel into SetMinMaxValues /
-- SetValue; texts and the rested band come from the rules, which read them
-- only when plain. Nothing secure: size, show and alpha may change in combat.
-- Blizzard's status tracking bars are hidden.
local Tracking = ns.Tracking
local Util = ns.Util

local ID = "tracking"

local function opt(key)
  return ns.Options.get(ID, key)
end

local function editing(spec)
  local glue = ns.EditMode and ns.EditMode.Glue
  return spec.sampling or (glue ~= nil and glue.inEditMode()) or false
end

local function call(name, ...)
  local f = _G[name]
  if type(f) == "function" then return f(...) end
  return nil
end

local function flag(v)
  return not Util.isSecret(v) and v == true
end

-- The XP rules' input from the client; nil without the XP API.
-- UNVERIFIED (check in client): UnitXP / UnitXPMax("player") answer the
-- level's XP and its maximum, GetXPExhaustion() the rested XP (nil when not
-- rested), IsPlayerAtEffectiveMaxLevel() true at max level (also for a
-- trial / expansion cap) and IsXPUserDisabled() true when XP gain is off.
local function readXP()
  if type(_G.UnitXP) ~= "function" or type(_G.UnitXPMax) ~= "function" then return nil end
  return Tracking.xp({
    xp = UnitXP("player"), max = UnitXPMax("player"), rested = call("GetXPExhaustion"),
    level = UnitLevel("player"), atMax = flag(call("IsPlayerAtEffectiveMaxLevel")),
    disabled = flag(call("IsXPUserDisabled")),
  })
end

-- The watched faction, or nil.
-- UNVERIFIED (check in client): C_Reputation.GetWatchedFactionData() answers
-- { name, reaction, currentReactionThreshold, nextReactionThreshold,
-- currentStanding } (nil or no name when none is watched); without it the
-- older GetWatchedFactionInfo() answers name, reaction, min, max, value.
local function readReputation()
  local C = _G.C_Reputation
  if type(C) == "table" and type(C.GetWatchedFactionData) == "function" then
    return Tracking.reputation(C.GetWatchedFactionData())
  end
  if type(_G.GetWatchedFactionInfo) ~= "function" then return nil end
  local name, reaction, min, max, value = GetWatchedFactionInfo()
  return Tracking.reputation({ legacy = { name = name, reaction = reaction, min = min, max = max, value = value } })
end

-- The honor row from the client; nil without the honor API.
-- UNVERIFIED (check in client): UnitHonor / UnitHonorMax("player") answer
-- the honor toward the next honor level and its maximum, UnitHonorLevel the
-- honor level.
local function readHonor()
  if type(_G.UnitHonor) ~= "function" or type(_G.UnitHonorMax) ~= "function" then return nil end
  return Tracking.honor({ value = UnitHonor("player"), max = UnitHonorMax("player"),
    level = call("UnitHonorLevel", "player") })
end

-- The Edit Mode sample: XP 60% with rested to 80%, reputation halfway
-- through Friendly, honor level 12 at 31%.
local function sampleData()
  return {
    xp = { value = 600, max = 1000, restedEnd = 800, text = Tracking.xpText(42, 600, 1000, 200) },
    rep = Tracking.reputation({ legacy = { name = ns.L["Sample Faction"], reaction = 5, min = 3000, max = 9000,
      value = 6000 } }),
    honor = Tracking.honor({ value = 1240, max = 4000, level = 12 }),
  }
end

-- What the bars show now: { xp, rep, honor } (each nil when that bar is off).
local function current(spec)
  if editing(spec) then
    -- A sample row whose option is off is left out; with all three off XP and
    -- reputation stay, so the frame remains selectable.
    local d = sampleData()
    local xp, rep = opt("showXP") == true, opt("showReputation") == true
    if xp or rep or opt("showHonor") == true then
      if not xp then d.xp = nil end
      if not rep then d.rep = nil end
    end
    if opt("showHonor") ~= true then d.honor = nil end
    return d
  end
  local d = {}
  if opt("showXP") == true then d.xp = readXP() end
  if opt("showReputation") == true then d.rep = readReputation() end
  if opt("showHonor") == true then d.honor = readHonor() end
  return d
end

local KEYS = { "xp", "rep", "honor" }

-- The rows in order (XP on top) and a key telling the layouts apart.
local function rowsOf(d)
  local rows = {}
  if d.xp then rows[#rows + 1] = "xp" end
  if d.rep then rows[#rows + 1] = "rep" end
  if d.honor then rows[#rows + 1] = "honor" end
  return rows, table.concat(rows, ",")
end

local function hideRow(row)
  row.bg:Hide()
  row.bar:Hide()
  if row.rested then row.rested:Hide() end
  row.text:Hide()
end

local function textShown(spec)
  local mode = opt("text")
  if mode == "Always" then return true end
  if mode == "Hover" then return spec.hover == true or editing(spec) end
  return false
end

local function refreshText(spec)
  local on = textShown(spec)
  for _, key in ipairs(KEYS) do
    local row = spec[key]
    if on and spec.shownRows[key] then row.text:Show() else row.text:Hide() end
  end
end

-- SetAlpha is not protected: also in combat.
local function fade(spec)
  spec.frame:SetAlpha(ns.UnitState.alpha({
    editMode = editing(spec),
    inCombat = spec.combat or InCombatLockdown(),
    hover = spec.hover,
    outOfCombat = opt("outOfCombat"),
    mouseover = opt("mouseover"),
  }))
end

-- The values into the bars (the rows already laid out).
local function setValues(spec, d)
  local T = ns.Theme
  local texture = opt("barTexture")
  local x = d.xp
  if x then
    local row = spec.xp
    row.bar:SetMinMaxValues(0, x.max)
    row.bar:SetValue(x.value)
    if x.restedEnd then
      row.rested:SetMinMaxValues(0, x.max)
      row.rested:SetValue(x.restedEnd)
      row.rested:Show()
    else
      row.rested:Hide()
    end
    row.text:SetText(x.text or "")
  end
  local r = d.rep
  if r then
    local row = spec.rep
    row.bar:SetMinMaxValues(r.min, r.max)
    row.bar:SetValue(r.value)
    local cr, cg, cb = T.barColor(Tracking.reactionColor(r.reaction), texture)
    row.bar:SetStatusBarColor(cr, cg, cb)
    row.bg:SetVertexColor(cr, cg, cb, T.sizes.unit.barBgAlpha)
    row.text:SetText(r.text or "")
  end
  local o = d.honor
  if o then
    local row = spec.honor
    row.bar:SetMinMaxValues(0, o.max)
    row.bar:SetValue(o.value)
    row.text:SetText(o.text or "")
  end
end

-- Reads every option: sizes the frame to the rows shown, lays out the panel,
-- the bars, the divider and the texts, then the values, texts, alpha and
-- the frame's show. Off: the frame hides, nothing else.
local function apply(spec)
  local frame = spec.frame
  if not frame then return end
  if not ns.Modules.isEnabled(ID) then
    frame:Hide()
    return
  end
  local T = ns.Theme
  local S = T.sizes.tracking
  local d = current(spec)
  local rows, key = rowsOf(d)
  spec.layoutKey = key
  local n = math.max(#rows, 1)
  local skin = ns.Units.Base.skinOf(frame)
  local e = ns.UnitLayout.edgeWidth(skin.border)
  local w, hgt, gap = opt("width"), opt("height"), S.gap
  frame:SetSize(w, n * hgt + (n - 1) * gap + 2 * e)
  spec.panel:layout({ skin = skin })

  local texture = opt("barTexture")
  local file = (T.barTextures[texture] or T.barTextures.Smooth).file
  local iw = w - 2 * e
  local xr, xg, xb = T.barColor(T.trackingColors.xp, texture)
  local rr, rg, rb = T.barColor(T.trackingColors.rested, texture)
  local hr, hg, hb = T.barColor(T.trackingColors.honor, texture)
  spec.shownRows = {}
  -- the shown rows and the edge, for the click's row hit test
  spec.rowKeys, spec.rowEdge = rows, e
  for _, k in ipairs(KEYS) do hideRow(spec[k]) end
  for i, k in ipairs(rows) do
    local row = spec[k]
    local y = -(e + (i - 1) * (hgt + gap))
    local items = { row.bg, row.bar }
    if row.rested then items[#items + 1] = row.rested end
    for _, item in ipairs(items) do
      item:ClearAllPoints()
      item:SetPoint("TOPLEFT", frame, "TOPLEFT", e, y)
      item:SetSize(iw, hgt)
    end
    row.bg:SetTexture(file)
    row.bar:SetStatusBarTexture(file)
    row.bg:Show()
    row.bar:Show()
    if row.rested then
      row.rested:SetStatusBarTexture(file)
      row.rested:SetStatusBarColor(rr, rg, rb, S.restedAlpha)
      row.bar:SetStatusBarColor(xr, xg, xb)
      row.bg:SetVertexColor(xr, xg, xb, T.sizes.unit.barBgAlpha)
    end
    if k == "honor" then
      row.bar:SetStatusBarColor(hr, hg, hb)
      row.bg:SetVertexColor(hr, hg, hb, T.sizes.unit.barBgAlpha)
    end
    row.text:ClearAllPoints()
    row.text:SetPoint("CENTER", row.bg, "CENTER", 0, 0)
    -- the row's inner width: a long name is cut by the client, not run over
    row.text:SetWidth(iw)
    row.text:SetFont(T.fonts.file, opt("fontSize"), "OUTLINE")
    row.text:SetWordWrap(false)
    spec.shownRows[k] = true
  end

  -- one divider under every row but the last
  local dividers = { { spec.divider, spec.groove }, { spec.divider2, spec.groove2 } }
  for j, pair in ipairs(dividers) do
    local div, groove = pair[1], pair[2]
    if j < #rows then
      -- painted like the segment dividers (shared painter)
      local second = ns.Bars.Segments.paintDivider(div, groove, skin.lines)
      local y = -(e + j * hgt + (j - 1) * gap)
      div:ClearAllPoints()
      div:SetPoint("TOPLEFT", frame, "TOPLEFT", e, y)
      div:SetSize(iw, gap)
      div:Show()
      if second then
        groove:ClearAllPoints()
        groove:SetPoint("TOPLEFT", frame, "TOPLEFT", e, y - gap)
        groove:SetSize(iw, 1)
        groove:Show()
      else
        groove:Hide()
      end
    else
      div:Hide()
      groove:Hide()
    end
  end

  setValues(spec, d)
  refreshText(spec)
  fade(spec)
  if #rows > 0 then frame:Show() else frame:Hide() end
end

-- New client values: the same rows get their values; a row coming or going
-- lays the frame out again.
local function update(spec)
  if not spec.frame or not ns.Modules.isEnabled(ID) or editing(spec) then return end
  local d = current(spec)
  local _, key = rowsOf(d)
  if key ~= spec.layoutKey then
    apply(spec)
    return
  end
  setValues(spec, d)
end

local function row(spec, withRested)
  local r = {}
  r.bg = spec.content:CreateTexture(nil, "BACKGROUND")
  if withRested then
    r.rested = CreateFrame("StatusBar", nil, spec.frame)
    r.rested:SetFrameLevel(spec.levels.rested)
  end
  r.bar = CreateFrame("StatusBar", nil, spec.frame)
  r.bar:SetFrameLevel(spec.levels.bar)
  r.text = spec.top:CreateFontString(nil, "OVERLAY")
  -- A font before any SetText: the client errors on a font string without one.
  r.text:SetFont(ns.Theme.fonts.file, ns.Theme.sizes.tracking.textFont, "OUTLINE")
  r.text:SetText("")
  hideRow(r)
  return r
end

-- The pane a row opens (XP: none).
-- UNVERIFIED (check in client): ToggleCharacter("ReputationFrame") opens the
-- character window on the reputation tab and TogglePVPUI() the PvP window,
-- both from addon code out of combat without taint.
local PANES = {
  rep = function() call("ToggleCharacter", "ReputationFrame") end,
  honor = function() call("TogglePVPUI") end,
}

-- A left click out of combat and outside Edit Mode opens the clicked row's
-- pane. The row comes from the cursor's height in the frame.
-- UNVERIFIED (check in client): GetCursorPosition() answers screen pixels;
-- divided by the frame's effective scale they match GetTop().
local function onClick(spec, button)
  if button ~= "LeftButton" or editing(spec) or InCombatLockdown() then return end
  local rows, frame = spec.rowKeys or {}, spec.frame
  -- a press on the bar released beside it opens nothing
  if not frame:IsMouseOver() then return end
  local _, y = GetCursorPosition()
  local top, scale = frame:GetTop(), frame:GetEffectiveScale()
  if not y or not top or not scale or scale == 0 then return end
  local i = Tracking.rowAt(top - y / scale, opt("height"), ns.Theme.sizes.tracking.gap, spec.rowEdge or 0, #rows)
  local open = i and PANES[rows[i]]
  if open then open() end
end

local function onEvent(spec, event)
  if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    spec.combat = event == "PLAYER_REGEN_DISABLED"
    fade(spec)
    return
  end
  update(spec)
end

-- UNVERIFIED (check in client): these fire on Forever for XP, rested XP,
-- level, XP gain on / off and the watched faction (UPDATE_FACTION also
-- when another faction is watched).
-- UNVERIFIED (check in client): HONOR_XP_UPDATE and HONOR_LEVEL_UPDATE fire
-- when the honor or the honor level changes.
local EVENTS = { "PLAYER_ENTERING_WORLD", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "ENABLE_XP_GAIN",
  "DISABLE_XP_GAIN", "UPDATE_FACTION", "HONOR_XP_UPDATE", "HONOR_LEVEL_UPDATE",
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local function slider(key, label, tooltip, min, max, step)
  return { key = key, type = "slider", label = label, tooltip = tooltip, min = min, max = max, step = step }
end

local function checkbox(key, label, tooltip)
  return { key = key, type = "checkbox", label = label, tooltip = tooltip }
end

local function dropdown(key, label, tooltip, values)
  return { key = key, type = "dropdown", label = label, tooltip = tooltip, values = values }
end

local S = ns.Theme.sizes.tracking

ns.Modules.define({
  id = ID, label = "XP / Reputation", kind = "bar",
  defaults = {
    width = S.width, height = S.height, text = "Hover", fontSize = S.textFont,
    skin = "Classic", barTexture = "Smooth", showXP = true, showReputation = true, showHonor = false,
    outOfCombat = 100, mouseover = true,
  },
  settings = {
    { section = "Size", controls = {
      slider("width", "Width", "Width of the bars.", 100, 1600, 1),
      slider("height", "Bar height", "Height of each bar.", 4, 30, 1),
    } },
    { section = "Text", controls = {
      dropdown("text", "Show text", "When the bars show their numbers.", { "Hover", "Always", "Never" }),
      slider("fontSize", "Text size", "Size of the bar texts.", 8, 16, 1),
    } },
    { section = "Look", controls = {
      dropdown("skin", "Skin", "Border and decoration style of the bars.", { "Classic", "Forge", "Slate" }),
      dropdown("barTexture", "Bar texture", "Look of the bar fill.", { "Smooth", "Flat", "Gloss" }),
    } },
    { section = "Behaviour", controls = {
      checkbox("showXP", "Show XP", "Show the experience bar while you can gain XP."),
      checkbox("showReputation", "Show reputation", "Show the reputation of the faction you watch."),
      checkbox("showHonor", "Show honor", "Show your honor and honor level."),
    } },
    { section = "Fading", controls = {
      slider("outOfCombat", "Out of combat opacity", "Opacity of the bars out of combat, in percent.", 0, 100, 5),
      checkbox("mouseover", "Show on mouseover", "Show the bars fully while the mouse is over them."),
    } },
  },
  -- Only the manager: its two bar containers (MainStatusTrackingBarContainer,
  -- SecondaryStatusTrackingBarContainer) stay its children and hide with it.
  -- Blizzard's containers call self:GetParent():CheckForLayoutChange() when
  -- Edit Mode closes; re-parented to our hidden frame that call failed
  -- (seen in the client, 2026-11-28).
  blizzard = { "StatusTrackingBarManager" },
  defaultPosition = { point = "BOTTOM", x = 0, y = 2 },
  create = function(spec)
    local frame = CreateFrame("Frame", "AnotherHUDTrackingBar", UIParent)
    frame.id = ID -- for Units.Base.skinOf
    frame:Hide()
    spec.frame = frame
    local base = frame:GetFrameLevel() or 0
    spec.levels = { panel = base + 1, content = base + 2, rested = base + 3, bar = base + 4, top = base + 5 }
    spec.panel = ns.Units.Parts.Panel.create(frame)
    spec.panel.frame:SetFrameLevel(spec.levels.panel)
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    content:SetFrameLevel(spec.levels.content)
    spec.content = content
    local top = CreateFrame("Frame", nil, frame)
    top:SetAllPoints(frame)
    top:SetFrameLevel(spec.levels.top)
    spec.top = top
    spec.xp = row(spec, true)
    spec.rep = row(spec, false)
    spec.honor = row(spec, false)
    spec.divider = top:CreateTexture(nil, "OVERLAY")
    spec.groove = top:CreateTexture(nil, "OVERLAY")
    spec.divider2 = top:CreateTexture(nil, "OVERLAY")
    spec.groove2 = top:CreateTexture(nil, "OVERLAY")
    for _, t in ipairs({ spec.divider, spec.groove, spec.divider2, spec.groove2 }) do t:Hide() end
    spec.sampling, spec.hover, spec.combat, spec.shownRows = false, false, false, {}
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function()
      spec.hover = true
      refreshText(spec)
      fade(spec)
    end)
    frame:SetScript("OnMouseUp", function(_, button) onClick(spec, button) end)
    frame:SetScript("OnLeave", function()
      spec.hover = false
      refreshText(spec)
      fade(spec)
    end)
    -- UNVERIFIED (check in client): PLAYER_XP_UPDATE carries the unit and
    -- RegisterUnitEvent("player") gets the player's.
    frame:RegisterUnitEvent("PLAYER_XP_UPDATE", "player")
    for _, ev in ipairs(EVENTS) do frame:RegisterEvent(ev) end
    frame:SetScript("OnEvent", function(_, event) onEvent(spec, event) end)
    apply(spec)
    ns.Units.Base.hideBlizzard(spec.blizzard)
  end,
  apply = function(spec) apply(spec) end,
  -- Edit Mode open: both sample rows and the frame shown; closed: the real
  -- values and show come back.
  onEditMode = function(spec, active)
    if not spec.frame then return end
    spec.sampling = active and true or false
    apply(spec)
  end,
})
