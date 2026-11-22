# AnotherHUD checklist

What still has to be confirmed in the Forever client, and the release steps.

Code that relies on an unconfirmed client API carries an
`UNVERIFIED (check in client)` comment; add a line here whenever you add one,
and remove both once it is confirmed.

## Open checks

- Edit Mode snapping (`EditMode/Glue.lua`): `EditModeManagerFrame:IsSnapEnabled()`
  exists on Forever and turning Blizzard's Snap off stops our snapping.
- Edit Mode grid: find a readable API for Blizzard's grid spacing; until
  then our frames don't snap to the grid (`opts.grid = nil` in `EditMode/Glue.lua`).
- Edit Mode panel: the section titles show as Divider rows with the packaged
  LibEditMode (else the disabled-checkbox fallback shows); our Settings
  button sits next to the library's own Reset Settings / Reset Position.
- Edit Mode: nudging a snapped frame with the arrow keys moves it off the
  snap line (a nudge is saved unsnapped, `EditMode/Glue.lua`); a drag near a
  line still snaps.
- Edit Mode layouts: rename a layout with a moved frame, the frame stays
  put under the new name; delete a layout, no Lua error.

## Unit frames (Plan 3)

FlareUI's unit frames off for this test. Run with the Player, Target, Target of
Target, Focus and Pet frames; a dummy and a group are enough.

Frames and Edit Mode:

- The five frames show at their default positions; in Edit Mode each shows
  with sample data (no target needed) and drags; positions differ per layout.
- Leaving Edit Mode with no target hides Target, Target of Target and Focus.
- Panel (Player): sections Size, Text, Look, Behaviour, Cast Bar, Auras,
  Fading show (Divider rows with the packaged LibEditMode), our Settings
  button sits next to Reset Settings / Reset Position.
- The panel's `BackdropTemplate` child (`Units/Parts/Panel.lua`) shows the
  Round edge and fill.
- Detach cast bar on puts the Player cast bar on its own Edit Mode frame
  ("Player Cast Bar") that drags; off, that frame can't be selected
  (`Units/PlayerCastBar.lua`) and the bar hangs under the Player frame.
- Right click (`*type2 = "togglemenu"`) opens the unit menu, also with the
  gamepad UI; the tooltip shows on hover and another addon's tooltip is not
  hidden on leave (`GameTooltip:IsOwned`).
- Target of Target follows its unit within 0.2 s.
- The state driver (`[petbattle] hide; [vehicleui] hide; [@unit,exists] show;
  hide`) hides the frames in pet battles and, with Show in vehicle off, in
  vehicles.

Colors, bars and texts:

- `C_ClassColor.GetClassColor(classFile)` returns a color with `GetRGB`;
  `PowerBarColor[token]` holds `r, g, b` for every power token
  (`Core/UnitColor.lua`).
- `SetFormattedText` takes secret health, power and level arguments
  (`Units/Parts/Bars.lua`, `Ring.lua`); health and power texts show in a
  fight against a dummy and in a group with no Lua error.
- `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` and
  `UnitPowerPercent(unit, type, false, CurveConstants.ScaleTo100)` give the
  percent texts 0-100 (`Units/Base.lua`).

Portrait ring:

- A `MaskTexture` with the Disc file (`CLAMPTOBLACKADDITIVE`) clips the
  portrait to a circle; `SetPortraitTexture(tex, unit, true)` draws for units
  with secret identity (instances) without an error (`Units/Parts/Ring.lua`).

Cast bar (`Units/Parts/CastBar.lua`):

- `StatusBar:SetTimerDuration` takes the secret duration from
  `UnitCastingDuration` / `UnitChannelDuration` (cast fills, channel
  empties).
- `C_DurationUtil.CreateDurationTextBinding` shows the time with one decimal
  (`C_StringUtil.CreateNumericRuleFormatter`); its `Disable` / `Enable` keep
  the Edit Mode sample's "0.9".
- The Edit Mode sample (a static 62% texture over the hidden timed fill,
  after `ClearTimerDuration` when it exists) shows right after a real cast,
  and the next real cast fills normally again.
- `SetAlphaFromBoolean` with a secret `notInterruptible` shows the shield and
  the grey overlay only on uninterruptible casts (a dungeon boss); the grey
  overlay and the spark follow the fill texture.
