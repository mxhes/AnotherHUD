# XP / Reputation Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An XP bar and a reputation bar (the watched faction) in one movable Edit Mode frame, replacing Blizzard's status tracking bars.

**Architecture:** Pure rules in `Core/Tracking.lua` (what each bar shows, its range, the rested part, the texts). The module `Bars/Tracking.lua` (`ns.Modules.define`, kind `"bar"`, its own Edit Mode frame and checklist entry) draws one or two stacked bars in the skin border and hides Blizzard's status tracking bars. Plain frames only: nothing secure, so nothing waits for combat except Blizzard's hiding (`Base.hideBlizzard`).

**Tech Stack:** Lua 5.1 (WoW Forever, Interface 16001), plain-Lua tests (`lua tests/run.lua`), luacheck.

**Spec:** `docs/superpowers/specs/2026-11-21-anotherhud-design.md` ("XP / Reputation bar"). No mockup exists for this bar; see Decisions.

## Global Constraints

- Lua 5.1 code (CI runs 5.1 and 5.4): no `goto`, `//`, `table.unpack` without the `unpack or` fallback.
- Client numbers (XP, rested XP, reputation values) are read as plain only after `ns.Util.isSecret(v)` is false and `ns.Util.isNumber(v)` is true; otherwise they only travel into `SetValue` / `SetMinMaxValues`, and texts and the rested part are left out.
- Look values (colors, sizes) live in `Core/Theme.lua`; UI files read them from there.
- Options: a default, a label of 24 characters at most and a tooltip; read with `ns.Options.get("tracking", key)`. Texts through `ns.L` (English key) with the German text in `Locales/deDE.lua`.
- Client APIs this plan starts to use get an `UNVERIFIED (check in client)` comment, a line in `docs/CHECKLIST.md` and a `.luacheckrc` `read_globals` entry: `UnitXP`, `UnitXPMax`, `GetXPExhaustion`, `IsXPUserDisabled`, `IsPlayerAtEffectiveMaxLevel`, `C_Reputation.GetWatchedFactionData`, `GetWatchedFactionInfo`, `FACTION_BAR_COLORS`, `BreakUpLargeNumbers`, and the frames `StatusTrackingBarManager`, `MainStatusTrackingBarContainer`, `SecondaryStatusTrackingBarContainer`.
- New `.lua` files go in `AnotherHUD.toc` (`Core/Tracking.lua` after `Core/Resource.lua`; `Bars/Tracking.lua` after `Bars/Resource.lua`) and the layout table of `docs/DEVELOPMENT.md` (replacing the "planned" row).
- `luacheck AnotherHUD` 0 warnings and `lua tests/run.lua` all passing after every task.
- Commits `feat:` / `fix:` / `docs:` style, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Decisions (made without the player this time, at their request; they can correct them at review)

- **Own bars, not re-skinned Blizzard bars.** The spec said "re-skinned Blizzard status tracking bars" back when action bars were re-skinned too. AnotherHUD now draws its own frames everywhere; own bars are testable and touch no Blizzard code. Blizzard's status tracking bars are hidden like the unit frames.
- **No new art.** The bars reuse the approved unit frame look: the skin's panel and border (`Units/Parts/Panel.lua`), the bar texture pick, the bar background at 18% (`Theme.sizes.unit.barBgAlpha`), the 1 px divider between the two bars in the skin's Lines pick, the unit text font. Colors are the game's usual ones: XP purple (0.58, 0, 0.55), rested XP blue (0, 0.39, 0.88) shown as a lighter band ahead of the XP fill at 40% alpha, reputation in the client's `FACTION_BAR_COLORS[reaction]` with a Theme copy of the standard eight as fallback. The player may ask for a mockup and a different look later.
- **What shows:** the XP bar while XP can be gained (not at max level, XP not turned off); the reputation bar while a faction is watched. XP on top when both show. No bar to show: the frame hides (Edit Mode shows a sample of both). Renown, friendship and paragon progress show as plain reputation values (backlog).
- **Texts:** on mouse-over by default (Text option `"Hover"`, also `"Always"` / `"Never"`). XP: `"Level 42  12,345 / 50,000 (24%)"` plus `"  +3,000 rested"` when rested; reputation: `"Faction  Friendly  1,200 / 6,000"`; at the top of a standing (min == max): `"Faction  Exalted"`.
- **Default place:** bottom center (`{ point = "BOTTOM", x = 0, y = 2 }`), 500 x 10 per bar, 1 px between them.
- Not in this plan (backlog): honor, artifact / azerite bars, clicking the bar to open the reputation pane, hiding in pet battles.

