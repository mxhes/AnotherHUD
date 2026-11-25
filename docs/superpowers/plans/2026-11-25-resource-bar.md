# Class Resource Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A segmented class resource bar (combo points, holy power, runes, soul shards, chi, arcane charges, essence) under the Player frame, detachable into its own Edit Mode frame, replacing the class resources that hiding Blizzard's `PlayerFrame` removed.

**Architecture:** Pure rules in `Core/Resource.lua` (which resource a class / spec has, segment count, rune order, essence regen, the attached geometry), a plain segment widget in `Bars/Segments.lua`, and the module in `Bars/Resource.lua`. The module copies the Player cast bar's holder pattern (`Units/PlayerCastBar.lua`): a child module of `player` whose holder is the Edit Mode frame only while detached; its options are a new "Resource Bar" section in the Player's panel. Attached, the bar sits under the Player frame and the Player's cast bar (or auras) move down below it.

**Tech Stack:** Lua 5.1 (WoW Forever, Interface 16001), plain-Lua tests (`lua tests/run.lua`), luacheck.

**Spec:** `docs/superpowers/specs/2026-11-21-anotherhud-design.md` ("Class resource bar") and the approved art `docs/mockups/APPROVED.md` §5 (`docs/mockups/5-resources.html`, variant B). The totem bar in both now belongs to the suite's action bar addon and is not part of this plan.

## Global Constraints

- Lua 5.1 code (CI runs 5.1 and 5.4): no `goto`, `//`, `table.unpack` without the `unpack or` fallback.
- Secret values: never do arithmetic, comparisons or `tostring` on a power value or rune / regen value from the client unless `ns.Util.isSecret(v)` is false and `ns.Util.isNumber(v)` is true; a secret count is only passed to `SetValue`. Tests use `fakes.secret()`, which throws on any operator.
- The resource bar is a plain frame (not secure). Anything that re-anchors it to or re-places parts of the secure Player frame goes through `ns.Combat.after(key, fn)` with keys `"bar:resource"` (bar anchor, size, holder) and the existing `"unit:player:cast"` (cast bar / aura placement). Show / Hide of the bar itself may run in combat.
- Art (APPROVED.md §5, verbatim values): one panel in the skin border split into equal segments by 1 px dividers in the skin's Lines pick; each segment a bar in the resource color, background the color at 18%; attached 4 px under the Player frame, starting right of the portrait ring and as wide as the health / power column (136 x 18 at the default Player size); detached default 200 x 20; partial points fill left to right at 55% of the color (`Theme.scaleColor(c, 0.55)`), with the seconds left (9 pt) centered on the segment.
- Colors (APPROVED.md §5): combo points (0.95, 0.35, 0.2), holy power (1, 0.82, 0.25), runes (0.85, 0.2, 0.25), frost runes (0.3, 0.7, 1), unholy runes (0.4, 0.85, 0.3), soul shards (0.62, 0.35, 0.95), chi (0.45, 0.95, 0.75), arcane charges (0.45, 0.55, 1), essence (0.35, 0.85, 0.8).
- Look values go in `Core/Theme.lua`; UI files read them from there.
- Options: a default, a label of 24 characters at most and a tooltip; read with `ns.Options.get`. Texts through `ns.L` (English key) with the German text in `Locales/deDE.lua`.
- Client APIs this plan starts to use get an `UNVERIFIED (check in client)` comment, a line in `docs/CHECKLIST.md` and an entry in `.luacheckrc` `read_globals`: `GetSpecialization`, `GetRuneCooldown`, `UnitPartialPower`, `GetPowerRegenForPowerType`, `UnitPowerDisplayMod`, `GetTime`, and `UnitPower(unit, type, true)` (unmodified fragments).
- New `.lua` files go in `AnotherHUD.toc` (after `Units/PlayerCastBar.lua`: `Bars/Segments.lua`, `Bars/Resource.lua`; `Core/Resource.lua` after `Core/GroupLayout.lua`) and in the layout table of `docs/DEVELOPMENT.md`.
- `luacheck AnotherHUD` 0 warnings and `lua tests/run.lua` all passing after every task.
- Commits `feat:` / `fix:` / `docs:` style, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Decisions this plan makes (the player can correct them at review)

