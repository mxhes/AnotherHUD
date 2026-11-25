# AnotherHUD Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A loadable, tested, packaged AnotherHUD skeleton with the module registry, settings, combat queue, Edit Mode glue and a client spike that answers the open taint questions.

**Architecture:** Same layout and tooling as AnotherLedger (plain-Lua tests with fake frames, luacheck, GitLab CI, BigWigs packager). Pure code in `Core/` and the pure halves of `EditMode/`; client code only inside functions. LibEditMode is an unmodified packager external.

**Tech Stack:** Lua 5.1 (WoW Forever, Interface 16001), LibStub, CallbackHandler-1.0, LibEditMode, luacheck, GitLab CI, BigWigs packager.

**Spec:** `docs/superpowers/specs/2026-11-21-anotherhud-design.md`

## Roadmap (all of release 1)

The spec is several subsystems; each gets its own plan, written when the one
before it has landed (the spike in this plan decides details of the later
ones). Mockups (Plan 2) can run in parallel with Plan 1.

| Plan | Delivers | Gate |
| --- | --- | --- |
| **1. Foundation** (this file) | repo, tooling, Core, module registry, Edit Mode glue, client spike | player runs the spike in the client |
| 2. Mockups | HTML mockups: Player frame (portrait ring), Party, Boss, action button border, proc glow, resource pips, totem bar | **player approves each mockup** |
| 3. Unit frames | `Units/Base.lua`, Player (with cast bar + Detach), Target, Target of Target, Focus, Pet; Size / Text / Look / Behaviour / Cast Bar / Auras / Fading sections; Blizzard frames hidden; secret-safe texts | client check |
| 4. Group frames | Party (header, orientation, growth, gap, sort by role, show player, sample data in Edit Mode), Boss 1-5 | client check |
| 5. Bars | action button skin, Action Bars 1-8, Stance, Pet Bar, proc glow, bar fading, XP / Reputation | client check |
| 6. Resource & totems | class resource bar, totem bar | client check |
| 7. Release 1 | Settings window, profiles UI, German texts, README, CHANGELOG, CurseForge project, tag v1.0.0 | player plays a week on the suite alone |

Approved art from Plan 2 is swapped into Plans 3-6 as it is approved; until
then they use AnotherLedger's look.

## Global Constraints

- `## Interface: 16001`; Lua 5.1 code (no `goto`, `//`, `table.unpack`); tests also run on 5.4.
- Addon folder `AnotherHUD/`; saved variables `AnotherHUDDB` (account) and `AnotherHUDCharDB` (character).
- Every file starts `local ADDON, ns = ...`; WoW globals only inside functions.
- Option labels at most 24 characters; texts through `ns.L`, German in `Locales/deDE.lua`.
- LibEditMode unmodified (packager external), no hooks into its internals.
- No arithmetic or comparison on client health / power / cast values.
- Nothing touches secure frames in combat (`ns.Combat.after`).
- No other addon's code or art copied. AnotherLedger code may be copied.
- Commits `feat:` / `fix:` / `docs:` / `refactor:`; remote `https://gitlab.com/mhhenjes/anotherhud`, branch `main`.

## Review Focus

1. **Entering or leaving Edit Mode in combat**: position and settings changes from the panel must queue, not error ("action blocked"). Test in Task 5.
2. **A new Edit Mode layout with no saved positions** (player creates "Layout 2"): every module falls back to its default position, nothing nil-indexes. Test in Task 6.
3. **LibEditMode missing** (dev copy without `Libs/`): the addon loads, frames sit at defaults, no Lua error. Test in Task 6.
4. **A secret value reaching pure code**: any arithmetic in a formatter throws in tests. Test helper in Task 4, used from Plan 3 on.
5. **German labels longer than 24 characters** in a module's settings. Test in Task 3.

---

### Task 1: Repo scaffold and tooling

**Files:**
- Create: `.gitignore`, `.pkgmeta`, `.gitlab-ci.yml`, `.luacheckrc`, `CHANGELOG.md`, `docs/CHECKLIST.md`, `docs/BACKLOG.md`
- Create: `AnotherHUD/AnotherHUD.toc`, `AnotherHUD/embeds.xml`, `AnotherHUD/Boot.lua`
- Create: `tests/harness.lua`, `tests/run.lua`, `tests/test_toc.lua`
- Modify: `README.md` (short player intro, "in development")

