local ADDON, ns = ...

-- Pure rules for the texts on unit frames. Health, power and level values can
-- be secret: they are never compared or computed on here, only handed back as
-- format arguments for SetFormattedText.
local UnitText = {}
local L, Util = ns.L, ns.Util

-- The stored values of the bar text option (also the dropdown texts through L).
UnitText.FORMATS = { "None", "Percent", "Value", "Value + Percent" }

-- `mode` one of FORMATS; src = { cur, max, pct, dead, offline }; abbr is the
-- number shortener (the client's AbbreviateNumbers). Returns the format
-- string and the argument list for SetFormattedText.
function UnitText.bar(mode, src, abbr)
  if mode == "Percent" or mode == "Value" or mode == "Value + Percent" then
    if src.dead or src.offline then
      local c = ns.Theme.unitColors.deadText
      local function hex(v) return string.format("%02x", math.floor(v * 255 + 0.5)) end
      local fmt = "|cff" .. hex(c[1]) .. hex(c[2]) .. hex(c[3]) .. "%s|r"
      return fmt, { src.dead and L["Dead"] or L["Offline"] }
    end
    if mode == "Percent" then return "%.0f%%", { src.pct } end
    if mode == "Value" then return "%s / %s", { abbr(src.cur), abbr(src.max) } end
    return "%s | %.0f%%", { abbr(src.cur), src.pct }
  end
  return "", {}
end

-- The level text: a secret level is formatted by the client; no level or a
-- skull level (<= 0 / -1) shows "??".
function UnitText.level(level)
  if Util.isSecret(level) then return "%d", { level } end
  if type(level) ~= "number" or level <= 0 then return "%s", { "??" } end
  return "%d", { level }
end

ns.UnitText = UnitText
