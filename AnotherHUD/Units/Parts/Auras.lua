local ADDON, ns = ...

-- The unit aura rows: two client AuraContainers (CustomAuraContainerTemplate),
-- debuffs (top rows) and buffs under them, each in its own clip frame sized
-- to its rows. Each holds two groups: mine first (bright), then other
-- players' (desaturated, off with Only Mine), so an overflow past the rows
-- cuts only others' auras. The client picks, sorts,
-- times and counts the auras; we only style its buttons. Debuff edges come
-- from AddDispelTypeTexture (Border style), buffs get a 1 px panelBorder
-- edge. The flow grows away from the portrait side. Edit Mode shows our own
-- placeholder textures instead. Without the template nothing shows and
-- nothing errors (`available` false). Plain frames, nothing secure.
ns.Units = ns.Units or {}
ns.Units.Parts = ns.Units.Parts or {}

local Auras = {}
Auras.__index = Auras

local TEMPLATE = "CustomAuraContainerTemplate"
local MAX_AURAS = 40

-- UNVERIFIED (check in client): the "!PLAYER" filter token (auras other
-- players / NPCs applied).
local G = {
  debuffMine = { key = "debuffMine", filter = "HARMFUL|PLAYER", debuff = true, mine = true },
  debuffOther = { key = "debuffOther", filter = "HARMFUL|!PLAYER", debuff = true, mine = false },
  buffMine = { key = "buffMine", filter = "HELPFUL|PLAYER", debuff = false, mine = true },
  buffOther = { key = "buffOther", filter = "HELPFUL|!PLAYER", debuff = false, mine = false },
}
local KINDS = {
  { kind = "debuff", groups = { G.debuffMine, G.debuffOther } },
  { kind = "buff", groups = { G.buffMine, G.buffOther } },
}
-- "line" mode (group frames): one container, debuffs first, then only my
-- buffs, all in the same flow.
local LINE_KINDS = {
  { kind = "line", groups = { G.debuffMine, G.debuffOther, G.buffMine } },
}

-- Edit Mode placeholders (docs/mockups/2-target.html): kind = Theme.unitColors
-- .debuff key, or "buff".
local SAMPLES = {
  { kind = "none", time = "12", mine = true },
  { kind = "Magic", time = "6", count = "3", mine = true },
  { kind = "Curse", time = "24", mine = true },
  { kind = "Poison", time = "3", mine = true },
  { kind = "buff", time = "30m", mine = true },
  { kind = "buff", time = "2m", mine = false },
}

local function tint(region, c)
  region:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

local function font(parent)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(ns.Theme.fonts.file, ns.Theme.sizes.unit.textFont, "OUTLINE")
  fs:SetWordWrap(false)
  return fs
end

local function crop(tex)
  local k = ns.Theme.sizes.unit.iconCrop
  tex:SetTexCoord(k, 1 - k, k, 1 - k)
end

local function textSize(size)
  return math.max(8, math.floor(size * ns.Theme.sizes.unit.auraTextShare + 0.5))
end

-- The edge color and width of one aura kind.
local function edgeOf(debuff, kind)
  local T = ns.Theme
  if not debuff then return T.colors.panelBorder, 1 end
  return T.unitColors.debuff[kind or "none"] or T.unitColors.debuff.none, 2
end

-- Places an icon's parts (edge behind, icon inset, time bottom center,
-- stacks top right) on `holder` at `size`.
local function placeIcon(p, holder, size, edgeWidth)
  p.edge:ClearAllPoints()
  p.edge:SetAllPoints(holder)
  p.icon:ClearAllPoints()
  p.icon:SetPoint("TOPLEFT", holder, "TOPLEFT", edgeWidth, -edgeWidth)
  p.icon:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -edgeWidth, edgeWidth)
  local fs = textSize(size)
  p.time:SetFont(ns.Theme.fonts.file, fs, "OUTLINE")
  p.count:SetFont(ns.Theme.fonts.file, fs, "OUTLINE")
  p.time:ClearAllPoints()
  p.time:SetPoint("CENTER", holder, "BOTTOM", 0, fs * 0.15)
  p.count:ClearAllPoints()
  p.count:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -1, 2)
  p.count:SetJustifyH("RIGHT")
