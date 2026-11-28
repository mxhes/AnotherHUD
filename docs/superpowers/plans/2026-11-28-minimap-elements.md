# Minimap Plan 2 (Ring and Elements) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Round shape its skin ring and add the approved elements around the map (zone name above; clock, calendar badge and coordinates below), each with its own setting.

**Architecture:** Pure rules in `Core/MinimapRules.lua` (clock text, coordinate text, zone color). A small round badge part `Map/Badge.lua` (the level badge look: skin line discs, panel fill, gold icon), reused by Plans 3 and 4. The minimap module (`Map/Minimap.lua`) draws the round ring with the existing `Units/Parts/Ring`, adds the texts and the calendar badge on its frame (outside the map, which stays the Edit Mode frame), and updates them from events plus one throttled `OnUpdate`.

**Tech Stack:** Lua 5.1, plain-Lua tests (`lua tests/run.lua`), luacheck, `tools/render_units.py` for the one new glyph.

**Spec:** `docs/superpowers/specs/2026-11-28-minimap-design.md`; look `docs/mockups/7-minimap.html` (approved, APPROVED.md section 7); spike results in `docs/CHECKLIST.md` "Minimap spike (gate)" (passed 2026-11-28).

## Global Constraints

- Lua 5.1; `lua tests/run.lua` passes and `luacheck AnotherHUD` has 0 warnings after each task.
- Look values in `Core/Theme.lua`; texts through `ns.L` with German in `Locales/deDE.lua`; labels <= 24 characters with a tooltip.
- Mockup placement (map `size`, default 180; frame = the map only): zone name centered above, 12 pt, its bottom 4 px above the frame; clock 11 pt, white, its top 4 px below the frame, centered 14 px left of the middle; calendar badge 18 px, centered 20 px right of the middle and 11 px below the frame; coordinates 10 pt, grey `{ 0.85, 0.85, 0.85 }`, top 22 px below the frame, centered. Texts and badges keep their size when the map size changes.
- Round: the map masked round inside the skin ring (`Units/Parts/Ring`, ring diameter = `size`, no badge, no portrait); Square: the skin panel (as now). Map inset = `UnitLayout.edgeWidth(skin.border)` for both.
- Element settings (section "Elements"): `showZone` true, `showClock` true, `showCalendar` true, `showCoords` false.
- Client values: zone text and coordinates only shown when plain (`Util.plainString`, `Util.isSecret` / `Util.isNumber`); nothing secret is formatted.
- Nothing here is secure: texts and our badge may change in combat. Clicks that open Blizzard panels run out of combat only.
- Every unconfirmed API: `UNVERIFIED (check in client)` plus a CHECKLIST line.
- Plans 3 (mail, queue, tracking badges) and 4 (addon container) are out of scope; their settings are not added here.

## Review Focus

1. 12 h clock at midnight and noon: 0 h is "12:00 AM", 12 h is "12:00 PM" (not "0:00").
2. Coordinates where the client has no position (instances, some zones): the line is empty, no error, every tick.
3. Zone text secret or nil: empty text, no error; a PvP type the table doesn't know gets the normal gold.
4. Clock and coordinates both off: the `OnUpdate` is removed (no per-frame work for nothing); back on, it returns.
5. Map size changed: the ring, texts and badge follow the frame edges; texts and badge keep their size.

---

### Task 1: Rules and look values

**Files:**
- Modify: `AnotherHUD/Core/MinimapRules.lua`, `AnotherHUD/Core/Theme.lua`, `docs/DEVELOPMENT.md` (rules row)
- Test: `tests/test_minimap_rules.lua`