- A kicked channel shows "Interrupted" (`UNIT_SPELLCAST_CHANNEL_STOP` with
  `interruptedBy`).
- `UnitCastingInfo` / `UnitChannelInfo` return no values at all when the unit
  is idle (`select("#", ...) == 0`).
- `INTERRUPTED` (or `CHANNEL_STOP` with `interruptedBy`) arrives before the
  cast's `STOP`, so the bar holds on "Interrupted" instead of hiding.

Auras (`Units/Parts/Auras.lua`):

- `Blizzard_AuraContainer` loads and
  `CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")`
  works when created at login.
- The `HARMFUL|!PLAYER` / `HELPFUL|!PLAYER` filters show only other players'
  / NPCs' auras.
- `SetIcon`, `SetDurationCooldown`, `SetApplicationCount`, `SetDurationText`
  and `AddDispelTypeTexture` (Border style) work on the container's buttons;
  the dispel border colors match the approved type colors
  (`Theme.unitColors.debuff`).
- `SetDesaturated` on an icon of the others' groups sticks.
- The flow layout setters (`SetFlowLayoutAxis`, `...AnchorPoint`,
  `...GrowthDirection`, `...MaximumLineSize`, `...Padding`) and
  `AnchorUtil.FlowDirection` grow away from the portrait.
- Each kind's clip frame (`SetClipsChildren(true)`) cuts icons past the Aura
  rows setting, and since mine come first only other players' auras are cut;
  buffs sit under the debuffs (none of the debuffs' space when Debuffs is
  off).

Hiding Blizzard's frames (`Units/Base.lua`):

- Blizzard's Player, Target, Focus, Pet and cast bar never reappear: not
  after a vehicle, a pet battle, an Edit Mode layout switch or the
  lock-to-player toggle (the `SetParent` hook parks the cast bar again).
- Blizzard's Target of Target goes away with `TargetFrame`.

Combat and taint:

- Dummy fight with `/console taintLog 1`: no AnotherHUD lines, no
  "Interface action failed" / blocked message; target and menu clicks work in
  combat.
- Hiding `PlayerFrame`, `TargetFrame`, `FocusFrame`, `PetFrame` and
  `PlayerCastingBarFrame` (events off, reparent to a hidden frame, re-hide on
  `Show`) leaves no AnotherHUD lines in the taint log.
- `/reload` in combat: the frames come back with no Lua error.

## Edit Mode spike (Plan 1, Task 7)

Setup first: link the addon and copy the libraries as in
`docs/DEVELOPMENT.md` (Setup, "Spike check"). Results go here (date,
pass / fail, what was seen). The spike's test frame is gone since Plan 3: run
these checks with the Player frame, whose panel has the sections Size, Text,
Look, Behaviour, Cast Bar, Auras and Fading.

- **First:** the library loaded: `/dump LibStub and LibStub("LibEditMode", true) ~= nil`
  prints `true`. Library source: the CI `package-dry-run` job artifact (its
  zip holds `AnotherHUD/Libs/...`) or https://github.com/p3lim-wow/LibEditMode
  copied into `AnotherHUD/Libs/LibEditMode/`; its entry file `embed.xml`
  (at the repo root upstream) is what `embeds.xml` loads. If this prints
  `false`, nothing below can pass.
- The Player frame shows in Edit Mode, drags, snaps to screen and
  AnotherHUD frames, and its panel opens next to it with our Settings button
  and the library's reset buttons; positions differ per layout. (Grid and
  Blizzard-frame snap are not built yet, see above.)
- Checklist checkbox appears under Blizzard's list and toggles the Player
  frame (`EditMode/Checklist.lua`: `EditModeManagerFrame:HookScript("OnShow")`,
  a `BackdropTemplate` box on `UIParent` anchored under the window,
  `UICheckButtonTemplate` rows).
- "AnotherHUD look" checkbox appears in Action Bar 1's Edit Mode panel
  (`EditMode/SystemSettings.lua`: `LibEditMode:AddSystemSettings` with
  `Enum.EditModeSystem.ActionBar` and
  `Enum.EditModeActionBarSystemIndices.MainBar`); clicking it prints
  "AnotherHUD look: on / off".