## Review Focus

- A level-up to max level, or XP turned off, while playing: the XP bar goes away and the reputation bar moves up (or the frame hides). Pinned in Task 2.
- Watching no faction, then picking one in the reputation pane (`UPDATE_FACTION`): the bar appears without a /reload. Pinned in Task 2.
- A standing at its top (Exalted: min == max) or a zero XP maximum (brief at login): no division by zero, the bar shows full / empty and the text has no percent. Pinned in Task 1.
- Values the client hands over as secret: bars still fill, texts and the rested band stay empty, no error. Pinned in Task 1 and Task 2.
- Turning the module off in the checklist: our frame hides at once; Blizzard's bars come back only after /reload (as for unit frames). Pinned in Task 2.

---

### Task 1: Tracking rules and theme values

**Files:**
- Create: `AnotherHUD/Core/Tracking.lua`
- Modify: `AnotherHUD/Core/Theme.lua` (`Theme.trackingColors`, `Theme.sizes.tracking`), `AnotherHUD/AnotherHUD.toc`
- Test: `tests/test_tracking_rules.lua`

**Interfaces:**
- Produces:
  - `Theme.trackingColors = { xp = { 0.58, 0, 0.55 }, rested = { 0, 0.39, 0.88 }, reaction = { [1] = { 0.8, 0.3, 0.22 }, [2] = { 0.8, 0.3, 0.22 }, [3] = { 0.75, 0.27, 0 }, [4] = { 0.9, 0.7, 0 }, [5] = { 0, 0.6, 0.1 }, [6] = { 0, 0.6, 0.1 }, [7] = { 0, 0.6, 0.1 }, [8] = { 0, 0.6, 0.1 } } }`.
  - `Theme.sizes.tracking = { width = 500, height = 10, gap = 1, restedAlpha = 0.4, textFont = 10 }`.
  - `Tracking.xp(s) -> nil | { value, max, restedEnd, text }` with `s = { xp, max, rested, level, atMax, disabled }`: nil when `atMax` or `disabled`. `value`, `max` passed as given (may be secret). When `xp`, `max` are plain and `max > 0`: `restedEnd = min(xp + rested, max)` when `rested` is a plain number > 0 (else nil) and `text = Tracking.xpText(level, xp, max, rested)`. Otherwise `restedEnd = nil`, `text = nil`.
  - `Tracking.xpText(level, xp, max, rested) -> string`: `"Level %d  %s / %s (%d%%)"` with `Tracking.number` and `floor(xp / max * 100)`; plus `"  +%s rested"` when rested > 0. `max <= 0`: no percent part.
  - `Tracking.reputation(d) -> nil | { name, min, max, value, reaction, text }`: `d` is either the table from `C_Reputation.GetWatchedFactionData()` (`name`, `reaction`, `currentReactionThreshold`, `nextReactionThreshold`, `currentStanding`) or `{ legacy = { name, reaction, min, max, value } }` from `GetWatchedFactionInfo()`. nil for nil d or no plain non-empty name. Range and value passed as given. Text only when min, max, value are plain: `"%s  %s  %s / %s"` with the standing label `Tracking.standing(reaction)` and `value - min` / `max - min`; when `max <= min`: `"%s  %s"` (name, standing) and the caller fills the bar (`min = 0, max = 1, value = 1`).
  - `Tracking.standing(reaction) -> string`: English keys `"Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted"` for 1..8 (through `ns.L` when drawn), `""` otherwise.
  - All words in these texts ("Level", "rested", the standings) go through `ns.L` when the text is built (tests run in English).
  - `Tracking.number(n) -> string`: thousands separated with `","` (`12345 -> "12,345"`); plain integers only (callers guarantee). Uses the client's `BreakUpLargeNumbers` when it exists, else its own.
  - `Tracking.reactionColor(reaction) -> rgb`: `FACTION_BAR_COLORS[reaction]` (`r, g, b`) when the global has it, else `Theme.trackingColors.reaction[reaction]`, else neutral (4).