**Interfaces:**
- Produces in `ns.MinimapRules`:
  - `clockText(hour, minute, military) -> string`: "14:05" when `military`, else "2:05 PM"; "" when hour or minute is not a plain number.
  - `coordText(x, y) -> string`: x, y in 0..1 -> "42.1, 65.8" (one decimal, times 100); "" when either is nil, secret or not a number, or both are 0 (the client's "no position").
  - `zoneColor(pvpType) -> { r, g, b }`: a copy from `Theme.minimapZoneColors[pvpType]`, else `.normal`.
- Produces in Theme: `Theme.minimapZoneColors = { sanctuary = { 0.41, 0.80, 0.94 }, friendly = { 0.10, 1.00, 0.10 }, hostile = { 1.00, 0.10, 0.10 }, arena = { 1.00, 0.10, 0.10 }, combat = { 1.00, 0.10, 0.10 }, contested = { 1.00, 0.70, 0.00 }, normal = { 1.00, 0.82, 0.00 } }` (the game's zone text colors); `Theme.sizes.minimap` grows to `{ size = 180, zoneFont = 12, clockFont = 11, coordFont = 10, textGap = 4, clockShift = 14, calendarBadge = 18, calendarShift = 20, calendarDrop = 11, coordDrop = 22, badgeIcon = 0.6, glow = 8, clockTick = 1, coordTick = 0.2 }` and `Theme.colors.coords = { 0.85, 0.85, 0.85, 1 }`.

- [ ] **Step 1: Write the failing tests** "clock text, 24 h and 12 h": `clockText(14, 5, true) == "14:05"`, `clockText(14, 5, false) == "2:05 PM"`, `clockText(0, 0, false) == "12:00 AM"`, `clockText(12, 0, false) == "12:00 PM"`, `clockText(0, 7, true) == "0:07"`, `clockText(nil, 5, true) == ""`; "coordinate text": `coordText(0.421, 0.658) == "42.1, 65.8"`, `coordText(0, 0) == ""`, `coordText(nil, 0.5) == ""`, with `fakes.secret(0.4)` as x `== ""` (inside `withGlobals({ issecretvalue = fakes.isSecret })`); "zone colors are copies with a fallback": `zoneColor("friendly")` equals `{ 0.10, 1.00, 0.10 }`, `zoneColor("nonsense")` and `zoneColor(nil)` equal `.normal`, changing the returned table leaves `zoneColor("friendly")` unchanged. The rules file now also needs `Core/Theme.lua` in the test's load list.
- [ ] **Step 2:** `lua tests/run.lua`: the new tests fail.
- [ ] **Step 3:** Implement the three functions and the Theme values (plain Lua). 12 h: hour 0 -> 12 AM, 1-11 AM, 12 PM, 13-23 -> 1-11 PM; minutes always two digits, hours without a leading zero. AM / PM go through `ns.L`.
- [ ] **Step 4:** Tests and luacheck: all pass, 0 warnings. German: "AM" / "PM" stay as they are (no entry).
- [ ] **Step 5: Commit** `feat: minimap clock, coordinate and zone color rules`.

### Task 2: The round ring

**Files:**
- Modify: `AnotherHUD/Map/Minimap.lua`
- Test: `tests/test_minimap.lua`

**Interfaces:**
- Consumes: `ns.Units.Parts.Ring.create(parent)`, `ring:layout(L, { skin })` with `L = { ring = { cx, cy, dia } }` (no `badge` hides the badge), `ring.frame`.
- Produces: `spec.ring` (a Ring) shown for Round, hidden for Square; `spec.ring.frame` at our frame's own level (below the map, like the panel).

- [ ] **Step 1: Write the failing tests** "round shows the skin ring, square the panel": default Square -> `spec.panel.frame:IsShown() == true`, `spec.ring.frame:IsShown() == false`; set Round -> panel hidden, ring shown, the ring's outermost line disc centered on `(90, 90)` of the frame with diameter 180 (read the last `SetPoint` / `_width` of `spec.ring.lines[1]`); set size 240 -> diameter 240 at `(120, 120)`. "the ring sits below the map": `spec.ring.frame` frame level equals the frame's (record `SetFrameLevel` on the fake).
- [ ] **Step 2:** Tests fail.
- [ ] **Step 3:** In `create` build `spec.ring = Ring.create(frame)`, hide its portrait texture, set `spec.ring.frame:SetFrameLevel(frame:GetFrameLevel() or 0)`; in `apply` lay it out with `{ ring = { cx = size / 2, cy = size / 2, dia = size } }` and show / hide it by shape. Update the module's header comment (the ring no longer "comes later").
- [ ] **Step 4:** Tests and luacheck pass.
- [ ] **Step 5: Commit** `feat: round minimap in the skin ring`.

### Task 3: The badge part and the calendar glyph

**Files:**
- Create: `AnotherHUD/Map/Badge.lua`, `AnotherHUD/Media/Units/Calendar.tga` (generated)
- Modify: `tools/render_units.py` (a `calendar` glyph), `AnotherHUD/Core/Theme.lua` (`textures.calendar`), `AnotherHUD/AnotherHUD.toc` (`Map/Badge.lua` before `Map/Minimap.lua`), `docs/DEVELOPMENT.md` (layout rows, art list)
- Test: `tests/test_minimap_badge.lua`

**Interfaces:**
- Consumes: `Ring.shadesOf(border)`, `Ring.disc(frame, layer, sub)`, `Ring.place(tex, frame, x, y, dia)`, `Theme.colors.panelTint / panelBorder / gold`, `Theme.textures.glow`, `Theme.scaleColor`.
- Produces `ns.Map.Badge`:
  - `Badge.create(parent) -> badge` with `badge.button` (a `Button` child of `parent`), `badge.icon` (texture), `badge.glow` (texture, hidden).
  - `badge:layout(size, skin)`: the button `size x size`; line discs per `Ring.shadesOf(skin.border)` from `size` down 2 px each, the panel-fill disc inside them, the icon centered at `size * Theme.sizes.minimap.badgeIcon`, tinted `colors.gold`; the glow `size + 2 * glow` centered, tinted gold.
  - `badge:setIcon(file)`, `badge:setGlow(on)`.

- [ ] **Step 1: Write the failing tests** "a badge has the ring lines, the fill and a gold icon": `Badge.create(parent)` then `layout(18, Theme.skins.classic)`; button size 18 x 18; the number of shown line discs `n` equals `#Ring.shadesOf(Theme.skins.classic.border)`; the fill disc diameter `18 - 2 * n`; icon size `18 * 0.6` with color `colors.gold`; "the glow follows setGlow": hidden by default, `setGlow(true)` shows it at `18 + 16`, `setGlow(false)` hides it.
- [ ] **Step 2:** Tests fail.
- [ ] **Step 3:** Implement `Map/Badge.lua` (plain frames, nothing secure; the disc stack as in `Ring`'s level badge). Add a `calendar()` glyph to `tools/render_units.py` (32 x 32, white, the mockup's ▤: a rounded page outline 2 px, a filled top band, two rows of three small squares) and run `python tools/render_units.py`; `Theme.textures.calendar = "Interface\\AddOns\\AnotherHUD\\Media\\Units\\Calendar"`.
- [ ] **Step 4:** Tests and luacheck pass; `tests/test_toc.lua` sees the new file.
- [ ] **Step 5: Commit** `feat: minimap badge part and calendar glyph`.

### Task 4: Zone name, clock, calendar and coordinates

**Files:**
- Modify: `AnotherHUD/Map/Minimap.lua`, `AnotherHUD/Locales/deDE.lua`, `.luacheckrc`, `README.md`, `CHANGELOG.md`, `docs/DEVELOPMENT.md`, `docs/CHECKLIST.md`, `CLAUDE.md` (status)
- Test: `tests/test_minimap.lua`

**Interfaces:**
- Consumes: Task 1's `clockText`, `coordText`, `zoneColor`; Task 3's `Badge`; Theme sizes from Task 1.
- Produces: `spec.zone`, `spec.clock`, `spec.coords` (font strings on a child frame of our frame above the map), `spec.calendar` (a Badge); options `showZone`, `showClock`, `showCalendar`, `showCoords`.

- [ ] **Step 1: Write the failing tests** (fakes: `GetMinimapZoneText` -> r.zone, `GetZonePVPInfo` -> r.pvp, `GetGameTime` -> r.hour, r.minute, `GetCVarBool(name)` -> r.cvars[name], `date("*t")` stays Lua's own, `C_Map.GetBestMapForUnit` -> r.mapID, `C_Map.GetPlayerMapPosition` -> nil or `{ GetXY = function() return r.x, r.y end }`, `C_Calendar.GetNumPendingInvites` -> r.invites, `ToggleCalendar` / `ToggleWorldMap` / `TimeManager_Toggle` / `C_AddOns.LoadAddOn` recording calls):
  - "the zone name shows above the map in its PvP color": text "Elwynn Forest", color `zoneColor("friendly")`, anchored `BOTTOM` to the frame's `TOP` at `(0, 4)`; `ZONE_CHANGED_NEW_AREA` with a new zone updates it; a secret zone text gives "".
  - "the clock follows Blizzard's clock settings": realm time 14:05, military on -> "14:05"; military off -> "2:05 PM"; local time on -> the text of `date("*t")`'s hour / min; the clock ticks only after `clockTick` seconds of `OnUpdate` elapsed.
  - "coordinates are off by default and empty without a position": hidden at default; on -> "42.1, 65.8" from x 0.421, y 0.658; no map id -> ""; no position -> "".
  - "the calendar badge glows with pending invites": `r.invites = 2`, fire `CALENDAR_UPDATE_PENDING_INVITES` -> glow shown; 0 -> hidden; a click calls `ToggleCalendar` out of combat, nothing in combat.
  - "clicks open Blizzard's panels out of combat": zone click -> `ToggleWorldMap`; clock click -> `C_AddOns.LoadAddOn("Blizzard_TimeManager")` then `TimeManager_Toggle`; in combat nothing.
  - "each element turns off on its own": each `show*` off hides its element; with clock and coordinates off the frame's `OnUpdate` is nil; one of them on again sets it.
  - "texts and badge follow the frame at any size": size 240 -> the same anchors (they hang on the frame edges) and the same font sizes.
- [ ] **Step 2:** Tests fail.
- [ ] **Step 3:** Implement in `Map/Minimap.lua`:
  - an `elements` frame (child of our frame, level above the map: `frame:GetFrameLevel() + 10`) holding the font strings (`SetFont` before any `SetText`) and the calendar badge; anchors and fonts from `Theme.sizes.minimap` as in Global Constraints; zone and clock and calendar mouse-enabled (the zone and clock via small invisible buttons sized to their text, or the font strings' parent buttons).
  - zone: `GetMinimapZoneText()` through `Util.plainString`; color from `zoneColor(pvpType)` with `pvpType` from `C_PvP.GetZonePVPInfo` if present, else `GetZonePVPInfo`; events `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_ENTERING_WORLD`.
  - clock: `GetCVarBool("timeMgrUseLocalTime")` -> `date("*t")` hour / min, else `GetGameTime()`; `GetCVarBool("timeMgrUseMilitaryTime")` -> 24 h.
  - coordinates: `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(id, "player")`, `pos:GetXY()`, through `coordText`.
  - calendar: Badge with `Theme.textures.calendar`; glow from `C_Calendar.GetNumPendingInvites() > 0` only when plain; event `CALENDAR_UPDATE_PENDING_INVITES` (and `PLAYER_ENTERING_WORLD`).
  - one `OnUpdate` (elapsed accumulators for `clockTick` / `coordTick`), set only while clock or coordinates are on and the module is on; removed otherwise.
  - clicks only when `not InCombatLockdown()`.
  - UNVERIFIED comments: `GetMinimapZoneText`, `C_PvP.GetZonePVPInfo` / `GetZonePVPInfo` types, the two CVars, `GetGameTime`, `C_Map` position, `C_Calendar.GetNumPendingInvites`, `CALENDAR_UPDATE_PENDING_INVITES`, `ToggleCalendar`, `ToggleWorldMap`, `TimeManager_Toggle` after loading `Blizzard_TimeManager`, all without taint.
  - settings section "Elements" between Look and Behaviour: `showZone` "Zone name" / "Show the zone name above the map.", `showClock` "Clock" / "Show the clock below the map.", `showCalendar` "Calendar" / "Show the calendar button below the map.", `showCoords` "Coordinates" / "Show your coordinates below the map.".
  - German: "Elements" "Elemente", "Zone name" "Zonenname", "Show the zone name above the map." "Zeigt den Zonennamen über der Karte.", "Clock" "Uhr", "Show the clock below the map." "Zeigt die Uhr unter der Karte.", "Calendar" "Kalender", "Show the calendar button below the map." "Zeigt den Kalenderknopf unter der Karte.", "Coordinates" "Koordinaten", "Show your coordinates below the map." "Zeigt deine Koordinaten unter der Karte.".
  - `.luacheckrc` read_globals: the new client names.
- [ ] **Step 4:** Docs: README Minimap paragraph (zone name, clock following Blizzard's clock settings, calendar with the invite glow, coordinates off by default, each one a setting; mail, tracking and the group finder eye come next), CHANGELOG one bullet, DEVELOPMENT (module row and Minimap section: ring, elements, `OnUpdate`), CHECKLIST a "Minimap Plan 2" section: the APIs above and in-game checks (zone name and color in a sanctuary / contested / hostile zone; clock matches Blizzard's clock in both settings; calendar opens, glows with an invite; coordinates match a map addon's or the world map's and are empty in an instance; round ring looks like the mockup in all three skins; clicks do nothing in combat, no taint). CLAUDE.md status line.
- [ ] **Step 5:** Tests and luacheck pass.
- [ ] **Step 6: Commit** `feat: minimap zone name, clock, calendar and coordinates`.

### Task 5: The player's client check

- [ ] The player runs the CHECKLIST "Minimap Plan 2" section; results go there. Then Plan 3 (mail, queue, tracking badges).
