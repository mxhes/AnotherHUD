# Honor row and click to open (XP / Reputation bar)

Short design, 2026-11-28. Backlog item "XP / Reputation bar: honor, click to
open the reputation pane". Builds on Plan 6 (`Core/Tracking.lua`,
`Bars/Tracking.lua`).

## Why

The player wants the rest of the XP / Reputation backlog line done. Forever
has honor but no pet battles, renown, friendship or paragon, so only honor
and the click are left.

## Goals

- A third row for honor, under XP and reputation, turned on with a new
  "Show honor" setting (off by default; the player's choice).
- Clicking a row opens the matching Blizzard pane: the reputation row opens
  the reputation pane, the honor row opens the PvP pane. The XP row does
  nothing.

## Non-goals and anti-goals

- No pet battle hiding (Forever has no pet battles).
- No renown, friendship or paragon handling (not on Forever).
- Not a failure mode to accept: a click that throws a Lua error or a
  blocked-action message in combat. Out of combat only.

## Approaches

1. **Honor as a third row in the existing bar (picked).** The same row
   machinery, panel, divider and text as XP and reputation; the bar grows by
   one row when Show honor is on. Least new code; matches the approved look.
2. Honor as its own Edit Mode frame. More freedom to place it, but a second
   frame and settings panel for one thin row; dropped.
3. Honor only at max level, replacing the XP row. The player picked the
   setting instead.

## Design

- **Look (approved mockup 6):** honor color (1, 0.24, 0) in
  `Theme.trackingColors.honor`. The row is built like the others; row order
  XP, reputation, honor; rows that are off or have nothing to show are
  skipped and the bar reflows, as today.
- **Text:** "Honor level %d  %s / %s (%d%%)" through `ns.L` (German in
  `Locales/deDE.lua`), numbers formatted like the XP text; the percent uses
  the same rule as XP (`floor(value * 100 / max)`, none when max is 0 or a
  value is secret).
- **Rules (`Core/Tracking.lua`):** `Tracking.honor(value, max, level)`
  returns a row like `Tracking.xp` (nil when value or max is nil); secret
  values pass to the bar unread.
- **Client (`Bars/Tracking.lua`):** reads `UnitHonor("player")`,
  `UnitHonorMax("player")`, `UnitHonorLevel("player")`; updates on
  `HONOR_XP_UPDATE` and `HONOR_LEVEL_UPDATE`. All UNVERIFIED (check in
  client), each with a CHECKLIST line.
- **Setting:** `showHonor = false` in the module defaults; checkbox "Show
  honor" (tooltip "Show your honor and honor level.") next to Show XP / Show
  reputation. Edit Mode sample gets an honor row that follows the checkbox
  like the other two.
- **Click:** a click on a row (mouse up, left button) opens the pane: the
  reputation row `ToggleCharacter("ReputationFrame")`, the honor row
  `TogglePVPUI()`, each only when the function exists and
  `InCombatLockdown()` is false, and never in Edit Mode. UNVERIFIED (check in
  client) with CHECKLIST lines: both open the right pane, and nothing
  happens (no error) when clicked in combat.
- **Docs:** README (Show honor, click to open), CHANGELOG (one bullet),
  DEVELOPMENT (tracking section), CHECKLIST (new lines), BACKLOG (line
  removed), deDE texts.

## Left to the builder

- How the click finds the row under the mouse (per-row hit frames or the
  cursor position against row bounds).
- Test names and the exact shape of the honor rules function, within the
  above.