- [ ] **Step 1: Write the failing tests** in `tests/test_tracking_rules.lua` (`h.load({ "Core/Util.lua", "Core/Theme.lua", "Core/Tracking.lua" })`; secret cases with `issecretvalue = fakes.isSecret`):
  - `"xp hides at max level and when turned off"`: `atMax = true` -> nil; `disabled = true` -> nil.
  - `"xp gives range, rested end and text"`: `{ xp = 12345, max = 50000, rested = 3000, level = 42 }` -> `value 12345, max 50000, restedEnd 15345, text "Level 42  12,345 / 50,000 (24%)  +3,000 rested"`; rested past max -> `restedEnd = max`; rested 0 -> no rested part, `restedEnd` nil.
  - `"xp with a zero maximum has no percent"`: `max = 0` -> no error, `text` nil, `restedEnd` nil.
  - `"secret xp passes through without text"`: xp secret -> `value` is that secret, `text` nil, `restedEnd` nil.
  - `"reputation reads both client shapes"`: modern `{ name = "Argent Dawn", reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000, currentStanding = 4200 }` and legacy `{ legacy = { "Argent Dawn", 5, 3000, 9000, 4200 } }` both -> `min 3000, max 9000, value 4200, text "Argent Dawn  Friendly  1,200 / 6,000"`.
  - `"reputation at the top of a standing shows full"`: min == max -> `min 0, max 1, value 1, text "Argent Dawn  Exalted"` (reaction 8).
  - `"no watched faction gives nil"`: nil, `{}`, name `""`, secret name -> nil.
  - `"reactionColor falls back to the theme"`: no global -> Theme value; global `FACTION_BAR_COLORS[5] = { r = 1, g = 2, b = 3 }` -> `{ 1, 2, 3 }`; reaction 99 -> neutral.
  - `"number separates thousands"`: 0 -> "0", 999 -> "999", 1000 -> "1,000", 1234567 -> "1,234,567".
- [ ] **Step 2: Run** `lua tests/run.lua`. Expected: new tests FAIL.
- [ ] **Step 3: Implement** `Core/Tracking.lua` (pure; no client calls at load) and the Theme values; `.toc` line.
- [ ] **Step 4: Run** tests and `luacheck AnotherHUD`. Expected: pass, 0 warnings.
- [ ] **Step 5: Commit** `feat: XP and reputation rules`.

### Task 2: The XP / Reputation module

**Files:**
- Create: `AnotherHUD/Bars/Tracking.lua`
- Modify: `AnotherHUD/AnotherHUD.toc`, `.luacheckrc`, `AnotherHUD/Locales/deDE.lua`
- Modify: `README.md`, `CHANGELOG.md`, `docs/DEVELOPMENT.md`, `docs/CHECKLIST.md`, `docs/BACKLOG.md`, `CLAUDE.md` (Status)
- Test: `tests/test_tracking.lua`; update the module / Edit Mode frame counts in `tests/test_units.lua` and `tests/test_checklist.lua` (one more module, listed in the checklist)

