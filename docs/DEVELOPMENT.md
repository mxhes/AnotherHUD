# AnotherHUD development

Status: Plan 1 is built: the core (saved state, options, module registry,
combat queue, theme, texts), the Edit Mode glue (frames, settings panels,
snapping, positions per layout, checklist toggles) and the Edit Mode spike
(test frame, one Action Bar 1 setting). Unit frames and bars are not built
yet; their rows below are the plan. The design and its reasons are in
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
| `Core/Core.lua` | `Core.init`: saved state, then Edit Mode registration |
| `EditMode/Glue.lua` | registers modules with LibEditMode, positions per layout |
| `EditMode/Panel.lua` | builds a module's settings sections for the Edit Mode panel |
| `EditMode/Snap.lua` | snapping to grid, screen and frames |
| `EditMode/Checklist.lua` | module toggles in the Edit Mode window |
| `EditMode/SystemSettings.lua` | spike: one checkbox in Action Bar 1's Edit Mode panel |
| `Spike/SpikeModule.lua` | spike: "AnotherHUD Test" frame; deleted when Plan 3's Player module lands |
| `Units/Base.lua` | shared unit frame parts (health, power, portrait, texts, cast bar, auras, icons) |
| `Units/Player.lua` ... `Units/Boss.lua` | one module per unit |
| `Bars/ActionSkin.lua` | look for Blizzard action buttons |
| `Bars/ActionBars.lua`, `Bars/Stance.lua`, `Bars/Pet.lua` | bar modules |
| `Bars/CastBar.lua`, `Bars/Tracking.lua` | player cast bar, XP / reputation |
| `UI/Fonts.lua`, `UI/Widgets.lua`, `UI/Settings.lua` | widgets and the Settings window |
| `Media/Skins/*.tga` | skin textures (Stud, Dotted; from AnotherLedger) |
| `Boot.lua` | last: `Core.init` on `ADDON_LOADED` |

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
`Checklist.toggle`: `Modules.setEnabled`, then shows / hides the frame
(`Combat.after("show:" .. id)`) or, for a module that was off at login,
`Glue.registerAll` creates it and prints "Reopen Edit Mode to move it" (the
library makes it selectable from the next open); a module that hides
Blizzard frames prints a `/reload` hint.
`EditMode/SystemSettings.lua` adds one checkbox, "AnotherHUD look", to Action
Bar 1's panel (`AddSystemSettings(Enum.EditModeSystem.ActionBar, ...,
Enum.EditModeActionBarSystemIndices.MainBar)`); its value is
`profile.spike.abLook` and only prints a line. The test frame itself is the
module `spike` in `Spike/SpikeModule.lua` (Size: width, height; Look: Show
border). To remove the spike: delete `Spike/` and its `.toc` line;
`EditMode/SystemSettings.lua` either becomes the real bar look or goes too.

*(Filled in as built.)* Planned topics: secret values and how texts are formatted, hiding
Blizzard frames, party header attributes, sample data in Edit Mode, skinning
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
