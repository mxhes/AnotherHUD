# AnotherHUD development

Status: **planned architecture**. Nothing here is built yet; sections are
filled in as the code lands. The design and its reasons are in
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
| `Core/Core.lua` | `Core.init`: saved state, then Edit Mode registration |
| `EditMode/Glue.lua` | registers modules with LibEditMode, positions per layout |
| `EditMode/Panel.lua` | builds a module's settings sections for the Edit Mode panel |
| `EditMode/Snap.lua` | snapping to grid, screen and frames |
| `EditMode/Checklist.lua` | module toggles in the Edit Mode window |
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
  id = "player", label = L["Player"], kind = "unit",
  defaults = { width = 200, height = 60, portraitScale = 100, powerHeight = 15 },
  settings = {               -- sections, drawn by Edit Mode panel and Settings window
    { section = L["Size"], controls = {
      { key = "width",  type = "slider", min = 80, max = 400, step = 1 },
      ...
    }},
  },
  blizzard = { "PlayerFrame" },   -- hidden while the module is on
  create = function(mod) ... end, -- once, out of combat
  apply  = function(mod) ... end, -- redraw from settings (queued in combat)
}
```

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
setter goes through `Options.set`), and three buttons (Settings, Reset
Settings, Reset To Default Position). Positions live in
`db.positions[layoutName][id] = { point, x, y }`; the library's `layout`
callback places every frame for the new layout, or at its default position
when that layout has none saved. The move callback snaps our own frames
(`EditMode/Snap.lua`, 8 px, to the screen edges and centre lines and to the
other AnotherHUD frames; no grid snap yet, see `docs/CHECKLIST.md`) and
saves; the default position (the library's own Reset Position) is saved
unsnapped. Every reposition goes through `Combat.after("pos:" .. id)`.
Without LibEditMode the frames go to their positions in the last layout
seen (`db.lastLayout`) or their defaults, and nothing else happens.

*(Filled in as built.)* Planned topics: secret values and how texts are formatted, hiding
Blizzard frames, party header attributes, sample data in Edit Mode, skinning
Blizzard action buttons.

## Secret values and taint

- Health, power and cast values may be secret in combat: no arithmetic,
  comparisons or string math on them; hand them to widgets.
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