**Interfaces:**
- Consumes: Task 1 `Tracking.*`, Theme values; `ns.Units.Parts.Panel`; `ns.Units.Base.hideBlizzard`, `ns.Units.Base.skinOf` (or the Theme skin lookup it uses); `ns.UnitState.alpha`; `ns.EditMode.Glue.inEditMode`; `Theme.barColor`, `Theme.lineColors`, `Theme.textures`, `Theme.fonts`.
- Produces: module `{ id = "tracking", label = "XP / Reputation", kind = "bar", defaults, settings, blizzard = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }, defaultPosition = { point = "BOTTOM", x = 0, y = 2 }, create, apply, onEditMode }`. Frame `AnotherHUDTrackingBar` (child of UIParent; the Edit Mode frame), holding the panel, `spec.xp` and `spec.rep` (each `{ bar (StatusBar), rested (StatusBar under the fill, XP only), bg, text }`) and a divider.
- Settings (sections in panel order; controls as `{ key, type, label, tooltip, min, max, step, values }` like `Units/Settings.lua`):
  - "Size": `width` slider 100-1600 step 1 (default `Theme.sizes.tracking.width`, "Width", "Width of the bars."), `height` slider 4-30 step 1 (default `Theme.sizes.tracking.height`, "Bar height", "Height of each bar.").
  - "Text": `text` dropdown `{ "Hover", "Always", "Never" }` default `"Hover"` ("Show text", "When the bars show their numbers."), `fontSize` slider 8-16 default `Theme.sizes.tracking.textFont` ("Text size", "Size of the bar texts.").
  - "Look": `skin` dropdown `{ "Classic", "Forge", "Slate", "Gilded" }` default `"Classic"` ("Skin", "Border and decoration style of the bars."), `barTexture` dropdown `{ "Smooth", "Flat", "Gloss" }` default `"Smooth"` ("Bar texture", "Look of the bar fill.").
  - "Behaviour": `showXP` checkbox default true ("Show XP", "Show the experience bar while you can gain XP."), `showReputation` checkbox default true ("Show reputation", "Show the reputation of the faction you watch.").
  - "Fading": `outOfCombat` slider 0-100 step 5 default 100 ("Out of combat opacity", "Opacity of the bars out of combat, in percent."), `mouseover` checkbox default true ("Show on mouseover", "Show the bars fully while the mouse is over them.").
- Behaviour:
  - **apply:** honors `Modules.isEnabled("tracking")` (off: frame hidden, nothing else). Sizes the frame to `width x (rows * height + (rows - 1) * gap + 2 * edge)` where `rows` is the number of bars shown (1 when none; the frame is hidden then) and `edge = UnitLayout.edgeWidth(skin.border)`; lays out the panel, the bars (XP on top), the divider (shown only with two rows), the texts (font `Theme.fonts.file`, `fontSize`, `"OUTLINE"`, centered). Frame size is not protected: no Combat.after needed for this plain frame.
  - **values** (`update`): XP from `Tracking.xp{ xp = UnitXP("player"), max = UnitXPMax("player"), rested = GetXPExhaustion(), level = UnitLevel("player"), atMax = IsPlayerAtEffectiveMaxLevel(), disabled = IsXPUserDisabled and IsXPUserDisabled() }` (missing functions count as false / nil); reputation from `C_Reputation.GetWatchedFactionData()` when that exists, else `{ legacy = { GetWatchedFactionInfo() } }`. Bar: `SetMinMaxValues(0, max)` / `SetValue(value)` (reputation `min, max`); rested band `SetMinMaxValues(0, max)` / `SetValue(restedEnd)` shown only with a restedEnd; colors `Theme.trackingColors.xp`, rested at `restedAlpha`, reputation `Tracking.reactionColor(reaction)`, all through `Theme.barColor(rgb, barTexture)` and backgrounds at `barBgAlpha`. Which bars show = (`showXP` and xp ~= nil), (`showReputation` and rep ~= nil); a change in the row count re-runs apply.
  - **text:** `"Always"`: texts shown; `"Never"`: hidden; `"Hover"`: shown while the mouse is over the frame (OnEnter / OnLeave) or in Edit Mode. A nil text shows `""`.
  - **events:** `PLAYER_ENTERING_WORLD`, `PLAYER_XP_UPDATE` (player), `UPDATE_EXHAUSTION`, `PLAYER_LEVEL_UP`, `ENABLE_XP_GAIN`, `DISABLE_XP_GAIN`, `UPDATE_FACTION`, `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` (fading).
  - **fading:** `frame:SetAlpha(ns.UnitState.alpha{ editMode, inCombat, hover, outOfCombat, mouseover })`.
  - **Edit Mode** (`onEditMode`): open -> sample (XP 60% of 1000 with rested to 80%, text `"Level 42  600 / 1,000 (60%)  +200 rested"`; reputation `"Sample Faction  Friendly  3,000 / 6,000"` at 50%, reaction 5) with both rows and the frame shown; close -> real values and visibility.
  - Blizzard's bars hidden through `Base.hideBlizzard(spec.blizzard)` in create.