end

-- A client button's look, built once per pooled button (initializeFrame)
-- and again on a new size. Our parts live in self.buttons (weak keys), not in
-- fields on the client's button.
local function initButton(self, button, g)
  local T = ns.Theme
  local entry = self.buttons[button]
  if not entry then
    local edge = button:CreateTexture(nil, "BACKGROUND")
    edge:SetTexture(T.textures.line)
    local icon = button:CreateTexture(nil, "ARTWORK")
    crop(icon)
    local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    cd:SetReverse(true)
    cd:SetDrawEdge(false)
    cd:SetHideCountdownNumbers(true)
    local over = CreateFrame("Frame", nil, button)
    over:SetAllPoints(button)
    over:SetFrameLevel((cd:GetFrameLevel() or 0) + 2)
    local dispel = over:CreateTexture(nil, "OVERLAY")
    dispel:SetAllPoints(button)
    entry = { g = g, parts = { edge = edge, icon = icon, cd = cd, dispel = dispel, time = font(over), count = font(over) } }
    self.buttons[button] = entry
  end
  local p = entry.parts
  local c, w = edgeOf(g.debuff)
  tint(p.edge, c)
  button:SetSize(self.size, self.size)
  placeIcon(p, button, self.size, w)
  -- UNVERIFIED (check in client): desaturating an aura group's icons (the
  -- button may reset the icon texture's desaturation).
  p.icon:SetDesaturated(not g.mine)
  -- UNVERIFIED (check in client): the CustomAuraButton setters.
  pcall(button.SetIcon, button, p.icon)
  pcall(button.SetDurationCooldown, button, p.cd)
  pcall(button.SetApplicationCount, button, p.count, {})
  pcall(button.SetDurationText, button, p.time, {})
  pcall(button.ClearDispelTypeTextures, button)
  local E = _G.Enum
  local style = E and E.CustomAuraButtonDispelTypeTextureStyle
  if g.debuff and style then
    -- UNVERIFIED (check in client): AddDispelTypeTexture (Border style)
    -- colors the edge by debuff type; the colors are the client's, ours
    -- (Theme.unitColors.debuff) are the target. Our edge under it shows
    -- debuff.none when it is missing.
    p.dispel:Show()
    pcall(button.AddDispelTypeTexture, button, p.dispel,
      { style = style.Border, showWhenHarmful = true, showWhenHelpful = false })
  else
    p.dispel:Hide()
  end
end

local function loadAuraContainer()
  local addons = _G.C_AddOns
  if type(addons) ~= "table" or not addons.LoadAddOn then return end
  local okExists, exists = pcall(addons.DoesAddOnExist, "Blizzard_AuraContainer")
  local okLoaded, loaded = pcall(addons.IsAddOnLoaded, "Blizzard_AuraContainer")
  if okExists and exists and not (okLoaded and loaded) then
    pcall(addons.LoadAddOn, "Blizzard_AuraContainer")
  end
end

-- UNVERIFIED (check in client): Blizzard_AuraContainer loads on demand and
-- CreateFrame("AuraContainer", ..., CustomAuraContainerTemplate) works at
-- login (created later the client refuses it).
-- `method` is the add function the caller needs (AddAuraGroup by default).
local function makeContainer(parent, unit, method)
  local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, TEMPLATE)
  if not ok or type(container) ~= "table" or type(container[method or "AddAuraGroup"]) ~= "function" then return nil end
  pcall(container.SetUnit, container, unit)
  return container
end

local function groupLayout(self, i)
  local gap = ns.Theme.sizes.unit.auraGap
  return {
    elementWidth = self.size, elementHeight = self.size,
    elementSpacing = gap, lineSpacing = gap, groupSpacing = gap, groupLineSpacing = gap,
    layoutIndex = i,
  }
end

