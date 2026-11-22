local ADDON, ns = ...

-- The shape the group modules (Party, Boss) share, so each is one call:
--   ns.Units.defineGroup{ id, label, name (the holder's global name; members
--     get name .. i), units (tokens in slot order), visibility (function ->
--     the holder's driver string), mirror, castBar, auras, auraMode,
--     auraSide, castGap, badge, range, role, dispel, roles (Sort by Role and
--     Show Player apply), samples (one Edit Mode sample table per slot),
--     parts, defaults, blizzard, defaultPosition,
--     orderEvents (extra events on the holder that re-order, as
--     GROUP_ROSTER_UPDATE does) }
-- spec.frame is a plain holder frame on UIParent (the frame Edit Mode
-- moves); spec.members are the member unit buttons (Units/Base.lua, member
-- = true) on the holder, one per token. Their order (existing first, then by
-- role with `roles`; index order in Edit Mode) and anchors are set out of
-- combat under "group:<id>:order"; the holder's state driver under
-- "group:<id>". Returns the spec.
ns.Units = ns.Units or {}

local function editing(spec)
  local glue = ns.EditMode and ns.EditMode.Glue
  return spec.editing == true or (glue ~= nil and glue.inEditMode()) or false
end

function ns.Units.defineGroup(o)
  local Base, GroupLayout, Combat = ns.Units.Base, ns.GroupLayout, ns.Combat
  local settings, defaults = ns.Units.Settings.build(o.parts, o.defaults)
  local id = o.id
  local holderKey, orderKey = "group:" .. id, "group:" .. id .. ":order"

  local function opt(key) return ns.Options.get(id, key) end

  local function showPlayer()
    return not o.roles or opt("showPlayer") ~= false
  end

  -- Show Player off turns the player's slot off (Base hides it, no driver).
  local function setSlots(spec)
    local show = showPlayer()
    for _, m in ipairs(spec.members) do
      m.slotOn = m.unit ~= "player" or show
    end
  end

  -- One member's block: the frame plus an attached cast bar under it.
  local function blockHeight(spec)
    local h = opt("height") or 0
    if o.castBar and opt("castBar") == true then
      local first = spec.members[1]
      local gap = o.castGap or (first and first.L and first.L.below) or 0
      h = h + gap + (opt("castHeight") or 0)
    end
    return h
  end

  -- Orders the slots, anchors the members inside the holder and sizes it.
  local function place(spec)
    Combat.after(orderKey, function()
      local holder, members = spec.frame, spec.members
      local edit = editing(spec)
      local slots = {}
      for i, m in ipairs(members) do
        local s = { index = i, unit = m.unit }
        if edit then
          s.exists = true
        else
          -- UnitExists / UnitGroupRolesAssigned may answer secrets:
          -- GroupLayout only reads them when plain.
          s.exists = UnitExists(m.unit)
          if o.roles and type(_G.UnitGroupRolesAssigned) == "function" then
            s.role = UnitGroupRolesAssigned(m.unit)
          end
        end
        slots[i] = s
      end
      local order = GroupLayout.order(slots, {
        sortByRole = o.roles and not edit and opt("sortByRole") == true,
        showPlayer = showPlayer(),
      })
      local list, w, h = GroupLayout.offsets(#order, {
        orientation = opt("orientation"), growth = opt("growth"),
        w = opt("width") or 0, h = blockHeight(spec), gap = opt("gap") or 0,
      })
      for pos, index in ipairs(order) do
        local m, p = members[index], list[pos]
        m:ClearAllPoints()
        m:SetPoint(p.point, holder, p.point, p.x, p.y)
      end
      holder:SetSize(w, h)
    end)
  end

  -- The holder: hidden while off, shown without a driver in Edit Mode, else
  -- driven by o.visibility().
  local function holderState(spec)
    local holder = spec.frame
    local on = ns.Modules.isEnabled(id)
    Combat.after(holderKey, function()
      UnregisterStateDriver(holder, "visibility")
      if not on then
        holder:Hide()
      elseif editing(spec) then
        holder:Show()
      else
        -- UNVERIFIED (check in client): the [group:raid] / [@raid1,exists]
        -- conditions in a state driver on a plain frame with secure children.
        RegisterStateDriver(holder, "visibility", o.visibility())
      end
    end)
  end

  local function apply(spec)
    if not spec.frame then return end
    local on = ns.Modules.isEnabled(id)
    setSlots(spec)
    local edit = editing(spec)
    for _, m in ipairs(spec.members) do
      -- A slot turned back on while Edit Mode is open starts its sample.
      if on and edit and m.slotOn and not m.sampling then Base.editModeFrame(m, true) end
      Base.applyFrame(m)
    end
    if on then place(spec) end
    holderState(spec)
  end

  local function onEvent(self, event)
    place(self.spec)
  end

  local function create(spec)
    local holder = CreateFrame("Frame", o.name, UIParent)
    holder.spec = spec
    spec.frame, spec.members = holder, {}
    local samples = o.samples or {}
    for i, unit in ipairs(o.units) do
      spec.members[i] = Base.create(spec, {
        member = true, parent = holder, key = id .. ":" .. i, unit = unit,
        name = o.name and (o.name .. i) or nil,
        sample = function() return samples[i] end,
        mirror = o.mirror, castBar = o.castBar, auras = o.auras, auraMode = o.auraMode,
        auraSide = o.auraSide, castGap = o.castGap, badge = o.badge,
        range = o.range, role = o.role, dispel = o.dispel, roster = true,
      })
    end
    holder:RegisterEvent("GROUP_ROSTER_UPDATE")
    if o.roles then holder:RegisterEvent("PLAYER_ROLES_ASSIGNED") end
    -- Bosses fire neither roster event: orderEvents (Boss passes
    -- INSTANCE_ENCOUNTER_ENGAGE_UNIT) queue the same re-order.
    -- UNVERIFIED (check in client): INSTANCE_ENCOUNTER_ENGAGE_UNIT fires when boss units change.
    for _, event in ipairs(o.orderEvents or {}) do holder:RegisterEvent(event) end
    holder:SetScript("OnEvent", onEvent)
    if o.range then
      -- Range has no event: Base.fade on every shown member each rangeTick s.
      local tick = ns.Theme.sizes.unit.rangeTick
      holder.elapsed = 0
      holder:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + (elapsed or 0)
        if self.elapsed < tick then return end
        self.elapsed = 0
        for _, m in ipairs(spec.members) do
          if m:IsShown() then Base.fade(m) end
        end
      end)
    end
    apply(spec)
    Base.hideBlizzard(spec.blizzard or {})
  end

  local function onEditMode(spec, active)
    if not spec.frame then return end
    spec.editing = active and true or false
    setSlots(spec)
    for _, m in ipairs(spec.members) do Base.editModeFrame(m, active) end
    if ns.Modules.isEnabled(id) then place(spec) end
    holderState(spec)
  end

  return ns.Modules.define({
    id = id, label = o.label, kind = "unit",
    defaults = defaults, settings = settings,
    blizzard = o.blizzard, defaultPosition = o.defaultPosition,
    create = create,
    apply = function(spec) apply(spec) end,
    onEditMode = onEditMode,
  })
end
