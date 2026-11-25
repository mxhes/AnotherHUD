# Unit Frames (Plan 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Our own Player (with cast bar and Detach), Target, Target of Target, Focus and Pet frames in the approved look, placed and set up in Edit Mode; Blizzard's frames hidden.

**Architecture:** The rules (texts, colors, geometry, fading, visibility) are pure Lua in `Core/` and tested with secret fakes. `Units/Parts/` build the drawn pieces (panel, ring, bars, cast bar, auras) on plain frames; `Units/Base.lua` puts them on a `SecureUnitButtonTemplate` button, wires the events and the Edit Mode sample; each unit is one `ns.Modules.define{...}` file. Values from the client go to widgets untouched (`SetValue`, `SetFormattedText`, `SetTimerDuration`, `SetAlphaFromBoolean`).

**Tech Stack:** Lua 5.1, WoW Forever client API (Interface 16001), LibEditMode (packager external), plain-Lua test harness (`lua tests/run.lua`), luacheck in CI.

**Spec:** `docs/superpowers/specs/2026-11-21-anotherhud-design.md` (Goals: unit frames and section contents; Design: Unit frames, Edit Mode integration) and the approved art in `docs/mockups/APPROVED.md` sections 1 and 2 (pages `1-player.html`, `2-target.html`, drawing rules in `units.js` / `kit.js`).

## Global Constraints

- Lua 5.1 code (CI runs 5.1 and 5.4): no `goto`, `//`, `table.unpack` (use `unpack or table.unpack` only in tests), integer-only APIs.
- Secret values: no arithmetic, comparison, `tostring`, `..` or boolean test on health, power, cast, aura or duration values from the client. They only travel to widget calls. A value that may be secret and must be read (reaction, classification, level, dead / connected flags, `notInterruptible`) is read only after `ns.Util.isSecret(v)` is false; else the documented fallback.
- Combat lockdown: everything that creates, shows / hides, anchors, sizes or sets attributes / state drivers on a secure frame goes through `ns.Combat.after(key, fn)`.
- Taint: Blizzard frames are only hidden (unregister events, reparent to our hidden frame, `hooksecurefunc(frame, "Show", ...)` that re-hides out of combat); no writes into Blizzard tables.
- Files in `Core/` are pure: client calls only inside functions, never at file load; tested with `h.load`.
- Look values (colors, sizes, textures, fonts) live in `Core/Theme.lua`.
- Options: a default in the module's `defaults`, label at most 24 glyphs (English and German), a `tooltip`; read with `ns.Options.get`.
- Texts go through `ns.L`; every new English key gets a German text in `Locales/deDE.lua`.
- Every unconfirmed client API: `-- UNVERIFIED (check in client)` comment plus a line in `docs/CHECKLIST.md`.
- New `.lua` file: `.toc` line and a row in the layout table of `docs/DEVELOPMENT.md`.
- Other addons are read only to learn which APIs work; no code or art is copied from them. AnotherLedger code may be copied.
- Approved art values, verbatim (APPROVED.md 1 and 2):
  - Player 200 x 60, power 15, 1 px divider; bars inset by the skin's border width + 1 px.
  - Ring diameter = 125% of frame height x Portrait Scale; ring center x = 32% of the diameter (mirrored for Target); bars start 2 px past the ring.
  - Level badge 18 px (Focus 14 px), center at ring center + (0.33, 0.36) x diameter (x mirrored), gold 10 pt number; ToT and Pet have none.
  - Cast bar 200 x 18; icon 18 x 18 left with a 2 px border-colored edge; name left, time right, spark at the fill end. Colors: cast (1, 0.74, 0.12), channel (0.35, 0.75, 0.35), interrupted (0.85, 0.2, 0.15) full bar with "Interrupted", uninterruptible (0.6, 0.6, 0.62) with a shield over the icon.
  - Bar textures Smooth (default; top 125%, 45% the color, bottom 72%), Flat, Gloss; bar background = bar color at 18% alpha.
  - Health: class color (option, default on); off = green (0.16, 0.62, 0.22); NPCs in reaction colors hostile (0.85, 0.2, 0.15), neutral (0.95, 0.82, 0.2), friendly (0.25, 0.75, 0.25).
  - Ring tint: normal `panelBorder`; elite / worldboss `gold`; rare silver (0.78, 0.78, 0.81); rare elite silver ring with a `gold` ring on the badge.
  - Auras 22 px, 2 px gap; debuff 2 px edge in type color magic (0.2, 0.6, 1), curse (0.6, 0, 1), poison (0, 0.6, 0), disease (0.6, 0.4, 0), none (0.8, 0, 0); buffs 1 px `panelBorder` edge; other players' auras desaturated; time bottom center, stacks top right, text about 42% of the icon size.
  - Focus 160 x 40, power 8, 10 pt; ToT 120 x 26, no power bar, name only 10 pt; Pet 120 x 34, power 6, 10 pt. Power text only on power bars of 9 px and up (font min(10, power height - 3)).
  - Gilded: four 9 px ring studs at 45 / 135 / 225 / 315 deg only on rings of 40 px and up; frame corner studs only on the corners the ring doesn't cover.

## Review Focus