-- Both kinds' clip frame and container are made here, at login. mode "rows"
-- (default): debuff and buff rows; "line": one line, debuffs then my buffs.
function Auras.create(parent, unit, mode)
  local frame = CreateFrame("Frame", nil, parent)
  local line = mode == "line"
  local self = setmetatable({ frame = frame, parent = parent, unit = unit, size = 22, line = line,
    kindList = line and LINE_KINDS or KINDS,
    buttons = setmetatable({}, { __mode = "k" }), samples = {}, kinds = {} }, Auras)
  loadAuraContainer()
  local any = false
  for _, k in ipairs(self.kindList) do
    -- UNVERIFIED (check in client): SetClipsChildren on the clip frame cuts
    -- the container's buttons past its rows.
    local clip = CreateFrame("Frame", nil, frame)
    if type(clip.SetClipsChildren) == "function" then pcall(clip.SetClipsChildren, clip, true) end
    local entry = { clip = clip, groups = {} }
    entry.container = makeContainer(clip, unit)
    if entry.container then
      for i, g in ipairs(k.groups) do
        local ok = pcall(entry.container.AddAuraGroup, entry.container, g.key, g.filter, {
          initializeFrame = function(button) initButton(self, button, g) end,
          maxFrameCount = 0,
          layout = groupLayout(self, i),
        })
        if ok then entry.groups[#entry.groups + 1] = { g = g, index = i } end
      end
      if #entry.groups == 0 then entry.container = nil end
    end
    any = any or entry.container ~= nil
    self.kinds[k.kind] = entry
  end
  self.available = any

  local sampleIcon = ns.Theme.textures.sampleIcon
  for i = 1, #SAMPLES do
    local holder = CreateFrame("Frame", nil, frame)
    local p = { holder = holder, edge = holder:CreateTexture(nil, "BACKGROUND"),
      icon = holder:CreateTexture(nil, "ARTWORK"), time = font(holder), count = font(holder) }
    p.edge:SetTexture(ns.Theme.textures.line)
    p.icon:SetTexture(sampleIcon)
    crop(p.icon)
    holder:Hide()
    for _, r in ipairs({ p.edge, p.icon, p.time, p.count }) do r:Hide() end
    self.samples[i] = p
  end
  return self
end

local function call(container, method, ...)
  local fn = container[method]
  if type(fn) == "function" then pcall(fn, container, ...) end
end

-- UNVERIFIED (check in client): the container's flow layout setters and
-- AnchorUtil.FlowLayoutAxis / FlowDirection.
local function flow(container, anchor, mirror, width)
  local A = _G.AnchorUtil
  if type(A) ~= "table" then return end
  if A.FlowLayoutAxis then call(container, "SetFlowLayoutAxis", A.FlowLayoutAxis.Horizontal) end
  call(container, "SetFlowLayoutAnchorPoint", anchor)
  if A.FlowDirection then
    call(container, "SetFlowLayoutGrowthDirection",
      mirror and A.FlowDirection.Left or A.FlowDirection.Right, A.FlowDirection.Down)
  end
  call(container, "SetFlowLayoutMaximumLineSize", width)
  call(container, "SetFlowLayoutPadding", 0, 0, 0, 0)
end

local function kindOn(o, debuff)
  if debuff then return o.debuffs end
  return o.buffs
end

local function wanted(o, g)
  return kindOn(o, g.debuff) and (g.mine or not o.onlyMine) and true or false
end

-- The top of a kind's rows (px below the aura frame's top): buffs sit under
-- the debuffs' rows plus the gap; a kind that is off takes no space.
local function kindTop(self, o, debuff)
  if self.line or debuff or not o.debuffs then return 0 end
  return o.rows * (o.size + ns.Theme.sizes.unit.auraGap)
end

