local ADDON, ns = ...

-- Pure color rules for unit frames. Client lookups (C_ClassColor,
-- PowerBarColor) happen inside the functions, never at file load. Any secret
-- input counts as unknown.
local UnitColor = {}
local Theme, Util = ns.Theme, ns.Util

local MANA = { 0, 0.44, 0.87 }

local function plain(v)
  if v == nil or Util.isSecret(v) then return nil end
  return v
end

-- info = { isPlayer, class, reaction, classColor } -> r, g, b.
function UnitColor.health(info)
  local C = Theme.unitColors
  local isPlayer = plain(info.isPlayer)
  local c
  if isPlayer == true then
    local class = plain(info.class)
    if info.classColor and type(class) == "string" then
      -- UNVERIFIED (check in client): C_ClassColor.GetClassColor(classFile)
      -- returns a ColorMixin on Forever.
      local cc = _G.C_ClassColor and _G.C_ClassColor.GetClassColor(class)
      if cc then
        local r, g, b = cc:GetRGB()
        return r, g, b
      end
    end
    c = C.healthDefault
  elseif isPlayer == false then
    local reaction = plain(info.reaction)
    if type(reaction) ~= "number" then c = C.neutral
    elseif reaction <= 3 then c = C.hostile
    elseif reaction == 4 then c = C.neutral
    else c = C.friendly end
  else
    c = C.healthDefault
  end
  return c[1], c[2], c[3]
end

-- classification -> ring color, badge color.
function UnitColor.ring(classification)
  local gold, border, rare = Theme.colors.gold, Theme.colors.panelBorder, Theme.unitColors.rare
  local c = plain(classification)
  if c == "elite" or c == "worldboss" then return gold, gold end
  if c == "rare" then return rare, rare end
  if c == "rareelite" then return rare, gold end
  return border, border
end

-- Power token ("MANA", "RAGE", ...) -> r, g, b; mana blue when unknown.
-- UNVERIFIED (check in client): PowerBarColor[token] holds { r, g, b } on
-- Forever. A secret token counts as unknown.
function UnitColor.power(token)
  token = plain(token)
  local t = _G.PowerBarColor
  local c = token ~= nil and type(t) == "table" and t[token]
  if c then return c.r or c[1], c.g or c[2], c.b or c[3] end
  return MANA[1], MANA[2], MANA[3]
end

-- "cast" | "channel" | "interrupted" | "uninterruptible" -> color table.
function UnitColor.cast(state)
  local C = Theme.unitColors
  if state == "channel" then return C.channel end
  if state == "interrupted" then return C.interrupted end
  if state == "uninterruptible" then return C.uninterruptible end
  return C.cast
end

ns.UnitColor = UnitColor
