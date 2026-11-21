local h = ...

local function load()
  local ns = h.load({ "Core/Util.lua", "Core/DB.lua", "Core/Modules.lua", "Core/Combat.lua", "Core/Options.lua" })
  ns.db, ns.chardb = ns.DB.init(nil, nil)
  return ns
end

local function define(ns, extra)
  local s = {
    id = "m", label = "M", kind = "unit",
    defaults = { width = 200, mode = "a", on = true },
    settings = { { section = "Size", controls = {
      { key = "width", type = "slider", label = "Width", min = 80, max = 400, step = 1 },
      { key = "mode", type = "dropdown", label = "Mode", values = { "a", "b" } },
    } } },
  }
  for k, v in pairs(extra or {}) do s[k] = v end
  ns.Modules.define(s)
  return s
end

h.test("get falls back to default", function()
  local ns = load()
  define(ns)
  h.eq(ns.Options.get("m", "width"), 200)
  ns.DB.profile().modules.m = { width = 150 }
  h.eq(ns.Options.get("m", "width"), 150)
  h.eq(ns.Options.get("m", "on"), true)
  h.eq(ns.Options.get("nope", "x"), nil)
end)

h.test("set clamps slider", function()
  local ns = load()
  define(ns)
  ns.Options.set("m", "width", 500)
  h.eq(ns.Options.get("m", "width"), 400)
  ns.Options.set("m", "width", 99.6)
  h.eq(ns.Options.get("m", "width"), 100)
  ns.Options.set("m", "width", 10)
  h.eq(ns.Options.get("m", "width"), 80)
end)

h.test("set rejects unknown dropdown value", function()
  local ns = load()
  define(ns)
  h.eq(ns.Options.set("m", "mode", "zzz"), false)
  h.eq(ns.Options.get("m", "mode"), "a")
  h.eq(ns.Options.set("m", "mode", "b"), true)
  h.eq(ns.Options.get("m", "mode"), "b")
end)

h.test("set calls apply", function()
  local ns = load()
  local calls = {}
  define(ns, { apply = function(spec, key, value) calls[#calls + 1] = { spec.id, key, value } end })
  ns.Options.set("m", "width", 300)
  h.eq(calls, { { "m", "width", 300 } })
  ns.Options.set("m", "mode", "zzz") -- rejected: no apply
  h.eq(#calls, 1)
end)

-- UTF-8 glyphs, not bytes.
h.test("glyphs counts utf-8 characters", function()
  local ns = load()
  h.eq(ns.Options.glyphs("abc"), 3)
  h.eq(ns.Options.glyphs("Größe ändern"), 12)
end)

local function germanNs(strings)
  local saved = _G.GetLocale
  _G.GetLocale = function() return "deDE" end
  local ns = h.load({ "Core/Util.lua", "Core/DB.lua", "Core/Modules.lua", "Core/Combat.lua", "Core/Options.lua" })
  _G.GetLocale = saved
  ns.Locale.register("deDE", strings, "deDE")
  return ns
end

-- Every module registered by the .toc files, in en and de.
h.test("labels fit 24 glyphs in en and de", function()
  local files = h.toc()
  local en = h.load(files)
  h.eq(en.Options.longLabels(en.Modules.list(), en.L, 24), {})
  _G.GetLocale = function() return "deDE" end
  local ok, de = pcall(h.load, files)
  _G.GetLocale = nil
  assert(ok, de)
  h.eq(de.Options.longLabels(de.Modules.list(), de.L, 24), {})
end)

h.test("longLabels flags a label that is too long and passes one that fits", function()
  local long = "Transparenz der Gruppenleiste"
  local ns = germanNs({ ["Opacity"] = long, ["Width"] = "Breite" })
  local specs = { {
    id = "f", label = "F", kind = "misc",
    settings = { { section = "S", controls = {
      { key = "o", type = "slider", label = "Opacity" },
      { key = "w", type = "slider", label = "Width" },
    } } },
  } }
  h.eq(ns.Options.longLabels(specs, ns.L, 24), { long })
  h.eq(ns.Options.longLabels(specs, setmetatable({}, { __index = function(_, k) return k end }), 24), {})
end)