- Docs: README gets an "XP and reputation" paragraph (what shows when, text on mouse-over, moving it in Edit Mode, Blizzard's bars come back after /reload when it is off) and the Unit frames table stays. CHANGELOG one bullet. DEVELOPMENT: layout rows, module table row, a short "XP / Reputation bar" section (own bars, which APIs, secret handling). CHECKLIST: a "Plan 6: XP / reputation bar" section with one line per UNVERIFIED API plus: XP and rested band fill right, the bar goes at max level, watching a faction shows it at once, Blizzard's bars are gone, Edit Mode moves the frame and its panel works. BACKLOG: replace "XP / Reputation bar." with "XP / Reputation bar: honor, renown / friendship / paragon details, click to open the reputation pane, hide in pet battles." CLAUDE.md status: Plans 1-6 built; next: the suite's action bar addon (or raid frames, BACKLOG).

- [ ] **Step 1: Write the failing tests** in `tests/test_tracking.lua` (Core.init through the `.toc` like `tests/test_units.lua`; install `UnitXP`, `UnitXPMax`, `GetXPExhaustion`, `UnitLevel`, `IsPlayerAtEffectiveMaxLevel`, `IsXPUserDisabled`, `C_Reputation`, `GetWatchedFactionInfo` with `fakes.withGlobals`):
  - `"the tracking module registers with Edit Mode and the checklist"`: module `tracking` exists, kind `"bar"`, its frame `AnotherHUDTrackingBar` registered with the fake LibEditMode, listed in the checklist.
  - `"XP and reputation stack with XP on top"`: both show: frame height `2 * 10 + 1 + 2 * edge`; XP bar value 12345 of 50000; rested band value 15345; reputation range 3000..9000 value 4200; divider shown.
  - `"reaching max level drops the XP bar"`: `IsPlayerAtEffectiveMaxLevel` true + `PLAYER_LEVEL_UP` -> one row, reputation on top, divider hidden.
  - `"no bar to show hides the frame"`: max level and no watched faction -> frame hidden; Edit Mode open -> shown with both sample rows; close -> hidden again.
  - `"watching a faction shows the reputation bar at once"`: no faction, then data + `UPDATE_FACTION` -> reputation row shown.
  - `"secret XP fills the bar without text"`: `UnitXP` returns `fakes.secret()` -> bar value is the secret, text `""`, rested band hidden, no error.
  - `"text follows the Text option"`: `"Hover"` -> text hidden until OnEnter, hidden after OnLeave; `"Always"` -> shown; `"Never"` -> hidden on hover.
  - `"Show XP off leaves only reputation"`.
  - `"legacy reputation API works when C_Reputation is missing"`.
  - `"turned off, the frame hides"`: `Modules.setEnabled("tracking", false)` + apply -> hidden.
  - `"Blizzard's status tracking bars are hidden"`: the three fake frames are reparented / hidden (as `tests/test_units.lua` checks for PlayerFrame).
- [ ] **Step 2: Run** `lua tests/run.lua`. Expected: new tests FAIL.
- [ ] **Step 3: Implement** `Bars/Tracking.lua`, `.toc` line, `.luacheckrc`, deDE texts (labels, tooltips, "XP / Reputation" = "EP / Ruf", the dropdown values "Hover" = "Bei Mauszeiger", "Always" = "Immer", "Never" = "Nie", standings "Hated" = "Hasserfüllt", "Hostile" = "Feindselig", "Unfriendly" = "Unfreundlich", "Neutral" = "Neutral", "Friendly" = "Freundlich", "Honored" = "Wohlwollend", "Revered" = "Respektvoll", "Exalted" = "Ehrfürchtig", "Level" = "Stufe", "rested" = "erholt", "Sample Faction" = "Beispielfraktion"), the count updates in other tests.
- [ ] **Step 4: Run** tests and luacheck. Expected: pass, 0 warnings.
- [ ] **Step 5: Update the docs** listed above (README free of API names, texture paths and pixel sizes).
- [ ] **Step 6: Commit** `feat: XP / Reputation bar` and `docs: XP / Reputation bar` (or one commit).