1. **A unit that disappears or changes mid-update** (target dies, is released, `targettarget` swaps every few frames, pet dismissed): no Lua error, the frame hides via its state driver, texts never show the previous unit's name. Test in Task 9 (`"unit gone: update hides texts and does not throw"`).
2. **`/reload` in combat**: frames must still exist and Blizzard's stay hidden after combat ends; nothing secure touched while locked. Test in Task 9 (`"created in combat: secure work waits for PLAYER_REGEN_ENABLED"`).
3. **Secret values on every path**, including Edit Mode leave (sample off → live values) and the cast bar's interrupted flash: tests in Tasks 2, 7 and 9 run with `fakes.secret` everywhere a client value comes in.
4. **Edit Mode entered with no target / focus / pet**: all five frames visible with samples, draggable; leaving restores the state drivers. Test in Task 9 (`"edit mode shows samples and restores visibility"`).
5. **Settings changed in combat** (Width, Detach, Cast Bar off): applied once when combat ends, no error. Test in Task 10 (`"detach in combat applies after combat"`).

---

### Task 1: Test groundwork

**Files:**
- Modify: `tests/fakes.lua`, `tests/test_fakes.lua`, `tests/test_glue.lua`, `tests/test_checklist.lua`, `.pkgmeta`

**Interfaces:**
- Produces:
  - `fakes.withGlobals(tbl, fn)`: sets every `_G[k] = v` from `tbl` (use `fakes.NIL` to clear a global), runs `fn()`, restores all of them even when `fn` throws, then rethrows.
  - `fakes.units(map)`: installs client unit API globals reading from `map[unit] = { exists, name, class, level, classification, reaction, isPlayer, dead, connected, health, healthMax, healthPct, power, powerMax, powerPct, powerToken, casting = { name, texture, notInterruptible, duration }, channel = {...} }`; returns a handle with `set(unit, field, value)`, `calls[globalName]` (how often each was called) and `restore()`. Globals: `UnitExists, UnitName, UnitClass, UnitLevel, UnitEffectiveLevel, UnitClassification, UnitReaction, UnitIsPlayer, UnitIsDeadOrGhost, UnitIsConnected, UnitHealth, UnitHealthMax, UnitHealthPercent, UnitPower, UnitPowerMax, UnitPowerPercent, UnitPowerType, UnitCastingInfo, UnitChannelInfo, UnitCastingDuration, UnitChannelDuration, SetPortraitTexture, RegisterStateDriver, UnregisterStateDriver, AbbreviateNumbers, CurveConstants, C_ClassColor, PowerBarColor, Enum.StatusBarInterpolation, Enum.StatusBarTimerDirection, GameTooltip`.
  - Fake frames gain: `SetFormattedText(fmt, ...)` storing `_fmt` and `_args` (and `_text = nil`), `SetAttribute(k, v)` / `GetAttribute(k)` in `_attrs`, `SetAlpha` / `GetAlpha` in `_alpha` (default 1), `SetAlphaFromBoolean(b, yes, no)` storing `_alphaFrom = { b, yes, no }`, `SetTimerDuration(d, interp, dir)` storing `_timer`, `HookScript(ev, fn)` chaining into `_scripts`, `RegisterUnitEvent(ev, ...)` like `RegisterEvent`, `SetSize` / `SetWidth` / `SetHeight` updating `_width` / `_height`. `fakes.client` records `RegisterStateDriver` calls in `handle.drivers[frame] = { attr, cond }`.

- [ ] **Step 1: Write the failing tests** in `tests/test_fakes.lua`:
  - `"secret values throw on < and <="`: `pcall(function() return fakes.secret(1) < 2 end)` is false; same for `<=` and `2 < secret`.
  - `"withGlobals restores after an error"`: `_G.FOO = 1`; `pcall(fakes.withGlobals, { FOO = 2, BAR = 3 }, function() error("x") end)`; then `FOO == 1`, `BAR == nil`.
  - `"units answers secrets untouched"`: `fakes.units{ target = { exists = true, health = fakes.secret(5) } }`; `fakes.isSecret(UnitHealth("target"))` is true; `UnitExists("focus")` is false.
  - `"SetFormattedText keeps format and args"`: fake frame, `SetFormattedText("%s | %.0f%%", a, b)` with two secrets; `_fmt` and `_args` are those values (`rawequal`).
- [ ] **Step 2:** Run `lua tests/run.lua`. Expected: FAIL (`withGlobals`, `units`, `SetFormattedText` missing; the `<` test may already pass, keep it).
- [ ] **Step 3:** Implement the fakes above. Replace the hand-written save / restore blocks in `tests/test_glue.lua` and `tests/test_checklist.lua` with `fakes.withGlobals` (no behavior change).
- [ ] **Step 4:** Pin LibEditMode in `.pkgmeta`: the external gets `tag: <latest tag>` (look it up with `git ls-remote --tags https://github.com/p3lim-wow/LibEditMode`; the local copy is MINOR 19, pick the tag that carries it).
- [ ] **Step 5:** Run `lua tests/run.lua`. Expected: PASS.
- [ ] **Step 6: Commit** `refactor: test fakes for units, restoring globals; pin LibEditMode`.

### Task 2: Pure unit rules (texts, colors, fading, visibility)

**Files:**
- Create: `AnotherHUD/Core/UnitText.lua`, `AnotherHUD/Core/UnitColor.lua`, `AnotherHUD/Core/UnitState.lua`
- Modify: `AnotherHUD/Core/Theme.lua` (`Theme.unitColors`), `AnotherHUD/AnotherHUD.toc` (after `Core/Options.lua`), `docs/DEVELOPMENT.md` (layout table)
- Test: `tests/test_unit_rules.lua`