- **In scope:** the seven resources of the spec list. Druids show combo points only in Cat Form (power type Energy); Monks chi only as Windwalker (spec 3); Mages arcane charges only as Arcane (spec 1); every Rogue, Paladin, Death Knight, Warlock and Evoker always.
- **Out of scope (backlog):** Brewmaster stagger, Rogue charged combo points, the encounter "alternate power" bar. Blizzard's Encounter Bar is its own Edit Mode system and is not hidden by AnotherHUD; that is a client check, not code.
- **Settings live in the Player panel** ("Resource Bar" section), like the cast bar; the detached holder ("Player Resource Bar") has no own settings. Turning the Player frame off turns the resource bar off too (Blizzard's Player frame and its class bars come back after /reload).
- **Partials and timers only when readable.** Secret rune cooldowns, partial essence or regen rate: whole points still show, the partial fill and seconds are left out.
- **The space under the Player frame stays reserved** whenever the class / spec has a resource (a Druid always), so shifting forms in combat never needs the secure cast bar moved.
- **Detached, the bar does not fade** with the Player frame (the detached cast bar does not either). Attached it is a child of the Player frame and fades with it.

## Review Focus

- Secret power values in combat, in every mode (points, fragments, runes, essence): the bar must keep showing whole points and never raise an error. Pinned in Task 2 and Task 4.
- A Druid shifting into and out of Cat Form in combat: the bar shows / hides at once, nothing secure moves, the cast bar keeps its place. Pinned in Task 4.
- Talents changing the maximum (a 6th or 7th combo point, 6th chi or essence) via `UNIT_MAXPOWER`: the segment count re-lays out. Pinned in Task 4.
- A class with no resource (Warrior, Hunter, Priest, Shaman, Demon Hunter) or a spec without one (Fire Mage, Brewmaster): no bar, no reserved gap, the holder never shows in Edit Mode. Pinned in Task 4.
- Detached, then the Player frame or the resource bar turned off: holder hidden, cast bar gap back to the ring's `L.below`. Pinned in Task 4.

---

### Task 1: Resource rules and theme values

**Files:**
- Create: `AnotherHUD/Core/Resource.lua`
- Modify: `AnotherHUD/Core/Theme.lua` (new `Theme.resourceColors`, `Theme.sizes.resource`)
- Modify: `AnotherHUD/AnotherHUD.toc` (after `Core/GroupLayout.lua`)
- Test: `tests/test_resource_rules.lua`

**Interfaces:**
- Produces:
  - `Theme.resourceColors = { combo, holy, runes, runesFrost, runesUnholy, shards, chi, arcane, essence }`, each `{ r, g, b }` with the Global Constraints values.
  - `Theme.sizes.resource = { attachedHeight = 18, gap = 4, detachedWidth = 200, detachedHeight = 20, partialShade = 0.55, timerFont = 9, maxSegments = 10, tick = 0.1 }`.
  - `Resource.forPlayer(class, spec) -> def | nil` where `def = { key, power, fallback, color, mode, form?, }`: `power` is the `Enum.PowerType` field name (`"ComboPoints"`, `"HolyPower"`, `"Runes"`, `"SoulShards"`, `"Chi"`, `"ArcaneCharges"`, `"Essence"`), `color` a `Theme.resourceColors` key, `mode` one of `"points" | "fragments" | "runes" | "essence"`, `form = "Energy"` for Druid only. Fallback counts: combo 5, holy 5, runes 6, shards 5, chi 5, arcane 4, essence 5. Returns a fresh table each call.
  - `Resource.active(def, powerToken) -> bool`: false for nil def; with `def.form`, true only when `powerToken == def.form`.
  - `Resource.runeColor(spec) -> key`: 2 -> `"runesFrost"`, 3 -> `"runesUnholy"`, else `"runes"`.
  - `Resource.count(max, fallback) -> n`: a readable number >= 1 gives `min(floor(max), maxSegments)`; secret, nil or < 1 gives `fallback`.
  - `Resource.runes(list, now) -> { { fill, left } ... }`: `list[i] = { start, duration, ready }` with plain numbers or nil (the caller drops secrets). Ready -> `fill = 1, left = nil`; recharging with numbers -> `fill = clamp((now - start) / duration, 0, 1)`, `left = start + duration - now`; anything unreadable -> `fill = 0, left = nil`. Sorted: ready first, then recharging by `left` ascending, unknown last; stable on ties by input index.
  - `Resource.essence(count, max, partial, rate) -> nil | { index, fill, left }`: nil unless all four are plain numbers and `count < max`; `index = count + 1`, `fill = partial / 1000` clamped 0..1, `left = (1 - fill) / rate` (nil when `rate <= 0`).
  - `Resource.timerText(left) -> string`: `""` for nil or `<= 0`, else `string.format("%d", math.ceil(left))`.
  - `Resource.attached(L) -> { x, w, h }`: `x = floor(L.bars.left + 0.5)`, `w = L.w - x`, `h = Theme.sizes.resource.attachedHeight`.
  - `Resource.reserve(h) -> px`: the gap the Player frame keeps below itself: `gap + h + gap` (26 at h = 18).

- [ ] **Step 1: Write the failing tests** in `tests/test_resource_rules.lua` (load with `h.load({ "Core/Util.lua", "Core/Theme.lua", "Core/UnitLayout.lua", "Core/Resource.lua" })`):

```lua
h.test("forPlayer maps classes and specs to their resource", function()
  local R = ns.Resource
  h.eq(R.forPlayer("ROGUE", 1).power, "ComboPoints")
  h.eq(R.forPlayer("DRUID", 2).form, "Energy")
  h.eq(R.forPlayer("PALADIN", 3).mode, "points")
  h.eq(R.forPlayer("DEATHKNIGHT", 1).mode, "runes")
  h.eq(R.forPlayer("WARLOCK", 3).mode, "fragments")
  h.eq(R.forPlayer("MONK", 3).power, "Chi")
  h.eq(R.forPlayer("MONK", 1), nil)
  h.eq(R.forPlayer("MAGE", 1).power, "ArcaneCharges")
  h.eq(R.forPlayer("MAGE", 2), nil)
  h.eq(R.forPlayer("EVOKER", 2).mode, "essence")
  for _, c in ipairs({ "WARRIOR", "HUNTER", "PRIEST", "SHAMAN", "DEMONHUNTER" }) do h.eq(R.forPlayer(c, 1), nil, c) end
end)
h.test("active needs Cat Form for druids", ...)        -- Energy true, Mana / Rage false, nil def false
h.test("runeColor follows the death knight spec", ...)  -- 1 runes, 2 runesFrost, 3 runesUnholy, nil runes
h.test("count falls back when max is unreadable", function()
  h.eq(ns.Resource.count(6, 5), 6); h.eq(ns.Resource.count(12, 5), 10)
  h.eq(ns.Resource.count(0, 5), 5); h.eq(ns.Resource.count(nil, 4), 4)
  -- with _G.issecretvalue = fakes.isSecret:
  h.eq(ns.Resource.count(fakes.secret(6), 6), 6)
end)
h.test("runes sort ready first, then by time left", function()
  local out = ns.Resource.runes({ { 10, 10, false }, { 0, 10, true }, { 14, 10, false }, {}, { 0, 10, true }, { 12, 10, false } }, 16)
  h.eq(out[1], { fill = 1 }); h.eq(out[2], { fill = 1 })
  h.near(out[3].fill, 0.6); h.near(out[3].left, 4)   -- start 10
  h.near(out[4].left, 6); h.near(out[5].left, 8)
  h.eq(out[6], { fill = 0 })                          -- the empty entry
end)
h.test("essence gives the regenerating segment", function()
  local e = ns.Resource.essence(3, 5, 550, 0.2)
  h.eq(e.index, 4); h.near(e.fill, 0.55); h.near(e.left, 2.25)
  h.eq(ns.Resource.essence(5, 5, 0, 0.2), nil)
  h.eq(ns.Resource.essence(3, 5, 550, 0).left, nil)
  -- secret partial: nil (no operator touched)
end)
h.test("timerText rounds up whole seconds", ...)      -- 2.25 -> "3", 0 -> "", nil -> "", 9.0 -> "9"
h.test("attached spans the health / power column", function()
  local L = ns.UnitLayout.frame({ w = 200, h = 60, powerH = 15, edge = 1 })
  h.eq(ns.Resource.attached(L), { x = 64, w = 136, h = 18 })
  h.eq(ns.Resource.reserve(18), 26)
end)
h.test("theme carries the approved resource colors", ...) -- every key above, values verbatim
```

- [ ] **Step 2: Run** `lua tests/run.lua`. Expected: the new tests FAIL (`Core/Resource.lua` missing).
- [ ] **Step 3: Implement** `Core/Resource.lua` (pure: no client calls at load or in these functions; `ns.Util.isSecret` / `isNumber` for every input) and the Theme values; add the `.toc` line.
- [ ] **Step 4: Run** `lua tests/run.lua` and `luacheck AnotherHUD`. Expected: all pass, 0 warnings.
- [ ] **Step 5: Commit** `feat: resource bar rules and colors`.

### Task 2: Segment widget

**Files:**
- Create: `AnotherHUD/Bars/Segments.lua`
- Modify: `AnotherHUD/AnotherHUD.toc` (after `Units/PlayerCastBar.lua`)
- Test: `tests/test_segments.lua`

**Interfaces:**
- Consumes: `Theme.sizes.resource`, `Theme.scaleColor`, `Theme.barColor`, `Theme.lineColors`, `ns.Units.Parts.Panel` (create / layout; pass `L = { studCorners = {} }` so no studs).
- Produces `ns.Bars.Segments` (`ns.Bars = ns.Bars or {}`):
  - `Segments.create(parent) -> seg` with `seg.frame` (all points of `parent`), `seg.panel`, `seg.slots[i] = { bg, partial, full, text }` created on demand, `seg.dividers[i]`.
  - `seg:layout(o)`, `o = { w, h, count, skin, texture, rgb }`: panel in the skin border; the inner area (inside `UnitLayout.edgeWidth(skin.border)`) split into `count` equal slots with a 1 px divider between neighbours painted like the health / power divider in `Units/Parts/Bars.lua` (`Theme.lineColors` with the skin's `lines`); per slot a `bg` texture in `rgb` at alpha `Theme.sizes.unit.barBgAlpha`, a `partial` StatusBar in `Theme.scaleColor(rgb, partialShade)` above it and a `full` StatusBar in `rgb` above that (both with no background of their own, texture from `Theme.textures` by `texture` name as the unit bars do), and a `text` font string on top (`Theme.fonts.file`, `timerFont`, `"OUTLINE"`) centered on the slot. Slots past `count` are hidden. `full:SetMinMaxValues(i - 1, i)` for every slot.
  - `seg:setPoints(value)`: `full:SetValue(value)` on every shown slot; `value` may be secret and is passed as given.
  - `seg:setFragments(raw, mod)`: `partial:SetMinMaxValues((i - 1) * mod, i * mod)` and `partial:SetValue(raw)` on every slot (`mod` is a plain number; `raw` may be secret).
  - `seg:setPartial(i, fill, left)`: plain numbers only: slot `i`'s `partial` range 0..1 set to `fill`, `text:SetText(Resource.timerText(left))`; `full` untouched. Used for regenerating essence.
  - `seg:setSlot(i, fill, left)`: plain numbers only, for runes (each slot its own state): `fill >= 1` -> `full:SetValue(i)` and partial / text cleared; else `full:SetValue(i - 1)` (empty) and `setPartial(i, fill, left)`.
  - `seg:clearPartials()`: every `partial:SetValue(0)` with range 0..1 and every `text:SetText("")`.

- [ ] **Step 1: Write the failing tests** in `tests/test_segments.lua` (fake client via `fakes.client()`; load Util, Locale, Theme, UnitLayout, Resource, `Units/Parts/Panel.lua`, `Bars/Segments.lua`):
  - `"layout splits the inner width into count slots"`: `w = 136, h = 18, count = 5`, Classic skin: 5 slots shown, 4 dividers shown, slot widths add up to the inner width minus 4 dividers.
  - `"layout hides slots past count"`: layout 6 then 3: slots 4-6 and dividers 3-5 hidden.
  - `"colors follow the approved shades"`: `rgb = Theme.resourceColors.holy`: `bg` vertex color alpha 0.18, `partial` color = `Theme.scaleColor(holy, 0.55)` (through `Theme.barColor` as the bars do).
  - `"setPoints passes a secret through"`: `seg:setPoints(fakes.secret(3))` does not throw and every `full._value` is that secret.
  - `"setFragments ranges per slot"`: `setFragments(23, 10)`: slot 3 partial min/max 20..30, value 23.
  - `"setSlot fills one slot with its timer"`: `setSlot(2, 0.4, 3.2)`: slot 2 partial value 0.4, text `"4"`, `full._value` 1 (empty); `setSlot(2, 1)` -> `full._value` 2, text `""`; `clearPartials()` empties partials and texts.
- [ ] **Step 2: Run** `lua tests/run.lua`. Expected: new tests FAIL.
- [ ] **Step 3: Implement** `Bars/Segments.lua`; `.toc` line. Plain frames and textures only.
- [ ] **Step 4: Run** tests and luacheck. Expected: pass, 0 warnings.
- [ ] **Step 5: Commit** `feat: segmented bar widget`.

### Task 3: Resource Bar settings and reserved space under the Player frame

**Files:**
- Modify: `AnotherHUD/Units/Settings.lua` (new builder `"Resource Bar"`, `parts.resource` option)
- Modify: `AnotherHUD/Units/Player.lua` (parts gain `"Resource Bar"` after `"Cast Bar"`)
- Modify: `AnotherHUD/Units/Base.lua` (`Base.reserveBelow`, used by `placeCast` / `placeAuras`)
- Modify: `AnotherHUD/Locales/deDE.lua`
- Test: `tests/test_unit_settings.lua`, `tests/test_unit_base.lua`

**Interfaces:**
- Produces:
  - Section `"Resource Bar"` (only with `parts.resource`): `showResource` (checkbox, default `true`, "Show resource bar", "Show your class resource (combo points, holy power, runes, ...)."), `resourceDetach` (checkbox, `false`, "Detach resource bar", "Make the resource bar a separate frame you can move."), `resourceWidth` (slider 80-400 step 1, default 200, "Resource bar width", "Width of the resource bar when detached."), `resourceHeight` (slider 10-40 step 1, default 20, "Resource bar height", "Height of the resource bar when detached."), `resourceTimers` (checkbox, `true`, "Show recharge timers", "Show the seconds left on recharging runes and essence.").
  - `Base.reserveBelow(frame, px)`: stores `frame.reserved = px or 0` and queues `placeCast` under the existing key `"unit:" .. frame.key .. ":cast"`. With `reserved > 0`, the cast bar under the frame sits at `max(frame.castGap or L.below, reserved)` below it, and auras placed directly under the frame (cast bar off or detached) at `max(L.below, reserved)`. `reserved = 0` keeps today's placement exactly.
  - deDE: "Resource Bar" = "Ressourcenleiste", "Player Resource Bar" = "Spielerressourcenleiste", plus the five labels and tooltips (German texts the implementer writes in the file's style).

- [ ] **Step 1: Write the failing tests:**
  - `test_unit_settings.lua` `"the Resource Bar section has its five controls and defaults"`: build `{ "Cast Bar", "Resource Bar", detach = true, resource = true }`: section order, keys, defaults above, every label <= 24 characters.
  - `test_unit_settings.lua` `"Player lists Resource Bar after Cast Bar"`.
  - `test_unit_base.lua` `"reserveBelow pushes the cast bar under the resource bar"`: default Player frame (`L.below = 14`): `reserveBelow(frame, 26)` -> cast bar `SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -26)`; `reserveBelow(frame, 0)` -> `-14` again.
  - `test_unit_base.lua` `"reserveBelow moves auras when the cast bar is off"`: `castBar = false`, reserved 26 -> auras at `-26`.
  - `test_unit_base.lua` `"reserveBelow waits for combat to end"`: in combat no SetPoint until `PLAYER_REGEN_ENABLED`.
- [ ] **Step 2: Run** `lua tests/run.lua`. Expected: new tests FAIL.
- [ ] **Step 3: Implement** the builder, Player parts, `Base.reserveBelow` and the deDE lines.
- [ ] **Step 4: Run** tests and luacheck. Expected: pass, 0 warnings.
- [ ] **Step 5: Commit** `feat: Resource Bar settings and space under the Player frame`.

### Task 4: The resource bar module

**Files:**
- Create: `AnotherHUD/Bars/Resource.lua`
- Modify: `AnotherHUD/Units/Player.lua` (apply order), `AnotherHUD/AnotherHUD.toc` (after `Bars/Segments.lua`), `.luacheckrc`
- Modify: `README.md`, `docs/DEVELOPMENT.md`, `docs/CHECKLIST.md`, `docs/BACKLOG.md`, `CLAUDE.md` (Status line)
- Test: `tests/test_resource.lua`; update `tests/test_units.lua` ("all eight modules register" becomes nine, with `"resource"` in the id list and its kind `"bar"`)

**Interfaces:**
- Consumes: Task 1 `Resource.*`, Task 2 `Segments`, Task 3 options and `Base.reserveBelow`, `ns.Units.Base.anchorCast`, `ns.Modules`, `ns.Combat.after`, `ns.Options.get("player", key)`, `ns.UnitLayout.frame` via the Player frame's `frame.L`.
- Produces: module `{ id = "resource", label = "Player Resource Bar", kind = "bar", parent = "player", defaults = {}, settings = {}, defaultPosition = { point = "CENTER", x = 0, y = -240 } }`. Holder `AnotherHUDResourceBarHolder` (child of UIParent, the Edit Mode frame), bar `AnotherHUDResourceBar` (plain frame holding a `Segments`). `spec.bar` is the bar frame, `spec.seg` the widget, `spec.def` the current def or nil.
- Behaviour:
  - **def:** `Resource.forPlayer(select(2, UnitClass("player")), GetSpecialization())`, recomputed on `PLAYER_ENTERING_WORLD`, `PLAYER_SPECIALIZATION_CHANGED` (player).
  - **on:** `Modules.isEnabled("resource")` and `showResource` and `def ~= nil`. **Attached:** on and not `resourceDetach`.
  - **apply (Combat.after "bar:resource"):** attached: bar parented to the Player frame, `TOPLEFT` at the Player frame's `BOTTOMLEFT` + (`x`, `-gap`), size `w x h` from `Resource.attached(frame.L)`; holder hidden. Detached: holder sized `resourceWidth x resourceHeight` and shown, bar parented to it with all points. Off: holder and bar hidden. Then `Base.reserveBelow(playerFrame, attached and Resource.reserve(h) or 0)`. `seg:layout` with the Player's `skin` and `barTexture`, the def's color (`runeColor(spec)` for runes) and `Resource.count(UnitPowerMax("player", Enum.PowerType[def.power]), def.fallback)`.
  - **Player.lua apply order:** `Base.apply(spec)`, then the resource module's apply, then the cast holder's apply (so `reserveBelow` is set before the cast bar is placed).
  - **shown:** on and `Resource.active(def, powerToken)` (`powerToken` from `UnitPowerType("player")`'s second return), or Edit Mode open. Show / Hide here run directly (bar is not secure). The reserved space does not depend on `active`.
  - **events** (bar frame; `RegisterUnitEvent(..., "player")` for unit events): `UNIT_POWER_FREQUENT`, `UNIT_POWER_UPDATE`, `UNIT_MAXPOWER` (re-layout when the count changes), `UNIT_DISPLAYPOWER`, `UPDATE_SHAPESHIFT_FORM`, `RUNE_POWER_UPDATE`, `PLAYER_ENTERING_WORLD`, `PLAYER_SPECIALIZATION_CHANGED`.
  - **values per mode:** `points`: `seg:setPoints(UnitPower("player", type))`. `fragments`: `seg:setPoints(UnitPower("player", type))` and `seg:setFragments(UnitPower("player", type, true), mod)` with `mod = UnitPowerDisplayMod(type)` when a plain number > 0, else 10. `runes`: `Resource.runes` over `GetRuneCooldown(1..count)` (secret fields become nil), `seg:setSlot(i, fill, timers and left)`. `essence`: `seg:setPoints(count)`, then `Resource.essence(count, max, UnitPartialPower("player", type), GetPowerRegenForPowerType(type))` -> `seg:setPartial(index, fill, timers and left)`, else `clearPartials()`.
  - **ticker:** while a rune is recharging or essence is regenerating (and readable), an `OnUpdate` on the bar refreshes runes / essence every `tick` (0.1 s) and removes itself when nothing recharges.
  - **Edit Mode** (`onEditMode`): sample on open: `setPoints(3)` and, for runes / essence, slot 4 at fill 0.55 with `"2"` (as the mockup); values return on close. Holder shown in Edit Mode only while detached and `def ~= nil`.
  - Turning the Player frame off turns the bar off (parent rule); `Modules.isEnabled` honored in apply (the existing "every module's apply honors isEnabled" test covers it).
- Docs: README "Unit frames" table gains no row; a short "Class resources" paragraph (what shows per class, attached under the Player frame, Detach resource bar, timers) and the Known gaps line drops class resources (totems and the encounter bar remain). DEVELOPMENT: layout rows for `Core/Resource.lua`, `Bars/Segments.lua`, `Bars/Resource.lua` (replacing the planned row, `Bars/Tracking.lua` stays planned), and a short "Resource bar" section (holder pattern, reserved space, secret handling). CHECKLIST: a "Plan 5: resource bar" section with one line per UNVERIFIED API plus: each class's bar in the client, Druid Cat Form in combat, Encounter Bar still shows in a fight that uses it. BACKLOG: replace the resource line with "Brewmaster stagger, Rogue charged combo points on the resource bar." CLAUDE.md status: "Plans 1-5 built ... Next: XP / Reputation."

- [ ] **Step 1: Write the failing tests** in `tests/test_resource.lua` (Core.init through the `.toc` like `test_units.lua`; install `UnitClass`, `GetSpecialization`, `UnitPower(unit, type, raw)`, `UnitPowerMax`, `UnitPowerType`, `UnitPowerDisplayMod`, `GetRuneCooldown`, `UnitPartialPower`, `GetPowerRegenForPowerType`, `GetTime`, `Enum.PowerType` with `fakes.withGlobals`):
  - `"a paladin gets five holy power segments under the Player frame"`: 5 slots; bar `SetPoint("TOPLEFT", playerFrame, "BOTTOMLEFT", 64, -4)`, size 136 x 18; cast bar at `-26`.
  - `"a warrior gets no bar and no reserved space"`: bar and holder hidden, cast bar at `-14`.
  - `"secret holy power reaches the segments untouched"`: `UnitPower` returns `fakes.secret(3)`, fire `UNIT_POWER_FREQUENT`: no error, slot `full._value` is the secret.
  - `"a druid's bar follows Cat Form in combat"`: in combat, power token `"ENERGY"` -> shown, `"MANA"` + `UPDATE_SHAPESHIFT_FORM` -> hidden; no cast bar SetPoint recorded during combat.
  - `"UNIT_MAXPOWER re-lays out the segments"`: rogue max 5 -> 7: 7 slots shown.
  - `"soul shard fragments fill the next shard"`: raw 23, mod 10: slot 3 partial value 23; secret raw passes through.
  - `"recharging runes sort and show seconds"`: 4 ready + 2 recharging; slot 5 text from `timerText`; `resourceTimers = false` -> text `""`; a secret `start` -> that rune `fill = 0`, no error.
  - `"essence shows the regenerating segment"`: count 3 of 5, partial 550, rate 0.2: slot 4 partial 0.55, text `"3"`; secret partial -> `clearPartials`, whole points still set.
  - `"detach moves the bar to its holder and frees the space"`: `resourceDetach = true`: holder shown 200 x 20, cast bar back at `-14`; Player turned off -> holder hidden.
  - `"Edit Mode shows the sample"`: open -> `full._value` 3 on every slot; close -> real values back.
  - `"a fire mage has no bar"`: `GetSpecialization` 2 -> hidden; spec change event to 1 -> shown with 4 slots.
- [ ] **Step 2: Run** `lua tests/run.lua`. Expected: new tests FAIL (module missing).
- [ ] **Step 3: Implement** `Bars/Resource.lua`, the Player apply order, `.toc`, `.luacheckrc` `read_globals`, and the `test_units.lua` count update.
- [ ] **Step 4: Run** tests and luacheck. Expected: pass, 0 warnings.
- [ ] **Step 5: Update the docs** listed above (README free of API names, texture paths and pixel sizes).
- [ ] **Step 6: Commit** `feat: class resource bar` (code) and `docs: resource bar` (docs), or one commit with both.