-- Our placeholders, on the same rows as the containers.
local function drawSamples(self)
  local o, gap = self.opts, ns.Theme.sizes.unit.auraGap
  local size, anchor = self.size, o.mirror and "TOPRIGHT" or "TOPLEFT"
  local nDebuff, nBuff = 0, 0
  for i, s in ipairs(SAMPLES) do
    local p = self.samples[i]
    local debuff = s.kind ~= "buff"
    local index
    if self.line then
      -- One line: debuffs first, no other players' buffs.
      if (debuff or s.mine) and wanted(o, { debuff = debuff, mine = s.mine }) then
        nDebuff = nDebuff + 1; index = nDebuff
      else index = math.huge end
    elseif debuff then nDebuff = nDebuff + 1; index = nDebuff
    else nBuff = nBuff + 1; index = nBuff end
    local show = self.sampling and wanted(o, { debuff = debuff, mine = s.mine }) and index <= self.shown
    if show then
      local col, row = (index - 1) % self.perRow, math.floor((index - 1) / self.perRow)
      local x = col * (size + gap)
      if o.mirror then x = -x end
      p.holder:ClearAllPoints()
      p.holder:SetPoint(anchor, self.frame, anchor, x, -(kindTop(self, o, debuff) + row * (size + gap)))
      p.holder:SetSize(size, size)
      local c, w = edgeOf(debuff, s.kind)
      tint(p.edge, c)
      placeIcon(p, p.holder, size, w)
      p.icon:SetDesaturated(not s.mine)
      p.time:SetText(s.time)
      p.count:SetText(s.count or "")
      p.holder:Show()
      for _, r in ipairs({ p.edge, p.icon, p.time, p.count }) do r:Show() end
    else
      p.holder:Hide()
      for _, r in ipairs({ p.edge, p.icon, p.time, p.count }) do r:Hide() end
    end
  end
end

-- opts = { size, rows (per kind), width, buffs, debuffs, onlyMine, mirror
-- (portrait on the right: start at the right edge, grow left) }.
function Auras:layout(opts)
  local U = ns.Theme.sizes.unit
  local o = {
    size = opts.size or 22, rows = opts.rows or 1, width = opts.width or 200,
    buffs = opts.buffs ~= false, debuffs = opts.debuffs ~= false,
    onlyMine = opts.onlyMine and true or false, mirror = opts.mirror and true or false,
  }
  self.opts, self.size = o, o.size
  self.perRow, self.shown = ns.UnitLayout.auras(o.width, o.size, U.auraGap, o.rows, MAX_AURAS)
  -- A kind's clip frame: its rows, the gap between them, nothing more.
  local clipH = o.rows * o.size + (o.rows - 1) * U.auraGap
  local kinds = (o.debuffs and 1 or 0) + (o.buffs and 1 or 0)
  if self.line then kinds = math.min(1, kinds) end
  self.frame:SetSize(o.width, math.max(1, kinds * clipH + math.max(0, kinds - 1) * U.auraGap))

  local anchor = o.mirror and "TOPRIGHT" or "TOPLEFT"
  for _, k in ipairs(self.kindList) do
    local entry, debuff = self.kinds[k.kind], k.kind == "debuff"
    local clip, c = entry.clip, entry.container
    clip:ClearAllPoints()
    clip:SetPoint(anchor, self.frame, anchor, 0, -kindTop(self, o, debuff))
    clip:SetSize(o.width, clipH)
    if (self.line and (o.debuffs or o.buffs)) or kindOn(o, debuff) then clip:Show() else clip:Hide() end
    if c then
      c:ClearAllPoints()
      c:SetPoint(anchor, clip, anchor, 0, 0)
      c:SetSize(o.width, clipH)
      for _, gi in ipairs(entry.groups) do
        call(c, "SetAuraGroupLayout", gi.g.key, groupLayout(self, gi.index))
        call(c, "SetAuraGroupMaxFrameCount", gi.g.key, self.shown)
        call(c, "SetAuraGroupEnabled", gi.g.key, wanted(o, gi.g))
      end
      flow(c, anchor, o.mirror, o.width)
    end
  end
  -- Buttons built at an earlier size.
  for button, entry in pairs(self.buttons) do initButton(self, button, entry.g) end
  drawSamples(self)
end

-- Edit Mode: our placeholders over hidden containers (they show even
-- without the template).
function Auras:sample(on)
  self.sampling = on and true or false
  if not self.opts then self:layout({}) end
  for _, entry in pairs(self.kinds) do
    local c = entry.container
    if c then
      if on then c:Hide() else c:Show() end
    end
  end
  drawSamples(self)
end

-- Shared with Dispel (its own container).
Auras.loadAuraContainer = loadAuraContainer
Auras.makeContainer = makeContainer

ns.Units.Parts.Auras = Auras