**Interfaces:**
- Produces:
  - `Theme.unitColors = { healthDefault, hostile, neutral, friendly, rare, cast, channel, interrupted, uninterruptible, debuff = { Magic, Curse, Poison, Disease, none } }` with the Global Constraints values; `elite` uses `Theme.colors.gold`, normal uses `Theme.colors.panelBorder`.
  - `UnitText.FORMATS = { "None", "Percent", "Value", "Value + Percent" }` (stored values; also the dropdown texts through `L`).
  - `UnitText.bar(mode, src, abbr) -> fmt, args` where `src = { cur, max, pct, dead, offline }` (cur / max / pct may be secret; dead / offline plain booleans) and `abbr` is the number shortener (the client's `AbbreviateNumbers`). Results: `"None"` → `"", {}`; `"Percent"` → `"%.0f%%", { pct }`; `"Value"` → `"%s / %s", { abbr(cur), abbr(max) }`; `"Value + Percent"` → `"%s | %.0f%%", { abbr(cur), pct }`; `dead` → `"%s", { L["Dead"] }`, `offline` → `"%s", { L["Offline"] }` (dead / offline win over the mode, except `"None"`).
  - `UnitText.level(level) -> fmt, args`: secret → `"%d", { level }`; plain `level <= 0` or nil → `"%s", { "??" }`; else `"%d", { level }`.
  - `UnitColor.health(info) -> r, g, b` with `info = { isPlayer, class, reaction, classColor }`: player + classColor on + class color known (`C_ClassColor.GetClassColor(class)`, looked up at call time) → that color; NPC with plain reaction: `<= 3` hostile, `4` neutral, `>= 5` friendly; secret / nil reaction → neutral; otherwise `healthDefault`. Any secret field is treated as unknown.
  - `UnitColor.ring(classification) -> ringColor, badgeColor`: `"elite"` / `"worldboss"` → gold, gold; `"rare"` → rare, rare; `"rareelite"` → rare, gold; else / secret → panelBorder, panelBorder.
  - `UnitColor.power(token) -> r, g, b`: `PowerBarColor[token]` when the client has it (call time), else mana blue (0, 0.44, 0.87).
  - `UnitColor.cast(state) -> color` for `"cast" | "channel" | "interrupted" | "uninterruptible"`.
  - `UnitState.alpha{ editMode, inCombat, hover, outOfCombat, mouseover } -> number`: 1 in Edit Mode, in combat, or when `mouseover` and `hover`; else `outOfCombat / 100`.
  - `UnitState.visibility(unit, showInVehicle) -> string` (state driver condition): `"player"` → `"[petbattle] hide; show"`, with `showInVehicle == false` → `"[petbattle] hide; [vehicleui] hide; show"`; other units → `"[petbattle] hide; [@<unit>,exists] show; hide"`, with `showInVehicle == false` a `[vehicleui] hide; ` after `[petbattle] hide; `.

- [ ] **Step 1: Write the failing tests** in `tests/test_unit_rules.lua` (load `Core/Util.lua`, `Core/Locale.lua`, `Locales/deDE.lua`, `Core/Theme.lua`, the three new files):
  - `"bar text passes secrets through"`: `cur, max, pct = fakes.secret(1), fakes.secret(2), fakes.secret(3)`, `abbr` returns `{ wrapped = v }`; for each format check `fmt` and that the args are the very values (`rawequal(args[1].wrapped, cur)` etc.).
  - `"bar text: dead and offline win, None stays empty"`.
  - `"level: secret, skull, number"`: `UnitText.level(fakes.secret(1))` → `"%d"`; `-1` → `"%s", {"??"}`; `80` → `"%d", {80}`.
  - `"health color: class, reaction, secret, default"`: with a fake `C_ClassColor.GetClassColor("PALADIN")` returning `{ r = 0.96, g = 0.55, b = 0.73 }`-style object (`GetRGB`); reactions 2 / 4 / 5 give the three colors; `fakes.secret(2)` gives neutral; classColor off gives `healthDefault`.
  - `"ring color by classification"`: the four cases plus a secret.
  - `"alpha rules"`: `{ outOfCombat = 40 }` → 0.4; in combat → 1; hover with mouseover → 1; hover without → 0.4; editMode → 1.
  - `"visibility conditions"`: the four strings exactly.
- [ ] **Step 2:** Run `lua tests/run.lua`. Expected: FAIL (modules missing).
- [ ] **Step 3:** Implement the three files and `Theme.unitColors`; add `Dead`, `Offline` to `Locales/deDE.lua` (`Tot`, `Offline`).
- [ ] **Step 4:** Run `lua tests/run.lua`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: unit text, color, fading and visibility rules`.

### Task 3: Pure geometry from the approved mockups

**Files:**
- Create: `AnotherHUD/Core/UnitLayout.lua`
- Modify: `.toc` (after `Core/UnitState.lua`), `docs/DEVELOPMENT.md`
- Test: `tests/test_unit_layout.lua`

**Interfaces:**
- Produces `UnitLayout.frame(o) -> L` with `o = { w, h, powerH, portraitScale (percent), mirror, edge, badge (px or nil), fontSize }` and, in frame pixels from the TOPLEFT (y grows down), the rules of `docs/mockups/units.js` (layout `'overhang'`):
  - `L.ring = { dia = round(h * 1.25 * ps), cx, cy = h / 2 }`, `cx = round(dia * 0.32)`, mirrored `w - cx`.
  - `L.bars = { left = cx + dia / 2 + 2, right = w - edge - 1 }` (mirrored: `left = edge + 1`, `right = w - cx - dia / 2 - 2`).
  - `L.health = { top = edge + 1, bottom }`, `L.power = { top, bottom = h - edge - 1 }` or nil when `powerH == 0`; `power.top = power.bottom - powerH`; `health.bottom = power.top - 1` (the divider row is `power.top - 1`), else `health.bottom = h - edge - 1`.
  - `L.badge = { size, cx = ring.cx ± 0.33 * dia, cy = ring.cy + 0.36 * dia }` or nil.
  - `L.powerText = powerH >= 9 and { size = min(10, powerH - 3) } or nil`.
  - `L.studCorners`: `{ "TOPRIGHT", "BOTTOMRIGHT" }` (mirrored: the left two) — the corners the ring doesn't cover.
  - `L.ringStuds = dia >= 40`.
  - `L.below = max(8, h / 2 + dia / 2 - h + 6)` rounded: the gap from the frame bottom to whatever hangs under it (cast bar, auras).
- `UnitLayout.auras(width, size, gap, rows, count) -> perRow, shown` (`perRow = floor((width + gap) / (size + gap))`, at least 1; `shown = min(count, perRow * rows)`).
- `edge` per skin border: `UnitLayout.edgeWidth(border)` = `#Theme.edgeRects(border)`, and 4 for `"round"` (the mockup's soft edge).

- [ ] **Step 1: Write the failing tests** (values from the mockup at 200 x 60, power 15):
  - `"player 200x60 classic"`: `edge = 4`; `ring.dia == 75`, `ring.cx == 24`, `ring.cy == 30`; `bars.left == 63.5`, `bars.right == 195`; `health.top == 5`, `power.bottom == 55`, `power.top == 40`, `health.bottom == 39`; `badge.cx == 24 + 0.33 * 75`; `below == 14`.
  - `"target mirrored"`: `ring.cx == 176`, `bars.left == 5`, `bars.right == 136.5`, `studCorners` are the left two.
  - `"tot has no power and no ring studs"`: 120 x 26, powerH 0 → `power == nil`, `health.bottom == 21`, `ringStuds == false` (dia 33).
  - `"portrait scale 150"`: `ring.dia == 113`.
  - `"aura rows"`: `UnitLayout.auras(200, 22, 2, 2, 40)` → `8, 16`; `UnitLayout.auras(10, 22, 2, 1, 3)` → `1, 1`.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement `Core/UnitLayout.lua` (pure, `math.floor(x + 0.5)` for `round`).
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: unit frame geometry from the approved mockups`.

### Task 4: Shared settings sections

**Files:**
- Create: `AnotherHUD/Units/Settings.lua`
- Modify: `.toc` (new `Units/` block after the `EditMode/` files), `Locales/deDE.lua`, `docs/DEVELOPMENT.md`
- Test: `tests/test_unit_settings.lua`

**Interfaces:**
- Produces `ns.Units.Settings.build(parts, defaults) -> settings, defaults`: `parts` is a list of section names in panel order, picked from `"Size", "Text", "Look", "Behaviour", "Cast Bar", "Auras", "Fading"`, plus the option fields `portrait`, `power`, `detach` (booleans, default false) on the same table; `defaults` overrides the shared defaults per unit. Returns the module's `settings` list and the merged `defaults` table. Keys, controls and shared defaults:
  - **Size**: `width` slider 80-400 step 1; `height` 20-120; `portraitScale` 50-150 step 5 (default 100) when `portrait`; `powerHeight` 2-40 (default 15) when `power`.
  - **Text**: `showName` checkbox (true); `healthText` dropdown `UnitText.FORMATS` ("Value"); `powerText` dropdown (when `power`, "Percent"); `fontSize` slider 8-20 (11).
  - **Look**: `skin` dropdown `{ "Classic", "Forge", "Slate", "Gilded" }` ("Classic"); `classColor` checkbox (true); `barTexture` dropdown `{ "Smooth", "Flat", "Gloss" }` ("Smooth").
  - **Behaviour**: `showInVehicle` checkbox (true).
  - **Cast Bar**: `castBar` checkbox (true); `castWidth` 80-400 (200); `castHeight` 10-40 (18); `castIcon` checkbox (true); `castDetach` checkbox (false) when `detach`.
  - **Auras**: `buffs` (true), `debuffs` (true) checkboxes; `auraSize` 14-40 (22); `auraRows` 1-4 (1); `onlyMine` checkbox (false).
  - **Fading**: `outOfCombat` slider 0-100 step 5 (100); `mouseover` checkbox (true).
  - Every control has an English `label` (at most 24 glyphs) and `tooltip`; dropdown values and section names are English keys translated where drawn.

- [ ] **Step 1: Write the failing tests:**
  - `"sections in the order asked"`: `build({ "Size", "Fading" }, {})` gives two sections named `Size`, `Fading`.
  - `"portrait and power controls only when asked"`: `build({ "Size" , portrait = false, power = false }, {})` has no `portraitScale` / `powerHeight` key.
  - `"unit defaults override shared ones"`: `build({ "Size" , power = true }, { width = 160, powerHeight = 8 })` → defaults `width == 160`, `powerHeight == 8`, `height == 60`.
  - `"every control has a default, label and tooltip"`: all parts on; each control key is in `defaults`, `label` and `tooltip` are strings.
  - `"German labels fit 24 glyphs"`: load with `GetLocale = "deDE"`; every section name, label and dropdown value is translated (`L[x] ~= x`) and `Options.glyphs(L[x]) <= 24`.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement `Units/Settings.lua` (pure data, `ns.Units = ns.Units or {}`); German texts for every label, tooltip, section and value.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: shared unit frame settings sections`.

### Task 5: Edit Mode glue for unit frames (child modules, enter / exit)

**Files:**
- Modify: `AnotherHUD/Core/Modules.lua`, `AnotherHUD/EditMode/Glue.lua`, `AnotherHUD/EditMode/Checklist.lua`, `docs/DEVELOPMENT.md` (module contract)
- Test: `tests/test_modules.lua`, `tests/test_glue.lua`, `tests/test_checklist.lua`

**Interfaces:**
- Produces, in the module contract:
  - `spec.parent = "<id>"`: a child module (the detached Player cast bar's holder). `Modules.isEnabled(child)` is false when the parent is off; the checklist leaves children out; `Modules.setEnabled` on a child is not offered.
  - `spec.onEditMode(spec, active)`: called by Glue for every registered module when LibEditMode fires `"enter"` (true) and `"exit"` (false), and once with `lem:IsInEditMode()` right after a module registers while Edit Mode is open.
  - `Glue.inEditMode() -> bool` for modules (false without the library).

- [ ] **Step 1: Write the failing tests:**
  - `test_modules.lua` `"a child follows its parent"`: define `a` and `b` with `parent = "a"`; `setEnabled("a", false)` → `isEnabled("b") == false`.
  - `test_checklist.lua` `"children are not listed"`.
  - `test_glue.lua` `"enter and exit reach onEditMode"`: fake lem records `RegisterCallback`; fire `"enter"` → spec got `true`; `"exit"` → `false`; `Glue.inEditMode()` follows.
  - `test_glue.lua` `"a module registered during Edit Mode is told at once"`: lem `IsInEditMode` returns true, register → `onEditMode(spec, true)`.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement; Glue keeps the state from the callbacks (`editing`); `onEditMode` errors go through `geterrorhandler` like `Combat`'s `report` (one bad module must not stop the others).
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: child modules and Edit Mode enter / exit for modules`.

### Task 6: Unit art and Theme entries

**Files:**
- Create: `tools/render_units.py`, `AnotherHUD/Media/Units/Disc.tga`, `BarSmooth.tga`, `BarGloss.tga`, `Spark.tga`, `Shield.tga`
- Modify: `AnotherHUD/Core/Theme.lua` (`Theme.textures`, `Theme.barTextures`, `Theme.sizes`), `docs/DEVELOPMENT.md` (Media + tools)
- Test: `tests/test_theme.lua`

**Interfaces:**
- Produces:
  - `Theme.textures.disc` (anti-aliased white disc, 256 x 256, alpha edge; the ring lines and the round portrait / badge masks are stacked discs: one disc per edge line, outside in, each `dia - 2 * i` in its shade, then the portrait masked to `dia - 2 * lines`), `spark`, `shield`.
  - `Theme.barTextures = { Smooth = { file, tint = 1.25 }, Flat = { file = WHITE8X8, tint = 1 }, Gloss = { file, tint = 1.05 } }`: the files are grey-scale vertical gradients normalized to their brightest stop (Smooth stops 1.25 / 1.0 at 45% / 0.72 → divided by 1.25; Gloss from `kit.js` `gloss`, with its white mix left in the file); the bar color is multiplied by `tint` (each channel clamped to 1) before `SetStatusBarColor`, so the middle reads as the color.
  - `Theme.sizes.unit = { badge = 18, focusBadge = 14, auraGap = 2, auraBelowCast = 6, castIcon = 18, castIconEdge = 2, ringStud = 9, auraTextShare = 0.42, barBgAlpha = 0.18, interruptHold = 0.6 }`.
  - `Theme.barColor(color, textureName) -> r, g, b` (pure, the tint rule above).
- [ ] **Step 1: Write the failing test** `"bar color tint"`: `Theme.barColor({ 0.4, 0.8, 0.2 }, "Smooth")` → `0.5, 1, 0.25`; `"Flat"` unchanged; an unknown name behaves as `"Smooth"`.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Write `tools/render_units.py` in the style of `tools/render_skins.py` (plain Python, writes uncompressed 32-bit TGA): disc, the two gradients (4 x 64), spark (a soft white vertical glow, 16 x 64, as the mockup's spark), shield (the mockup's shield outline, 32 x 32, white on transparent). Run it; add the files and the Theme entries.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: unit frame textures and theme entries`.

### Task 7: Drawn parts (panel, ring, bars, texts)

**Files:**
- Create: `AnotherHUD/Units/Parts/Panel.lua`, `AnotherHUD/Units/Parts/Ring.lua`, `AnotherHUD/Units/Parts/Bars.lua`
- Modify: `.toc`, `docs/DEVELOPMENT.md`, `docs/CHECKLIST.md`, `.luacheckrc` (`read_globals` for every new client API)
- Test: `tests/test_unit_parts.lua`

**Interfaces:**
- Consumes: `UnitLayout.frame`, `Theme.edgeRects`, `Theme.lineColors`, `Theme.barColor`, `Theme.textures.disc`.
- Produces (each `create(parent) -> part`, `part:layout(L, opts)`, plain frames and textures, nothing secure):
  - `Parts.Panel`: the panel fill (`panelTint`) and the skin's border as line textures, copied and adapted from AnotherLedger `UI/Widgets.lua` (`skinEdges` / `paintEdges`); Round uses the tooltip backdrop edge; Gilded studs on `L.studCorners`. `panel:layout(L, { skin })`.
  - `Parts.Ring`: stacked discs (Task 6) in the ring color's shades, portrait texture (`SetPortraitTexture(tex, unit, true)`, masked by a disc-shaped `MaskTexture`), Gilded ring studs when `L.ringStuds`, level badge (disc stack, panel fill, gold number). `ring:setUnit(unit)`, `ring:setColors(ringColor, badgeColor)`, `ring:setLevel(fmt, args)`, `ring:layout(L, { skin })`.
  - `Parts.Bars`: health and power `StatusBar`s with texture and background (color at 18%), the divider in the skin's Lines pick (`Theme.lineColors`), name / health / power font strings (`Theme.fonts.file`, `"OUTLINE"`). `bars:setHealth(cur, max)` (`SetMinMaxValues(0, max)`, `SetValue(cur)`), `bars:setPower(cur, max)`, `bars:setColors(healthRGB, powerRGB)`, `bars:setTexts(name, healthFmt, healthArgs, powerFmt, powerArgs)` (`SetFormattedText(fmt, unpack(args))`; an empty fmt → `SetText("")`), `bars:layout(L, { texture, fontSize, showName, mirror })` (name next to the ring, value at the far end, as in `units.js`).
- [ ] **Step 1: Write the failing tests** with `fakes.client{}` and `fakes.frame`:
  - `"bars take secrets"`: `setHealth(fakes.secret(1), fakes.secret(2))` and `setTexts` with secret args do not throw and store them.
  - `"bars layout follows the geometry"`: after `layout(UnitLayout.frame{ w = 200, h = 60, powerH = 15, portraitScale = 100, edge = 4 })` the health bar's recorded `SetPoint` offsets are `63.5, -5` (TOPLEFT) and `-5, ...` (right side), height 34.
  - `"no power bar when the layout has none"`: power bar hidden, divider hidden.
  - `"ring has one disc per edge line"`: Forge (5 lines) → 5 line discs.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement the three parts. Mark `MaskTexture` on a disc, `SetPortraitTexture` with secret units, and `SetFormattedText` taking secrets `UNVERIFIED (check in client)`; add the CHECKLIST lines.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: unit frame panel, portrait ring and bars`.

### Task 8: Cast bar and auras parts

**Files:**
- Create: `AnotherHUD/Units/Parts/CastBar.lua`, `AnotherHUD/Units/Parts/Auras.lua`
- Modify: `.toc`, `docs/DEVELOPMENT.md`, `docs/CHECKLIST.md`, `.luacheckrc`
- Test: `tests/test_unit_cast.lua`

**Interfaces:**
- Produces:
  - `Parts.CastBar.create(parent, unit) -> cast` (a plain frame: icon with 2 px edge, bar panel, `StatusBar`, spark on the fill end, name / time texts, shield over the icon, a grey overlay for uninterruptible). Methods:
    - `cast:update(event)`: reads `UnitCastingInfo` / `UnitChannelInfo` (by `select("#", ...)`, never by testing a secret), `UnitCastingDuration` / `UnitChannelDuration`; `SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, channel and RemainingTime or ElapsedTime)`; time text through `C_DurationUtil.CreateDurationTextBinding` with one decimal; `notInterruptible` plain → color pick and shield shown or hidden; secret → `shield:SetAlphaFromBoolean(v, 1, 0)` and the grey overlay likewise. No cast → hidden.
    - `UNIT_SPELLCAST_INTERRUPTED` (and a channel stop with an `interruptedBy`) → full bar in the interrupted color, text `L["Interrupted"]`, hidden after `Theme.sizes.unit.interruptHold = 0.6` s (`C_Timer.After`); a new cast ends the hold.
    - `cast:sample(on)`: Edit Mode: static 62% fill, `L["Sample Spell"]`, time `"0.9"`, cast color.
    - `cast:layout({ width, height, icon, skin })`.
    - `cast.EVENTS`: the `UNIT_SPELLCAST_*` list the owner registers with `RegisterUnitEvent`.
  - `Parts.Auras.create(parent, unit) -> auras`: one `CustomAuraContainerTemplate` container (created at login only; created later the client refuses them), groups `"HARMFUL|PLAYER"`, `"HARMFUL|!PLAYER"` (desaturated), `"HELPFUL|PLAYER"`, `"HELPFUL|!PLAYER"` (desaturated), `"HARMFUL|PLAYER"` only when Only Mine; debuff edges through `AddDispelTypeTexture` (Border style) in the type colors, buffs a 1 px `panelBorder` edge; flow layout horizontal, growing away from the portrait side, `perRow` / rows from `UnitLayout.auras`. `auras:layout({ size, rows, width, buffs, debuffs, onlyMine, mirror })`, `auras:sample(on)` (placeholder icons `Interface\\Icons\\INV_Misc_QuestionMark`, 4 debuffs + 2 buffs, plain times), `auras.available` false when the template is missing (then nothing shows, no error).
- [ ] **Step 1: Write the failing tests:**
  - `"cast with secret duration and flags"`: `fakes.units{ target = { casting = { name = fakes.secret(1), texture = 1, notInterruptible = fakes.secret(2), duration = fakes.secret(3) } } }`; `update("UNIT_SPELLCAST_START")` → `_timer[1]` is the duration (rawequal), shield `_alphaFrom[1]` is the flag.
  - `"plain uninterruptible cast is grey with the shield"`.
  - `"interrupted holds then hides"`: with `C_Timer.After` captured (not run at once); after the event the bar shows `"Interrupted"`; running the captured callback hides it; a `START` before the callback cancels the hide.
  - `"no cast hides the bar"`.
  - `"auras without the template stay quiet"`: `CreateFrame` throws for `"AuraContainer"` → `available == false`, `layout` and `sample` do not throw.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement. `UNVERIFIED (check in client)` on: `SetTimerDuration`, `CreateDurationTextBinding`, `SetAlphaFromBoolean` with a secret, the `!PLAYER` filter token, `AddDispelTypeTexture`, desaturating an aura group's icons, container creation at login; CHECKLIST lines for each.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: unit cast bar and aura rows`.

### Task 9: Unit frame base

**Files:**
- Create: `AnotherHUD/Units/Base.lua`
- Modify: `.toc`, `docs/DEVELOPMENT.md` (How things work: Unit frames), `docs/CHECKLIST.md`, `.luacheckrc`
- Test: `tests/test_unit_base.lua`

**Interfaces:**
- Consumes: Tasks 2-8.
- Produces `ns.Units.Base`:
  - `Base.create(spec, o) -> frame` with `o = { unit, name (global frame name), mirror, castBar = bool, auras = bool, badge = px|nil }`: `CreateFrame("Button", o.name, UIParent, "SecureUnitButtonTemplate")`, attributes `unit`, `*type1 = "target"`, `*type2 = "togglemenu"`, `RegisterForClicks("AnyUp")`; parts from Tasks 7-8 as children; tooltip on enter (`GameTooltip_SetDefaultAnchor`, `GameTooltip:SetUnit(unit)`); unit events with `RegisterUnitEvent` (`UNIT_HEALTH, UNIT_MAXHEALTH, UNIT_POWER_UPDATE, UNIT_POWER_FREQUENT, UNIT_MAXPOWER, UNIT_DISPLAYPOWER, UNIT_NAME_UPDATE, UNIT_LEVEL, UNIT_PORTRAIT_UPDATE, UNIT_MODEL_CHANGED, UNIT_FACTION, UNIT_CLASSIFICATION_CHANGED, UNIT_CONNECTION, UNIT_FLAGS` and the cast events) plus the unit's change event (`PLAYER_TARGET_CHANGED` for target, `PLAYER_FOCUS_CHANGED` for focus, `UNIT_TARGET` of `target` for `targettarget`, `UNIT_PET` of `player` for pet, `PLAYER_ENTERING_WORLD` for all), `PLAYER_REGEN_DISABLED` / `_ENABLED` for fading. `targettarget` gets no unit events from the client: it refreshes on a 0.2 s `OnUpdate` throttle while shown.
  - `Base.update(frame)`: everything from the client through Tasks 2-3 rules into the parts; `UnitExists` false → texts cleared, nothing else read.
  - `Base.apply(spec)`: reads every option with `Options.get`, lays the parts out (`UnitLayout.frame` with `edge = UnitLayout.edgeWidth(skin border)`), sizes the frame, sets the state driver `RegisterStateDriver(frame, "visibility", UnitState.visibility(unit, showInVehicle))` (all inside `Combat.after("unit:" .. spec.id)`), sets the alpha.
  - `Base.editMode(spec, active)`: on → `UnregisterStateDriver`, `Show`, every part's `sample(true)` (name = `UnitName("player")` for the player, else `L[spec.label]`; health 72%, power 55%, level `UnitLevel("player")`), alpha 1; off → samples off, state driver back, `Base.update`. Secure parts through `Combat.after`.
  - `Base.hideBlizzard(names)`: once per name, out of combat (`Combat.after("hide:" .. name)`): `UnregisterAllEvents`, `SetParent(hidden)` (our hidden frame), `hooksecurefunc(frame, "Show", fn)` with `fn` hiding it again out of combat.
- [ ] **Step 1: Write the failing tests** (fake client + `fakes.units`):
  - `"secure button with clicks"`: attributes `unit`, `*type1`, `*type2` set.
  - `"update passes secrets to the parts"`: health / power / percent secret; no throw; health bar `_value` is the secret.
  - `"unit gone: update hides texts and does not throw"`: `exists = false` after a first update → name `_text == ""` / health fmt empty; `UnitHealth` not called (count calls).
  - `"created in combat: secure work waits for PLAYER_REGEN_ENABLED"`: `fakes.client{ inCombat = true }`; `create` + `apply` → no `SetPoint` / `SetAttribute` / driver yet; `setCombat(false)`, `fire("PLAYER_REGEN_ENABLED")` → all present.
  - `"edit mode shows samples and restores visibility"`: target missing; `editMode(spec, true)` → frame shown, driver gone, health `_value == 0.72`; `editMode(spec, false)` → driver back with the target condition.
  - `"fading follows combat and hover"`: `outOfCombat = 40` → alpha 0.4; `fire("PLAYER_REGEN_DISABLED")` → 1; enter / leave scripts with `mouseover`.
  - `"hideBlizzard reparents once, and re-hides on Show"`.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement. `UNVERIFIED (check in client)`: `RegisterStateDriver` visibility with `[vehicleui]` / `[petbattle]`; hiding `PlayerFrame` / `TargetFrame` / `FocusFrame` / `PetFrame` / `PlayerCastingBarFrame` this way without taint; `togglemenu`; CHECKLIST lines.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: unit frame base (secure button, events, samples, fading)`.

### Task 10: The unit modules, Spike removed

**Files:**
- Create: `AnotherHUD/Units/Player.lua`, `Units/PlayerCastBar.lua`, `Units/Target.lua`, `Units/TargetTarget.lua`, `Units/Focus.lua`, `Units/Pet.lua`
- Delete: `AnotherHUD/Spike/` (and its `.toc` line)
- Modify: `.toc`, `Locales/deDE.lua`, `tests/test_checklist.lua` (the `Core.init` test counts the unit frames instead of the spike), `docs/DEVELOPMENT.md`
- Test: `tests/test_units.lua`

**Interfaces:**
- Consumes: `Units.Settings.build`, `Units.Base`, Glue's `parent` / `onEditMode`.
- Produces six modules (`kind = "unit"`, `create` → `Base.create` + `Base.apply`, `apply` → `Base.apply`, `onEditMode` → `Base.editMode`):

| id | label | unit | settings parts | defaults (overrides) | blizzard | defaultPosition |
| --- | --- | --- | --- | --- | --- | --- |
| `player` | Player | player | Size (portrait, power), Text, Look, Behaviour, Cast Bar (detach), Auras, Fading | — (shared) | `PlayerFrame`, `PlayerCastingBarFrame` | CENTER -260, -200 |
| `playercast` | Player Cast Bar | — | none (Settings button only) | — | — | CENTER 0, -280 |
| `target` | Target | target, mirrored | as Player, Cast Bar without detach | `healthText = "Percent"`, `powerText = "None"` | `TargetFrame` | CENTER 260, -200 |
| `targettarget` | Target of Target | targettarget, mirrored | Size (portrait), Text (no power), Look, Fading | `width = 120, height = 26, fontSize = 10, healthText = "None"` | — (part of `TargetFrame`) | CENTER 330, -300 |
| `focus` | Focus | focus | as Target | `width = 160, height = 40, powerHeight = 8, fontSize = 10, healthText = "Percent", powerText = "None"`, badge 14 | `FocusFrame` | CENTER -420, 40 |
| `pet` | Pet | pet | Size (portrait, power), Text, Look, Auras, Fading | `width = 120, height = 34, powerHeight = 6, fontSize = 10, healthText = "Percent", powerText = "None"` | `PetFrame` | CENTER -300, -290 |

  - Player and Target have the badge (18 px); ToT and Pet none.
  - Attached cast bar (Player and Target, `castBar` on): anchored under its frame at `L.below` px, as wide as `castWidth`; auras under the cast bar with `Theme.sizes.unit.auraBelowCast` (6 px) between, or under the frame at `L.below` without an attached cast bar.
  - `playercast` (`parent = "player"`): a plain holder frame of the cast bar's size, registered with Edit Mode like any module. `castDetach` on → the Player's cast bar is parented and anchored to the holder; the holder is shown in Edit Mode. Off → the holder stays hidden (so it can't be selected) and the bar hangs under the Player frame. Player's `apply` re-applies `playercast`.
- [ ] **Step 1: Write the failing tests** (`h.load(h.toc())` with the fake client, `fakes.units` and a fake lem as in `test_checklist.lua`):
  - `"all six modules register with Edit Mode"`: `Core.init()` → `lem.frames == 6`, `Modules.get("player").frame ~= nil`, no `spike` module.
  - `"checklist shows five unit frames"`: `Checklist.entries()` ids are `player, target, targettarget, focus, pet`.
  - `"labels and defaults fit"`: `Options.longLabels(Modules.list(), L, 24)` is empty in English and German.
  - `"detach moves the cast bar to its holder"`: `Options.set("player", "castDetach", true)` → cast bar parent is the holder; false → back under the player frame.
  - `"detach in combat applies after combat"`: same in combat; nothing moves until `PLAYER_REGEN_ENABLED`.
  - `"blizzard frames hidden at init"`: fake `PlayerFrame` etc. reparented after `Core.init()`.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement the six files, delete `Spike/`, update `test_checklist.lua`'s `Core.init` test and the German-label test there (drop `AnotherHUD Test`, `Show border`). `SystemSettings.lua` keeps writing `profile().spike.abLook` until Plan 5 replaces it; note that in `DEVELOPMENT.md`.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: player, target, target of target, focus and pet frames`.

### Task 11: Docs and the client check

**Files:**
- Modify: `README.md` (the five frames, their Edit Mode sections, Detach, what Blizzard frame each replaces; no texture paths / API names / pixel sizes), `docs/DEVELOPMENT.md`, `docs/CHECKLIST.md`, `CHANGELOG.md` (unreleased: one bullet per frame family)

- [ ] **Step 1:** Write the docs. `CHECKLIST.md` gets a "Unit frames (Plan 3)" block: every UNVERIFIED item from Tasks 7-9, plus: the five frames show with samples in Edit Mode and drag; leaving Edit Mode with no target hides Target / ToT / Focus; combat on a dummy with `/console taintLog 1`: no AnotherHUD lines, no blocked actions, target / menu clicks work in combat; secrets: a fight against a dummy and in a group shows health and power texts without Lua errors; Blizzard's Player / Target / Focus / Pet / cast bar never reappear (also after a vehicle and a pet battle); `/reload` in combat.
- [ ] **Step 2:** Run `lua tests/run.lua` (PASS); push the branch, open the MR, CI `test` and `lint` green.
- [ ] **Step 3:** Ask the player to run the client checks (other unit frame addons off for the test); record the results in `CHECKLIST.md`; fix what fails (each fix TDD, own commit).
- [ ] **Step 4: Commit** `docs: unit frames`; merge the MR once the player is happy.

## Not in this plan

- Party and Boss frames (Plan 4), with raid target, role and leader icons (none are in the approved Player / Target mockups).
- The Settings window (Plan 3 keeps the "Settings window comes later" message), profile switching that re-applies every module.
- Range fading, threat glow, heal prediction and absorbs, druid extra mana bar.
