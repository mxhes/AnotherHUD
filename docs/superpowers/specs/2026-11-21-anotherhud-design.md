# AnotherHUD: action bars and unit frames with Edit Mode

Date: 2026-11-21. Status: draft for approval.

## Intent

The player wants to run their own UI suite:
**AnotherLedger** (exists, `D:\GitRepos\LootLedger`), **AnotherHUD** (this
addon) and a minimap addon (later). AnotherHUD is the frames part of that
suite. The Edit Mode integration should feel like this:

- every AnotherHUD frame can be moved and snapped in Blizzard's Edit Mode,
- each one has a toggle in the Edit Mode window's checklist (like the "WIM ..."
  entries some addons show below the Blizzard list),
- clicking a frame in Edit Mode opens a settings panel next to it with
  collapsible sections (Size, Text, Look, Behaviour, Cast Bar, Auras, ...) and
  footer buttons (Settings, Reset Settings, Reset To Default Position).

The addon must be easy to extend: more Blizzard frames will be replaced later.

## Goals (first release: the player's old UI addon can be switched off)

Unit frames (own frames, Blizzard's are hidden):

| Frame | Sections in its Edit Mode panel |
| --- | --- |
| Player | Size (Width, Height, Portrait Scale, Power Height), Text, Look, Behaviour, Cast Bar, Auras, Fading |
| Target | as Player (its cast bar) |
| Target of Target | Size, Text, Look, Fading |
| Focus | as Target |
| Pet | Size, Text, Look, Auras, Fading |
| Party | Orientation, Growth, Frame Gap, Sort by Role, Show Player, Size, Text, Look, Behaviour, Auras, Fading |
| Boss | Growth, Frame Gap, Size, Text, Look, Cast Bar, Auras |

Section contents (the player's pick: a small set first):

- **Size**: width, height, portrait scale, power height (per unit as listed).
- **Text**: name on/off, health format and power format (none, percent,
  value, value + percent), font size.
- **Look**: skin, class color on/off, bar texture.
- **Behaviour**: show in vehicle; clicks stay Blizzard's (target / menu).
- **Cast Bar**: on/off, width, height, icon on/off, detach (see below).
- **Auras**: buffs on/off, debuffs on/off, icon size, rows, only mine.
- **Fading**: opacity out of combat, full opacity on mouse-over.

Bars (Blizzard's own, re-skinned):

- Action Bars 1-8, Stance Bar, Pet Bar: our look on Blizzard's buttons
  (border, background, font, hotkey / macro text / count, range and mana
  tinting); Blizzard keeps clicks, paging, cooldowns, procs and keybinds.
  Panel sections: Look, Text, Fading (out of combat / mouse-over).
- **Proc glow** on action buttons in our look (Blizzard's spell alert
  restyled or recolored; mockup first).
- **Player cast bar**: one bar, owned by the Player module ("Cast Bar"
  section). It sits under the Player frame; **Detach** turns it into its own
  Edit Mode frame. Blizzard's player cast bar is hidden.
- XP / Reputation bar: re-skinned Blizzard status tracking bars.
- **Class resource bar** (combo points, holy power, runes, soul shards,
  chi, arcane charges, essence, ...): own module, own Edit Mode frame,
  attached under the Player frame by default.
- **Totem bar**: own module (totems / guardians with timers).
- **Bar text and fading** as above, for unit frames and bars.

Second release: Party Style (Classic / other styles), Pets & Targets for
party, raid frames.

Everywhere:

- One look shared with AnotherLedger: `Theme.lua` (colors, fonts, sizes,
  textures) and its skins (Classic, Forge, Slate, Gilded) carried over.
- A small Settings window (the panel's "Settings" button and a slash command)
  for addon-wide things: skin, colors, fonts, profiles, which modules are on.
- Profiles like AnotherLedger (account-wide data, per-character profile pick).
- English and German texts.
- A module registry so a new replaced frame is one file plus one `.toc` line.

## Non-goals (first release)

- Raid frames, nameplates, minimap, chat, bags, tooltips, objective tracker,
  damage meter, cooldown manager, loot rolls: AnotherHUD
  does not do them (raid frames come next; minimap goes to its own addon).
- Own action buttons with free layouts (radial menus, custom paging).
- Languages other than English and German.
- Importing another addon's settings.

## Anti-goals (a failure even if it works)

- **Taint in combat**: "Interface action failed because of an AddOn", blocked
  actions, or bars that can't be changed in combat because we touched them.
- **Lua errors from secret values**: math or comparisons on health, power or
  cast values in combat.
- Copying or imitating other addons' code, art or design. Only the player's
  own addons (AnotherLedger) may be copied.
- A huge options maze: settings live in the Edit Mode panel next to
  the frame; the Settings window only holds what is addon-wide.
- New artwork shipped without the player having approved a mockup.

## Constraints

- **WoW Forever**, retail engine, `## Interface: 16001`, Lua 5.1.
- **Secret values.** In combat the client hands addons health, power and cast
  numbers as secret values (e.g. `UnitHealthPercent(unit, true, curve)`). Code may pass them to widgets
  (`StatusBar:SetValue`, `FontString:SetText`, curve / color APIs) but must not
  do arithmetic or comparisons on them. Exact API surface: UNVERIFIED, check
  in the client which calls work.
- **Combat lockdown.** Secure frames can't be created, moved, shown/hidden or
  re-anchored in combat; all layout changes queue until
  `PLAYER_REGEN_ENABLED`.
- Same tooling as AnotherLedger: plain-Lua tests (`lua tests/run.lua`, 5.1 and
  5.4 in CI), luacheck, GitHub Actions, BigWigs packager, CurseForge release.
- Development copy works without `Libs/` except for Edit Mode (LibEditMode is
  required for the Edit Mode part; without it frames stay where they are and
  the Settings window still works).
- Remote: `https://github.com/mxhes/AnotherHUD`, branch `main`.

## Approaches (picked by the player: A / A / A)

**Action bars**

- **A. Re-skin Blizzard's bars (picked).** Blizzard keeps the secure logic
  (clicks, paging, cooldowns, procs, keybinds) and Edit Mode already places
  these bars; we add the look and our settings to their Edit Mode panel. Least
  taint, survives patches.
- B. Own secure action buttons: full layout freedom, but cooldowns, proc
  glows, paging, keybinds and drag & drop rebuilt under the secret-value rules.
- LibActionButton: no sign it supports Forever; dropped.

**Unit frames**

- **A. Own frames on `SecureUnitButtonTemplate` (picked).** Free layout,
  Blizzard's frames hidden, values go straight into status bars and text.
- B. Re-skin Blizzard's unit frames: too limiting for the Player / Party
  options the player wants.
- oUF: no sign it supports Forever; dropped.

**Edit Mode**

- **A. Embed LibEditMode unmodified (picked)**, fetched by the packager, plus
  a small own piece for snapping and the checklist toggles.
- B. Fork it: we would own its upkeep.

## Design

### Layout of the repo (mirrors AnotherLedger)

```
AnotherHUD/            addon folder (.toc, code, Media/, Locales/)
  Core/                pure Lua: Util, Locale, Theme, DB, Options, Profiles, Modules
  EditMode/            LibEditMode glue, snapping, checklist toggles, panel builder
  Units/               unit frame base + one file per unit (Player, Target, ...)
  Bars/                action bar skin, stance, pet, cast bar, XP / rep
  UI/                  Settings window, widgets, fonts (from AnotherLedger)
  Boot.lua
docs/                  DEVELOPMENT.md, CHECKLIST.md, BACKLOG.md, superpowers/
tests/                 harness + test_*.lua (fake frames, as AnotherLedger)
```

### Module registry (the extension point)

Every replaced frame is a module: `ns.Modules.define{ id, label, kind =
"unit" | "bar", defaults, settings, create, apply, enable, disable,
blizzard }`.

- `defaults`: its saved settings (merged into the profile).
- `settings`: a data list of sections and controls (slider, dropdown,
  checkbox, color) that the Edit Mode panel and the Settings window both
  draw from. Controls read and write through `Options.get/set`.
- `create`: builds the frame once (out of combat). `apply`: redraws it from
  settings (queued while in combat if it touches secure attributes).
- `blizzard`: what to hide or re-skin (a frame name list or a function).

Adding a frame later = one new file calling `Modules.define` + a `.toc` line.
UI code never names a module.

### Edit Mode integration

- Unit frames: `LibEditMode:AddFrame(frame, onMove, default, label)` plus
  `AddFrameSettings` built from the module's `settings` list, plus
  `AddFrameSettingsButtons` for Settings / Reset Settings / Reset To Default
  Position.
- Blizzard bars: `LibEditMode:AddSystemSettings(systemID, ...)` appends our
  look settings to Blizzard's own action bar panels (UNVERIFIED on Forever).
- Positions are stored per Edit Mode layout (LibEditMode's `layout`
  callback); look settings are per profile, not per layout.
- Snapping to grid, screen edges and other frames: own small helper run in
  our own move callback on our own frames. **No hooks into LibEditMode's
  internals**; panels stay short enough not to need scrolling.
- Checklist toggles: a short list of checkboxes under Blizzard's list in the
  Edit Mode window (as WIM does in `Sources/EditMode.lua`), one per module;
  off = the module is disabled and Blizzard's frame comes back (after
  `/reload` if it can't be restored live). Taint risk: UNVERIFIED.
- **Early client spike** for the checklist toggles and `AddSystemSettings`
  before any bar work. If either taints: action bar look goes into our own
  panel (opened from our Settings window), module toggles live only in the
  Settings window.
- Module on/off is part of the **profile**. Switching to a profile that
  needs a Blizzard frame back asks for a `/reload`.

### Unit frames

- One base (`Units/Base.lua`) builds the parts every unit uses: health bar,
  power bar, portrait (round mask, like the screenshot, scalable), name /
  level / value texts, cast bar, aura rows, raid icon, role / leader icons.
- Values reach the widgets as given (secret-safe); texts use the client's
  formatting / curve APIs, never our math.
- Party and Boss are headers (`SecureGroupHeaderTemplate` for party; boss1-5
  fixed frames) with orientation, growth, gap and role sort.
- Blizzard's frames are hidden by reparenting to a hidden frame and
  unregistering their events, out of combat, once.
- Edit Mode shows sample data (fake party members) so frames
  can be placed with nobody in the group.

### Look and artwork

- `Theme.lua`, fonts, skins and widgets come from AnotherLedger, renamed into
  this addon's namespace (no shared library yet; a shared "Another" core is a
  backlog idea once the minimap addon exists).
- **Any new art (portrait ring, bar textures, button borders, proc glow,
  resource bar pips) is shown to the player as a mockup first and built only
  after approval.** Mockups are HTML pages shown in the browser pane. Code is
  built on AnotherLedger's existing look meanwhile; only the new art waits
  for approval and is swapped in afterwards.

### Saved state

- `AnotherHUDDB` (account): profiles, per-layout positions.
- `AnotherHUDCharDB` (character): chosen profile.

## Left to the builder

- Order of work, file split inside the folders above, test layout.
- Whether the player cast bar is drawn by us or is Blizzard's re-parented and
  re-skinned (pick what is safer with secret values once checked in the
  client); either way it behaves as described above.

## Calls made by Claude (the player may overrule)

- One player cast bar with a Detach option, owned by the Player module.
- HTML mockups; code proceeds on the existing look while art waits.
- No hooks into LibEditMode internals; snapping in our own callback.
- Taint fallback for the checklist and action bar panels (above).
- Module on/off stored per profile, `/reload` prompt when needed.
- Exact control ranges and defaults (sizes start from the screenshot:
  Player 200 x 60, Power Height 15, Portrait Scale 100%).
- How sample data looks in Edit Mode.
