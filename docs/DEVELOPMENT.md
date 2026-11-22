# AnotherHUD development

Status: Plan 1 is built: the core (saved state, options, module registry,
combat queue, theme, texts), the Edit Mode glue (frames, settings panels,
snapping, positions per layout, checklist toggles) and the Edit Mode spike
(one Action Bar 1 setting; its test frame is gone). Plan 3 adds the Player,
Target, Target of Target, Focus and Pet frames; party, boss and the bars
are not built yet, their rows below are the plan. The design and its reasons are in
`docs/superpowers/specs/2026-11-21-anotherhud-design.md`.

## Setup

- Repo: https://gitlab.com/mhhenjes/anotherhud (`main`, changes through merge
  requests once the branch is protected).
- Client: WoW Forever, `C:\Program Files (x86)\World of Warcraft\_forever_\`.
  For testing in game, link the addon folder into `Interface\AddOns`:
  `New-Item -ItemType Junction -Path "<WoW>\_forever_\Interface\AddOns\AnotherHUD" -Target "D:\GitRepos\AnotherHUD\AnotherHUD"`.
- `Libs/` is fetched by the packager (`.pkgmeta` externals). For a local copy
  with Edit Mode, run the packager dry run once or copy LibStub,
  CallbackHandler-1.0 and LibEditMode into `AnotherHUD/Libs/` (git-ignored).
- Tools: Lua 5.4 (local), luacheck, glab.

**Spike check (Edit Mode, Plan 1 Task 7).** Run once by the player, in
PowerShell; nothing here is done by the build.

1. Close the game. Link the addon (WoW folder as above):
   `New-Item -ItemType Junction -Path "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\AnotherHUD" -Target "D:\GitRepos\AnotherHUD\AnotherHUD"`
   (if the folder exists from an installed release, move it away first).
2. Libraries: create `D:\GitRepos\AnotherHUD\AnotherHUD\Libs\` and put in it
   `LibStub\LibStub.lua`, `CallbackHandler-1.0\` (with
   `CallbackHandler-1.0.xml`) and `LibEditMode\` (with `embed.xml`), the
   paths `embeds.xml` loads. Easiest source: the artifact of the CI
   `package-dry-run` job (its zip holds `AnotherHUD/Libs/...`; copy that
   `Libs` folder over). Or copy https://github.com/p3lim-wow/LibEditMode
   (the whole repo; `embed.xml` sits at its root, checked against upstream)
   into `AnotherHUD\Libs\LibEditMode\`, plus LibStub and CallbackHandler-1.0
   from their own releases. Never from FlareUI (its copy is modified).
3. Start the game, enable AnotherHUD in the AddOns list, log in. First check
   the library loaded: `/dump LibStub and LibStub("LibEditMode", true) ~= nil`
   must print `true` (else the files are not where `embeds.xml` looks; fix
   step 2 before going on). Then `/console taintLog 1` and `/reload` once
   so logging starts clean.
4. Run the "Edit Mode spike" checks in `docs/CHECKLIST.md`. The taint log is
   `C:\Program Files (x86)\World of Warcraft\_forever_\Logs\taint.log` (written on logout / `/reload`): search it
   for `AnotherHUD`.
5. Write the results under "Results" in `docs/CHECKLIST.md`. If the checklist
   or the Action Bar setting taints, the fallback from the design applies:
   action bar look goes into our own panel (opened from the Settings window),
   module toggles live only in the Settings window; note it here and in
   Plan 5's notes.
6. `/console taintLog 0` when done.

## Code layout

| Folder / file | What it holds |
| --- | --- |
| `AnotherHUD.toc` | load order |
| `embeds.xml` | LibStub, CallbackHandler, LibEditMode |
| `Core/Util.lua`, `Core/Locale.lua`, `Locales/deDE.lua` | helpers, texts |
| `Core/Theme.lua` | colors, fonts, sizes, textures, skins (from AnotherLedger) |
| `Core/DB.lua`, `Core/Options.lua`, `Core/Profiles.lua` | saved state, settings, profiles |
| `Core/Modules.lua` | module registry |
| `Core/Combat.lua` | combat-lockdown queue |
| `Core/UnitText.lua`, `Core/UnitColor.lua`, `Core/UnitState.lua` | pure unit frame rules: bar / level texts, health / ring / power / cast colors, fading, visibility conditions |
| `Core/UnitLayout.lua` | pure unit frame geometry from the approved mockups: ring, bars, badge, studs, aura rows |
| `Core/GroupLayout.lua` | pure group rules: member order, block offsets, holder visibility conditions |
| `Core/Core.lua` | `Core.init`: saved state, then Edit Mode registration |
| `EditMode/Glue.lua` | registers modules with LibEditMode, positions per layout |
| `EditMode/Panel.lua` | builds a module's settings sections for the Edit Mode panel |
| `EditMode/Snap.lua` | snapping to grid, screen and frames |
| `EditMode/Checklist.lua` | module toggles in the Edit Mode window |
| `EditMode/SystemSettings.lua` | spike: one checkbox in Action Bar 1's Edit Mode panel (still writes `profile.spike.abLook` until Plan 5 replaces it) |
| `Units/Settings.lua` | shared settings sections (`Settings.build(parts, defaults)`) the unit modules pick from |
| `Units/Parts/Panel.lua`, `Units/Parts/Ring.lua`, `Units/Parts/Bars.lua` | drawn unit frame parts: panel fill and skin border, portrait ring with studs and level badge, health / power bars with divider and texts (`create(parent)`, `part:layout(L, opts)`) |
| `Units/Parts/CastBar.lua` | unit cast bar: icon, panel, client-timed `StatusBar`, spark, name / time (client duration binding), shield and grey overlay from `notInterruptible`, interrupted hold; `create(parent, unit)`, `cast:update(event, ...)` for `CastBar.EVENTS`, `cast:layout(opts)`, `cast:sample(on)` |
| `Units/Parts/Auras.lua` | unit aura rows: two client `AuraContainer`s (`CustomAuraContainerTemplate`), debuffs and buffs under them, each in a clip frame sized to its rows, mine first then others (desaturated, off with Only Mine), styled buttons; own placeholder icons in Edit Mode (also without the template); `available` false without the template; `create(parent, unit, mode)` (mode `"line"` for group frames: one container, debuffs then my buffs only, one line), `auras:layout(opts)`, `auras:sample(on)` |
| `Units/Parts/Role.lua` | group frames: role badge (disc stack in the skin's line shades, panel fill, glyph at 72%) at the ring's lower left and the leader crown above the ring; a secret role or leader flag hides them; `create(parent)`, `role:layout(L, opts)`, `role:setRole(r)`, `role:setLeader(b)`, `role:setUnit(unit)` |
| `Units/Parts/Dispel.lua` | group frames: dispellable-debuff glow, a 9-slice texture reaching `glow` px outside the frame; live one is an `AuraContainer` slot (raid dispel filter) whose button carries the glow texture tinted by `AddDispelTypeTexture`; `available` false without the template; `create(parent, unit)`, `dispel:layout()`, `dispel:sample(colorOrNil)` |
| `Units/Base.lua` | unit frame base: `SecureUnitButtonTemplate` button with the parts, unit events, Edit Mode sample, fading, hiding Blizzard frames (`Base.create(spec, o)`, `Base.apply(spec)`, `Base.update(frame)`, `Base.editMode(spec, active)`, `Base.anchorCast(frame, holder)`, `Base.hideBlizzard(names)`) |
| `Units/Define.lua` | `ns.Units.define(o)`: the shared unit module shape (settings from `Units/Settings.lua`, create / apply / onEditMode through `Units/Base.lua`) |
| `Units/Player.lua`, `Units/Target.lua`, `Units/TargetTarget.lua`, `Units/Focus.lua`, `Units/Pet.lua` | one unit module each (`ns.Units.define{...}`) |
| `Units/PlayerCastBar.lua` | `playercast`: the detached player cast bar's holder (child of `player`) |
| `Units/Party.lua`, `Units/Boss.lua` | planned |
| `Bars/ActionSkin.lua` | look for Blizzard action buttons |
| `Bars/ActionBars.lua`, `Bars/Stance.lua`, `Bars/Pet.lua` | bar modules |
| `Bars/CastBar.lua`, `Bars/Tracking.lua` | player cast bar, XP / reputation |
| `UI/Fonts.lua`, `UI/Widgets.lua`, `UI/Settings.lua` | widgets and the Settings window |
| `Media/Skins/*.tga` | skin textures (Stud, Dotted; from AnotherLedger) |
| `Media/Units/*.tga` | unit frame art (Disc, BarSmooth, BarGloss, Spark, Shield); generated, see below |
| `Boot.lua` | last: `Core.init` on `ADDON_LOADED` |

`tools/render_units.py` (repo root, not packaged) draws the `Media/Units`
textures: `python tools/render_units.py` (plain Python 3, no libraries)
rewrites the TGA files; commit them. The bar gradients are grey and
normalized to their brightest stop; `Theme.barColor` multiplies the bar color
by `Theme.barTextures[name].tint` to compensate.

## Extending: modules

```lua
ns.Modules.define{
  id = "player", label = "Player", kind = "unit",
  defaults = { width = 200, height = 60, portraitScale = 100, powerHeight = 15 },
  settings = {               -- sections, drawn by Edit Mode panel and Settings window
    { section = "Size", controls = {
      { key = "width",  type = "slider", label = "Width", min = 80, max = 400, step = 1 },
      ...
    }},
  },
  blizzard = { "PlayerFrame" },   -- hidden while the module is on
  create = function(mod) ... end, -- once, out of combat
  apply  = function(mod, key, value) ... end, -- redraw from settings (queued in combat)
  parent = "player",              -- optional: a child module (see below)
  onEditMode = function(mod, active) ... end, -- optional: Edit Mode opened / closed
}
```

Labels and section names are English keys, not `L[...]`: they are
translated where they are drawn (`EditMode/Panel.lua`,
`EditMode/Checklist.lua`, `EditMode/Glue.lua`). Add the German text to
`Locales/deDE.lua`.

`apply(spec, key, value)`: `key` / `value` say what changed and are
informational only; `apply` must redraw the whole module from its settings,
because the combat queue keeps only the last call per module (earlier
changes made in combat arrive folded into that one call).

`parent`: a child module (e.g. the detached Player cast bar's holder).
`Modules.isEnabled(child)` is false while the parent is off (an unknown
parent id counts as enabled); the Edit Mode checklist does not list
children. `onEditMode(spec, active)`: `EditMode/Glue.lua` calls it for every
registered module when LibEditMode fires `"enter"` (true) / `"exit"` (false)
and once right after a module registers while Edit Mode is open; errors are
reported through the error handler so one module cannot stop the others.
`Glue.inEditMode()` gives the tracked state (false without the library).

A new replaced frame is a new file with one `Modules.define` and a `.toc`
line; nothing else names it.

## How things work

**Edit Mode.** `Boot.lua` calls `Core.init` on the addon's `ADDON_LOADED`:
`DB.init` on the saved variables, then `EditMode/Glue.registerAll`. For every
enabled module it creates the frame if needed (`spec.create`, queued with
`Combat.after("create:" .. id)`), then hands it to LibEditMode: `AddFrame`
with our move callback and `spec.defaultPosition`, `AddFrameSettings` with
the rows `EditMode/Panel.build` makes from `spec.settings` (one Divider row
per section, a disabled line when the library has no Divider type; every
setter goes through `Options.set`), and one Settings button (the library's
dialog brings its own Reset Settings, which calls every row's setter with
its default, and Reset Position, which calls our move callback with the
default position). Positions live in
`db.positions[layoutName][id] = { point, x, y }`; the library's `layout`
callback places every frame for the new layout, or at its default position
when that layout has none saved; on `rename` the layout's positions (and
`db.lastLayout`) move to the new name, on `delete` they are dropped. The
move callback snaps our own frames (`EditMode/Snap.lua`,
`Theme.sizes.snapDistance` px, to the screen edges and centre lines and to
the other AnotherHUD frames; no grid snap yet, see `docs/CHECKLIST.md`) and
saves; the default position (the library's own Reset Position) and an
arrow-key nudge (at most 10 px on one axis, none on the other, against the
saved position) are saved unsnapped, so a nudge can leave a snap line.
Every reposition goes through `Combat.after("pos:" .. id)` and
anchors to the frame's parent (as the library does).
Without LibEditMode the frames go to their positions in the last layout
seen (`db.lastLayout`) or their defaults, and nothing else happens.

With LibEditMode, `Core.init` then attaches two spike pieces (taint test,
results in `docs/CHECKLIST.md`). `EditMode/Checklist.lua` hooks
`EditModeManagerFrame` with `HookScript("OnShow")` and `HookScript("OnHide")`
(no writes into Blizzard tables or frames); on the first show it builds a
small box on `UIParent`, anchored under the window, with one checkbox per
module (`Checklist.entries()`: define order, `Modules.isEnabled`); the box
shows (re-reading the checks) and hides with the window. A click runs
`Checklist.toggle`: `Modules.setEnabled`, then the module's `apply` (which
must honor `Modules.isEnabled`; a module without `apply` is shown / hidden
with `Combat.after("show:" .. id)`) or, for a module that was off at login,
`Glue.registerAll` creates it and prints "Reopen Edit Mode to move it" (the
library makes it selectable from the next open); a module that hides
Blizzard frames prints a `/reload` hint.
`EditMode/SystemSettings.lua` adds one checkbox, "AnotherHUD look", to Action
Bar 1's panel (`AddSystemSettings(Enum.EditModeSystem.ActionBar, ...,
Enum.EditModeActionBarSystemIndices.MainBar)`); its value is
`profile.spike.abLook` and only prints a line; it keeps doing so until
Plan 5 turns it into the real bar look or removes it. The spike's test frame
(`Spike/`) is gone: the unit frames replaced it.

**Unit frames.** A unit module's `create` calls `Units/Base.create(spec, o)`
(`o = { unit, name, mirror, castBar, auras, badge }`): a
`SecureUnitButtonTemplate` button on `UIParent` (`unit`, `*type1 = "target"`,
`*type2 = "togglemenu"`, `RegisterForClicks("AnyUp")`, queued with
`Combat.after`) holding the parts as children (Panel, Ring, Bars, and
`frame.cast` / `frame.auras` when asked for, else `false`). Every field Base
keeps on the frame is set at create (`false` for "none"). Events: the unit
events with `RegisterUnitEvent`, the cast events (to `cast:update`), the
unit's change event (`PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`,
`UNIT_TARGET` of `target`, `UNIT_PET` of `player`), `PLAYER_ENTERING_WORLD`,
and `PLAYER_REGEN_DISABLED` / `_ENABLED` for fading. `targettarget` gets no
unit events: it refreshes every 0.2 s from `OnUpdate` while shown (values
only while `UnitGUID` stays the same; a new or secret GUID and
`UNIT_TARGET` / `PLAYER_TARGET_CHANGED` update everything). Every unit
frame also runs a full `Base.update` from `HookScript("OnShow")`. Health /
power events update only values and texts; the others (and the change
events) also colors, portrait and level. `Base.update` passes every client
value through untouched (`UnitHealthPercent` / `UnitPowerPercent` with
`CurveConstants.ScaleTo100` for the percent texts; without that API the
text mode falls back, "Percent" to "None" and "Value + Percent" to
"Value"); only the dead /
connected flags, the power token, reaction and classification are read, and
only when plain. `Base.apply(spec)` reads the options and, in one
`Combat.after("unit:" .. id)`, sizes the frame, lays out the parts
(`UnitLayout.frame`), places the cast bar `L.below` px under the frame
(left-aligned, mirrored right-aligned; `Base.anchorCast(frame, holder)` moves
it onto a detached holder) and the auras under it (`auraBelowCast` between)
or `L.below` under the frame, and sets the state driver
(`UnitState.visibility`). The opacity (`UnitState.alpha`) is set right away:
`SetAlpha` is not protected. In Edit Mode (`Base.editMode`, a module's
`onEditMode`) the driver goes, the frame shows a plain sample (health 72%,
power 55%, the unit's label or the player's name, the cast bar and aura
samples) at full opacity; on close the driver comes back and `Base.update`
runs (and a running cast is picked up). A module turned off
(`Modules.isEnabled` false) makes `Base.apply` and `Base.editMode` only
drop the sample, unregister the driver and hide the frame (queued under
`unit:<id>` and `unit:<id>:edit`); turned on again while Edit Mode is
open, `Base.apply` starts the sample. The detached cast bar holder is off
while the Player is off. `Base.hideBlizzard(names)` hides
each Blizzard frame once it exists, out of combat: `UnregisterAllEvents` on
it and its child bars (`healthbar`, `manabar`, `spellbar`, `totFrame`,
`powerBarAlt`), reparent to one hidden frame of ours (made on first use),
a `hooksecurefunc(frame, "Show", ...)` that hides it again (a protected
frame in combat: queued), and a `SetParent` hook that parks it again
(queued in combat). A name whose frame is missing is tried again by the
next call.

**Unit modules.** Each unit file is one `ns.Units.define{...}`
(`Units/Define.lua`): id, label, unit, global frame name, `mirror`,
`castBar`, `auras`, `badge`, `parts` (the `Units.Settings.build` sections and
flags), `defaults` (overrides), `blizzard`, `defaultPosition`, optional
`apply`. It calls `ns.Modules.define{ kind = "unit" }` with `create` =
`Base.create` + apply + `Base.hideBlizzard`, `apply` = `Base.apply`,
`onEditMode` = `Base.editMode`.

| id | frame | unit | sections | overrides | hides |
| --- | --- | --- | --- | --- | --- |
| `player` | `AnotherHUDPlayerFrame` | player, badge 18 | Size (portrait, power), Text, Look, Behaviour, Cast Bar (detach), Auras, Fading | none | `PlayerFrame`, `PlayerCastingBarFrame` |
| `playercast` | `AnotherHUDPlayerCastBarHolder` | (holder, child of `player`) | none | none | none |
| `target` | `AnotherHUDTargetFrame` | target, mirrored, badge 18 | as Player, Cast Bar without detach | health Percent, power None | `TargetFrame` |
| `targettarget` | `AnotherHUDTargetTargetFrame` | targettarget, mirrored | Size (portrait), Text, Look, Fading | 120 x 26, 10 pt, health None | none (inside `TargetFrame`) |
| `focus` | `AnotherHUDFocusFrame` | focus, badge 14 | as Target | 160 x 40, power 8, 10 pt, health Percent, power None | `FocusFrame` |
| `pet` | `AnotherHUDPetFrame` | pet | Size (portrait, power), Text, Look, Auras, Fading | 120 x 34, power 6, 10 pt, health Percent, power None | `PetFrame` |

`targettarget` has no `blizzard` list (nil, not `{}`), so turning it off
needs no `/reload`. The detached cast bar: `playercast` is a plain frame on
`UIParent`, sized to the Player's Cast bar width / height, placed by Edit
Mode like any module. With Show cast bar and Detach cast bar on,
`Base.anchorCast(playerFrame, holder)` parents the bar to it and the holder
is shown (empty outside Edit Mode, the bar is its only content); otherwise
the holder is hidden (Edit Mode can't select it) and the bar hangs under
the Player frame. The Player's `apply` re-runs `playercast`'s apply (or,
before the holder exists, anchors the bar under the frame); the holder's
own create applies the Player's state once it exists. Size and visibility
go through `Combat.after("unit:playercast")`, the move through
`Base.anchorCast`, so both change together after combat.

*(Filled in as built.)* Planned topics: secret values and how texts are formatted, party header attributes, sample data in Edit Mode, skinning
Blizzard action buttons.

## Secret values and taint

- Health, power and cast values may be secret in combat: no arithmetic,
  comparisons or string math on them; hand them to widgets.
- Type guards such as `Util.isNumber` compare what they check (NaN and
  infinity tests): never pass client health, power or cast values through them (they
  are for saved settings and positions only).
- Secure frames change only out of combat (`ns.Combat.after`).
- Never write into Blizzard tables; `hooksecurefunc` only.

## Saved state

- `AnotherHUDDB` (account): profiles (module settings, look), positions per
  Edit Mode layout.
- `AnotherHUDCharDB` (character): chosen profile.

## Events

*(Filled in as built.)*

## Tests

`lua tests/run.lua`: plain Lua with fake frames (harness from AnotherLedger).
Fake client values can be marked secret; touching them with arithmetic fails
the test.

## Localization

English (keys) and German (`Locales/deDE.lua`).

## Packaging

BigWigs packager from the repo root (`.pkgmeta`: `package-as: AnotherHUD`,
move-folders, externals for LibStub, CallbackHandler-1.0 and LibEditMode).
GitLab CI: test (Lua 5.1 + 5.4), lint, package on tags.