**Interfaces:**
- Produces: `h.load(files)` loading paths under `AnotherHUD/` (copy of AnotherLedger's harness with the folder renamed); `h.toc()` returning the `.toc` file list in order.

- [ ] **Step 1:** Copy `tests/harness.lua` and `tests/run.lua` from `D:\GitRepos\LootLedger`, replace `AnotherLedger` with `AnotherHUD`; add `h.toc()` (reads `AnotherHUD/AnotherHUD.toc`, skips `##` lines, blanks and `.xml`, returns paths with `/`).
- [ ] **Step 2: Write the failing test** `tests/test_toc.lua`: `"every .toc file exists"` (each `h.toc()` path opens) and `"Boot.lua is last"`.
- [ ] **Step 3:** Run `lua tests/run.lua` — expected FAIL (no `.toc`).
- [ ] **Step 4:** Create the `.toc` (`## Interface: 16001`, `## Title: AnotherHUD`, `## Version: @project-version@`, `## Author: Maximilian Henjes`, `## X-Website: https://gitlab.com/mhhenjes/anotherhud`, `## SavedVariables: AnotherHUDDB`, `## SavedVariablesPerCharacter: AnotherHUDCharDB`, `## OptionalDeps: LibStub, CallbackHandler-1.0, LibEditMode`, then `embeds.xml`, `Boot.lua`), `embeds.xml` (loads `Libs\LibStub\LibStub.lua`, `Libs\CallbackHandler-1.0\CallbackHandler-1.0.xml`, `Libs\LibEditMode\embed.xml`; missing files are skipped by the client), `Boot.lua` (`local ADDON, ns = ...` only for now).
- [ ] **Step 5:** `.pkgmeta`, `.gitlab-ci.yml`, `.luacheckrc`, `.gitignore` adapted from AnotherLedger (`package-as: AnotherHUD`, move-folders `AnotherHUD/AnotherHUD: AnotherHUD`, externals LibStub, CallbackHandler-1.0 and `AnotherHUD/Libs/LibEditMode: https://github.com/p3lim-wow/LibEditMode`; luacheck excludes `AnotherHUD/Libs/`, globals `AnotherHUDDB`, `AnotherHUDCharDB`). `CHECKLIST.md` with "Open checks" (empty) and release steps copied from AnotherLedger; `BACKLOG.md` with: raid frames, Party Style, Pets & Targets, shared "Another" suite core.
- [ ] **Step 6:** Run `lua tests/run.lua` — expected PASS; `luacheck AnotherHUD` — 0 warnings (if luacheck is missing locally, CI runs it).
- [ ] **Step 7: Commit** `feat: repo scaffold, tests, CI and packaging`, push a branch, open an MR; CI `test` and `lint` green; run the manual `package-dry-run` job once and check the zip holds one `AnotherHUD/` folder with the `.toc` and `Libs/LibEditMode`.

### Task 2: Core basics (Util, Locale, Theme, DB)

**Files:**
- Create: `AnotherHUD/Core/Util.lua`, `Core/Locale.lua`, `Locales/deDE.lua`, `Core/Theme.lua`, `Core/DB.lua`
- Modify: `AnotherHUD.toc` (in this order, before `Boot.lua`)
- Test: `tests/test_db.lua`, `tests/test_theme.lua`

**Interfaces:**
- Produces: `ns.Util.copy(t)`, `ns.Util.merge(dst, defaults)` (fills missing keys deeply, never overwrites); `ns.L` (English key fallback); `ns.Theme` (AnotherLedger's `colors`, `fonts`, `sizes`, `textures`, skins Classic / Forge / Slate / Gilded); `ns.DB.init(saved, charSaved) -> db, chardb`; `db.profiles[name] = { modules = {} }`, `db.positions[layoutName][moduleId] = { point, x, y }`, `chardb.profile = "Default"`; `ns.DB.profile() -> table`.

- [ ] **Step 1: Write failing tests:** `"init creates Default profile"` (`DB.init(nil, nil)` → `chardb.profile == "Default"`, `db.profiles.Default.modules` is a table); `"init keeps existing values"` (saved `profiles.Default.modules.player.width = 250` survives); `"theme has all four skins"` (`Theme.skins` has keys `classic`, `forge`, `slate`, `gilded`).
- [ ] **Step 2:** Run — FAIL.
- [ ] **Step 3:** Port `Util`, `Locale`, `Theme` from AnotherLedger (drop ledger-only entries: coins, row and tab sizes; keep colors, fonts, skin parts, textures under `Interface\AddOns\AnotherHUD\Media\`, copying `Media/Skins/*.tga`). Write `DB.init` / `DB.profile`.
- [ ] **Step 4:** Run tests and luacheck — PASS.
- [ ] **Step 5: Commit** `feat: core util, locale, theme and saved state`.

### Task 3: Module registry and options

**Files:**
- Create: `AnotherHUD/Core/Modules.lua`, `Core/Options.lua`
- Test: `tests/test_modules.lua`, `tests/test_options.lua`

**Interfaces:**
- Consumes: `ns.DB.profile()`, `ns.Util.merge`.
- Produces:
  - `ns.Modules.define(spec)` — `spec = { id, label, kind = "unit"|"bar"|"misc", defaults, settings, blizzard, create, apply, defaultPosition = { point, x, y } }`; errors on duplicate `id`, missing `id`/`label`, unknown `kind`.
  - `ns.Modules.list() -> { spec, ... }` in define order; `ns.Modules.get(id)`.
  - `ns.Modules.isEnabled(id) -> bool` (profile `modules[id].enabled`, default `true`); `ns.Modules.setEnabled(id, on) -> needsReload` (true when the module has a `blizzard` list and its frame was already created this session; the caller then offers `/reload`).
  - `settings` format: `{ { section = "Size", controls = { { key, type = "slider"|"dropdown"|"checkbox"|"color", label, tooltip, min, max, step, values } } } }`.
  - `ns.Options.get(id, key)` (profile value, else module default); `ns.Options.set(id, key, value)` (clamps sliders to min/max/step, rejects unknown dropdown values, then calls `spec.apply` through `ns.Combat.after` if defined — `Combat` arrives in Task 5; until then call directly).

- [ ] **Step 1: Write failing tests:** `"define rejects duplicate id"`; `"get falls back to default"`; `"set clamps slider"` (`min 80, max 400, step 1`, set 500 → 400; set 99.6 → 100); `"set rejects unknown dropdown value"`; `"set calls apply"`; `"labels fit 24 glyphs in en and de"` (for every module and every control, `L[label]` and German `deDE[label]` ≤ 24 UTF-8 glyphs — Review Focus 5).
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement. **Step 4:** Run — PASS.
- [ ] **Step 5: Commit** `feat: module registry and options`.

### Task 4: Test fakes for the client, incl. secret values

**Files:**
- Create: `tests/fakes.lua`
- Test: `tests/test_fakes.lua`

**Interfaces:**
- Produces: `fakes.frame(name)` (AnotherLedger's fake-frame rule: any unset field is a no-op function; records `SetPoint`, `Show`, `Hide`, `SetParent` calls in `frame.calls`); `fakes.client{ inCombat = bool }` installs globals `CreateFrame`, `UIParent`, `InCombatLockdown`, `hooksecurefunc`, `C_Timer` into `_G` and returns a handle with `fire(event, ...)` and `setCombat(bool)`; `fakes.secret(n)` returns a value whose metatable errors on `__add __sub __mul __div __mod __unm __lt __le __eq __concat`, and which `StatusBar:SetValue` / `FontString:SetText` fakes accept.

- [ ] **Step 1: Write failing tests:** `"secret value throws on arithmetic"` (`pcall(function() return fakes.secret(5) + 1 end)` is false); `"secret value throws on compare"`; `"fake statusbar accepts secret"`; `"fire reaches registered handlers"`.
- [ ] **Step 2–4:** Run FAIL, implement (reuse fake frames from AnotherLedger's `tests/test_wiring.lua`), run PASS.
- [ ] **Step 5: Commit** `test: client fakes with secret values`.

### Task 5: Combat queue

**Files:**
- Create: `AnotherHUD/Core/Combat.lua`
- Modify: `Core/Options.lua` (`set` goes through `Combat.after`), `.toc`
- Test: `tests/test_combat.lua`

**Interfaces:**
- Produces: `ns.Combat.after(key, fn)` — runs `fn()` now when `InCombatLockdown()` is false, else stores it under `key` (a later call with the same key replaces the earlier one) and runs all stored functions in insertion order on `PLAYER_REGEN_ENABLED`; `ns.Combat.pending() -> count`.

- [ ] **Step 1: Write failing tests:** `"runs now out of combat"`; `"queues in combat and flushes on regen"`; `"same key keeps only the last"`; `"options set in combat applies after combat"` (Review Focus 1).
- [ ] **Step 2–4:** FAIL, implement, PASS.
- [ ] **Step 5: Commit** `feat: combat lockdown queue`.

### Task 6: Edit Mode glue and snapping

**Files:**
- Create: `AnotherHUD/EditMode/Panel.lua` (pure), `EditMode/Snap.lua` (pure), `EditMode/Glue.lua`
- Create: `AnotherHUD/Core/Core.lua` (`Core.init`: DB, then `Glue.registerAll`), wire `Boot.lua` to call it on `ADDON_LOADED`
- Test: `tests/test_panel.lua`, `tests/test_snap.lua`, `tests/test_glue.lua`

**Interfaces:**
- Consumes: `ns.Modules.list/get`, `ns.Options.get/set`, `ns.Combat.after`, `ns.DB`.
- Produces:
  - `ns.EditMode.Panel.build(spec, lemTypes) -> settings[]`: converts a module's `settings` into LibEditMode setting tables (`{ name, kind = lemTypes.Slider|Dropdown|Checkbox|ColorPicker, default, get = function(layoutName), set = function(layoutName, value), minValue, maxValue, valueStep, values }`), one Divider/header per section (use the library's divider/expander type if `lemTypes` has one, else a disabled header line).
  - `ns.EditMode.Snap.snap(rect, targets, opts) -> x, y`: `rect = { x, y, w, h }` (bottom-left, UIParent units), `targets = { rect, ... }` (screen edges included by caller), `opts = { grid = number|nil, threshold = 8 }`; snaps each edge to the nearest target edge or centre line within `threshold`, else to the grid when `grid` is set, else unchanged.
  - `ns.EditMode.Glue.registerAll()`: for each enabled module with a frame, `LEM:AddFrame(frame, onMove, spec.defaultPosition, spec.label)`, `LEM:AddFrameSettings(frame, Panel.build(...))`, `LEM:AddFrameSettingsButtons(frame, { Settings, Reset Settings, Reset To Default Position })` (Settings calls `ns.UI.Settings.open(id)` when it exists — Plan 7 — else prints "Settings window comes later"; Reset Settings clears the profile's `modules[id]` except `enabled`; Reset To Default Position clears `db.positions[layout][id]`); `onMove(frame, layoutName, point, x, y)` snaps (our frames only) and saves to `db.positions[layoutName][id]`; `LEM:RegisterCallback("layout", fn)` re-applies positions for the new layout, falling back to `defaultPosition` when none saved (Review Focus 2). Positioning goes through `Combat.after("pos:" .. id, ...)`. If `LibStub("LibEditMode", true)` is nil: place frames at saved / default positions and return (Review Focus 3).

- [ ] **Step 1: Write failing tests:** Panel — `"slider maps min/max/step"`, `"one header per section"`, `"set writes through Options.set"`. Snap — `"snaps left edge to target within 8"`, `"no snap beyond threshold"`, `"grid snap when no target near"`, `"centre line snap"`. Glue (with `fakes.client` and a fake LEM recording calls) — `"registers every enabled module"`, `"skips disabled modules"`, `"onMove saves per layout"`, `"new layout uses default position"`, `"works without LibEditMode"`.
- [ ] **Step 2–4:** FAIL, implement, PASS; luacheck clean (add `LibStub` to `read_globals`).
- [ ] **Step 5: Commit** `feat: Edit Mode glue, settings panels and snapping`.

### Task 7: Client spike (taint questions)

**Files:**
- Create: `AnotherHUD/Spike/SpikeModule.lua` (a plain 200x60 test frame module "AnotherHUD Test", sections Size + Look with 3 controls), `EditMode/Checklist.lua`, `EditMode/SystemSettings.lua`
- Modify: `.toc`, `docs/CHECKLIST.md`, `docs/DEVELOPMENT.md` ("How things work: Edit Mode")
- Test: `tests/test_checklist.lua` (pure part)

**Interfaces:**
- Produces: `ns.EditMode.Checklist.entries() -> { { id, label, checked } }` (pure, from `Modules`); `Checklist.attach()` (client: adds checkboxes under `EditModeManagerFrame`'s list, UNVERIFIED); `ns.EditMode.SystemSettings.attach()` (client: `LEM:AddSystemSettings(Enum.EditModeSystem.ActionBar, {one checkbox "AnotherHUD look"}, Enum.EditModeActionBarSystemIndices.MainBar)`, UNVERIFIED).

- [ ] **Step 1:** Test `"entries follow module order and enabled state"`; FAIL; implement; PASS.
- [ ] **Step 2:** Write the client part; mark every client call `UNVERIFIED (check in client)`; add CHECKLIST lines:
  - Test frame shows in Edit Mode, drags, snaps to grid / screen / Blizzard frames, panel opens next to it with the sections and the three buttons; positions differ per layout.
  - Checklist checkbox appears under Blizzard's list and toggles the test frame.
  - "AnotherHUD look" checkbox appears in Action Bar 1's Edit Mode panel.
  - **Taint:** after opening Edit Mode, changing both, saving and leaving: `/reload`-free combat on a target dummy, cast from Action Bar 1, open the spellbook and talents in combat — no "Interface action failed" / blocked message; `/console taintLog 1` log shows no AnotherHUD lines.
- [ ] **Step 3:** Link the addon into the client (`docs/DEVELOPMENT.md` Setup), install libs, and **ask the player to run the checks**. Record results in `CHECKLIST.md`; if checklist or system settings taint, write the fallback (spec: own panel / Settings window only) into `docs/DEVELOPMENT.md` and Plan 5's notes.
- [ ] **Step 4: Commit** `feat: Edit Mode spike (test frame, checklist, action bar setting)`, merge the MR after CI is green.

## After this plan

Write Plan 3 (unit frames) from the spike results; Plan 2 mockups may
already be underway. The spike module stays until Plan 3's Player module
replaces it, then `Spike/` is deleted.