- **Taint:** after opening Edit Mode, changing both, saving and leaving:
  `/reload`-free combat on a target dummy, cast from Action Bar 1, open the
  spellbook and talents in combat — no "Interface action failed" / blocked
  message; `/console taintLog 1` log shows no AnotherHUD lines. If taint
  lines point at `Checklist`, report it: the fallback moves the module
  toggles to the Settings window.
- With Edit Mode open, start a fight (target dummy) and change the Player's Width: no
  error, the size applies when combat ends.
- Reset Settings (the library's button) returns the Player's settings to
  their defaults with no Lua error.
- `BackdropTemplate` on the checklist box draws the round edge.
- Turn the Player frame off, /reload, open Edit Mode, turn it on: it appears
  and the chat says "Reopen Edit Mode to move it"; after closing and
  reopening Edit Mode it is selectable and drags, with no taint lines.
- The checklist box shows under the Edit Mode window and hides with it.

Results:

- 2026-11-21, first run (LibEditMode MINOR 19 from the `package-dry-run`
  artifact, FlareUI still enabled):
  - **Fail, fixed:** the library check printed `true`, but AnotherHUD fell
    back to "no LibEditMode": `Glue.lib()` expected `LibStub` to be a
    function, while the real one is a callable table. Fixed by looking it up
    with `LibStub:GetLibrary` (merge request 3).
  - **Pass after the fix:** the test frame is selectable and draggable in
    Edit Mode with its panel; the layout callback works (`lastLayout` saved
    as the active layout); the "AnotherHUD look" setting on Action Bar 1
    stores its value; BugGrabber recorded no AnotherHUD errors.
  - **Pass (by sight only):** combat on a target dummy with Action Bar 1
    after using the checklist and the Action Bar 1 setting showed no
    "Interface action failed" / blocked message. The taint log was not
    captured (`taintLog` was not on), so "no AnotherHUD lines in the taint
    log" is still open.
  - Still open: everything else in the list above (snapping, per-layout
    positions after a drag, Reset Settings, combat Width change, the
    checklist box and toggle details, rename / delete).
- [ ] LibEditMode fires "enter" / "exit" when Edit Mode opens / closes and
  `lem:IsInEditMode()` exists (Glue.inEditMode and `spec.onEditMode`).

## Release steps

1. `main` is green: `lua tests/run.lua` passes locally and the `test` jobs
   (Lua 5.1 and 5.4) and the `lint` job pass in GitLab CI.
2. The open checks above are done in the client, or knowingly left for a
   later release.
3. `## Interface:` in `AnotherHUD/AnotherHUD.toc` matches the client
   (`/dump select(4, GetBuildInfo())`, 16001 today).
4. Run the manual `package-dry-run` job on `main`: its log lists one
   `AnotherHUD/` folder with the `.toc`, the code and `Libs/` (LibStub,
   CallbackHandler-1.0, LibEditMode), and no `docs/`,
   `tests/` or `CLAUDE.md`.
5. Add the version's entry on top of `CHANGELOG.md` (merged into `main`):
   the packager sends it to CurseForge as the release notes. Keep it short
   and precise: one bullet per player-visible change, one or two lines
   each, about ten bullets at most, small fixes together in one "Fixes:"
   bullet; no internals (refactors, tests, caches), no option details or
   reasons (those go in `README.md`).
6. Tag `main` with the version as a maintainer (`git tag -a v0.1.0 -m ...`,
   then `git push origin v0.1.0`). `v*` tags are protected tags (maintainers
   only), which is what gives the tag pipeline the protected, masked CI/CD
   variable `CF_API_KEY` (the CurseForge API token). The `package` job builds
   the zip (the `.toc` version comes from the tag), uploads it to CurseForge
   (`## X-Curse-Project-ID` in the `.toc`, once the project exists) and keeps it in the
   job's artifacts for 30 days.
7. Check the `package` job log: `CurseForge ID: <project id> [token set]` near the
   top and `Uploading ... Success!` before `Packaging complete.`; then the file
   on CurseForge shows the changelog and the game version (the packager maps
   `## Interface: 16001` to `1.60.1`). Without `[token set]` the upload is
   skipped silently. Retrying the job doesn't help: a pipeline keeps the
   protection it was created with, so start a new pipeline on the tag (CI/CD >
   Pipelines > Run pipeline, pick the tag).
