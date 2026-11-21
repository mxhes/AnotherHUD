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
- Edit Mode: nudging a frame with the arrow keys near another frame or a
  screen line snaps it back (our snap runs on every move callback).

### Edit Mode spike (Plan 1, Task 7)

Setup first: link the addon and copy the libraries as in
`docs/DEVELOPMENT.md` (Setup, "Spike check"). Results go here (date,
pass / fail, what was seen).

- Test frame ("AnotherHUD Test", `Spike/SpikeModule.lua`) shows in Edit Mode,
  drags, snaps to grid / screen / Blizzard frames, panel opens next to it with
  the sections (Size, Look), our Settings button and the library's reset buttons; positions differ per
  layout. (Grid and Blizzard-frame snap are not built yet, see above: expect
  screen and AnotherHUD-frame snap only.)
- Checklist checkbox appears under Blizzard's list and toggles the test frame
  (`EditMode/Checklist.lua`: `EditModeManagerFrame:HookScript("OnShow")`, a
  `BackdropTemplate` box anchored under the window, `UICheckButtonTemplate`
  rows).
- "AnotherHUD look" checkbox appears in Action Bar 1's Edit Mode panel
  (`EditMode/SystemSettings.lua`: `LibEditMode:AddSystemSettings` with
  `Enum.EditModeSystem.ActionBar` and
  `Enum.EditModeActionBarSystemIndices.MainBar`); clicking it prints
  "AnotherHUD look: on / off".
- **Taint:** after opening Edit Mode, changing both, saving and leaving:
  `/reload`-free combat on a target dummy, cast from Action Bar 1, open the
  spellbook and talents in combat — no "Interface action failed" / blocked
  message; `/console taintLog 1` log shows no AnotherHUD lines.
- `BackdropTemplate` on the test frame and the checklist box draws the round
  edge; "Show border" off leaves the flat fill.

Results: *(not run yet)*

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
6. Tag `main` with the version as a maintainer (`git tag -a v0.4.2 -m ...`,
   then `git push origin v0.4.2`). `v*` tags are protected tags (maintainers
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
