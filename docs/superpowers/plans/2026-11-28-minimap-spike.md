# Minimap Plan 1 (Spike Gate) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Blizzard's map into an AnotherHUD Edit Mode frame with the Square / Round shape and mouse wheel zoom, hide Blizzard's minimap cluster, and let the player check in the game that nothing taints. This is the design's hard gate.

**Architecture:** Pure rules in `Core/MinimapRules.lua` (mask path, shape name, zoom step); module `minimap` in `Map/Minimap.lua` (plain frame `AnotherHUDMinimap` on `UIParent`, Blizzard's `Minimap` reparented into it out of combat and kept there by hooks, `MinimapCluster` hidden with `Base.hideBlizzard`). The square border is the existing skin panel; the round ring, the elements and the container come in later plans.

**Tech Stack:** Lua 5.1, plain-Lua tests (`lua tests/run.lua`), luacheck, LibEditMode through the existing `EditMode/` glue.

**Spec:** `docs/superpowers/specs/2026-11-28-minimap-design.md` (approved 2026-11-28); look `docs/mockups/7-minimap.html` (APPROVED.md section 7).

## Global Constraints

- Lua 5.1; `lua tests/run.lua` passes and `luacheck AnotherHUD` has 0 warnings after each task.
- Skins Classic, Forge, Slate (no Gilded).
- Map default 180 x 180; default position top right of the screen (`{ point = "TOPRIGHT", x = -16, y = -40 }`).
- Masks (no new art): Square `Interface\Buttons\WHITE8x8`, Round `Textures\MinimapMask`. UNVERIFIED (check in client).
- `GetMinimapShape` defined at `PLAYER_LOGIN` only when still nil; answers "SQUARE" / "ROUND" from the Shape setting on every call.
- Mouse wheel zoom on by default; zoom stays within `0 .. Minimap:GetZoomLevels() - 1`.
- Everything that touches Blizzard frames (reparent, anchor, hide) runs out of combat through `ns.Combat.after(key, fn)`.
- Never write to Blizzard tables; hooks with `hooksecurefunc` only.
- Options: default in `defaults`, label <= 24 characters, tooltip, German in `Locales/deDE.lua`.
- Every unconfirmed API: `UNVERIFIED (check in client)` comment plus a CHECKLIST line.
- New `.lua` files go in the `.toc` (after `Bars/Tracking.lua`) and the DEVELOPMENT layout table.
- Lua edited with the Write / Edit tools.
- During the spike Blizzard's mail, tracking, calendar, clock and zone text are hidden with the cluster (they come back in Plan 2); README says so.

## Review Focus

1. Blizzard re-parents or re-anchors `Minimap` (layout switch, Edit Mode close): it goes back into our frame, never in combat.
2. Turning the module off: `Minimap` is not left inside a hidden frame (the player keeps a map after a /reload with Blizzard's back).
3. Another addon already defined `GetMinimapShape`: ours does not overwrite it.
4. The wheel at the zoom ends: no call with a zoom below 0 or at / above the level count.
5. A Shape change while in combat: the mask change is queued, no error.

---

### Task 1: Minimap rules

**Files:**
- Create: `AnotherHUD/Core/MinimapRules.lua`
- Modify: `AnotherHUD/AnotherHUD.toc` (after `Core/Tracking.lua`), `docs/DEVELOPMENT.md` (layout row)
- Test: `tests/test_minimap_rules.lua`

**Interfaces:**
- Produces `ns.MinimapRules`:
  - `mask(shape) -> string`: "Square" -> `Interface\Buttons\WHITE8x8`, anything else -> `Textures\MinimapMask`.
  - `shapeName(shape) -> "SQUARE" | "ROUND"`.
  - `zoom(current, delta, levels) -> number | nil`: the new zoom for a wheel `delta` (+1 in, -1 out); nil when it would leave `0 .. levels - 1` or when an input is not a plain number.

- [ ] **Step 1: Write the failing tests** "minimap mask follows the shape" (Square / Round / nil), "shape name for GetMinimapShape", "wheel zoom stays in range": `zoom(0, 1, 6) == 1`, `zoom(5, 1, 6) == nil`, `zoom(0, -1, 6) == nil`, `zoom(3, -1, 6) == 2`, `zoom(nil, 1, 6) == nil`, `zoom(1, 1, nil) == nil`.
- [ ] **Step 2:** `lua tests/run.lua`: the new tests fail.
- [ ] **Step 3:** Implement the three functions (plain Lua, no client calls); add the `.toc` and DEVELOPMENT rows.
- [ ] **Step 4:** `lua tests/run.lua` and `luacheck AnotherHUD`: all pass, 0 warnings.
- [ ] **Step 5: Commit** `feat: minimap rules`.

### Task 2: The minimap module (spike)

**Files:**
- Create: `AnotherHUD/Map/Minimap.lua`
- Modify: `AnotherHUD/AnotherHUD.toc` (after `Bars/Tracking.lua`), `AnotherHUD/Locales/deDE.lua`, `.luacheckrc` (read_globals `Minimap`, `MinimapCluster`, `GetMinimapShape` as a settable global), `README.md`, `CHANGELOG.md`, `docs/DEVELOPMENT.md`, `docs/CHECKLIST.md`, `CLAUDE.md` (status)
- Test: `tests/test_minimap.lua`; bump module / checklist counts in `tests/test_units.lua` (checklist order ends "boss", "tracking", "minimap")

**Interfaces:**
- Consumes: Task 1's `ns.MinimapRules`; `ns.Modules.define`, `ns.Units.Base.hideBlizzard`, `ns.Units.Base.skinOf`, `Units/Parts/Panel`, `ns.Combat.after`, `ns.Options.get`.
- Produces: module `minimap` (kind `"misc"`, label "Minimap", frame `AnotherHUDMinimap`), options `size = 180`, `shape = "Square"`, `skin = "Classic"`, `wheelZoom = true`.

- [ ] **Step 1: Write the failing tests** in `tests/test_minimap.lua` (fake `Minimap` frame with `SetMaskTexture`, `GetZoom`, `SetZoom`, `GetZoomLevels` = 6 recording calls; fake `MinimapCluster`; set up like `tests/test_tracking.lua`'s `withBar`):
  - "the minimap module registers with Edit Mode and the checklist": kind, label, default position, frame name, size 180 x 180.
  - "Blizzard's map moves into our frame": `Minimap:GetParent() == frame`, anchored inside the skin border (inset = edge width), size `180 - 2 * edge`.
  - "Blizzard's cluster is hidden": `MinimapCluster` reparented away and hidden.
  - "the shape sets the mask": Square -> `Interface\Buttons\WHITE8x8`; set Round -> `Textures\MinimapMask`; the square panel shows only for Square.
  - "a shape change in combat waits": with combat on, set Round, mask unchanged; leave combat, mask is round.
  - "Blizzard re-parenting the map is undone": call `Minimap:SetParent(UIParent)` (as Blizzard would), the hook puts it back into our frame (out of combat at once, in combat after combat).
  - "the wheel zooms within range": `OnMouseWheel(1)` from 0 sets zoom 1; at 5 a further +1 does nothing; with `wheelZoom` off nothing changes.
  - "GetMinimapShape answers the shape and is not overwritten": fire `PLAYER_LOGIN`; `GetMinimapShape() == "SQUARE"`, after setting Round `"ROUND"`; in a second run with a pre-set `GetMinimapShape` that returns "CORNER-TOPLEFT", ours does not replace it.
  - "turned off, the map goes back to Blizzard": module off -> `Minimap` back under `MinimapCluster` with its old anchors, and the cluster is not hidden after a reload (the module does not hide it when disabled at login).
- [ ] **Step 2:** `lua tests/run.lua`: the new tests fail.
- [ ] **Step 3:** Implement `Map/Minimap.lua`:
  - `ns.Modules.define{ id = "minimap", label = "Minimap", kind = "misc", defaults, settings, defaultPosition, create, apply, onEditMode }`; settings sections Size (`size` slider 120-320, "Map size", "Width and height of the map."), Look (`skin` dropdown Classic / Forge / Slate, `shape` dropdown Square / Round: "Shape", "Square or round map."), Behaviour (`wheelZoom` checkbox: "Mouse wheel zoom", "Zoom the map with the mouse wheel.").
  - Frame and panel like the tracking bar; the panel shows for Square, hides for Round (the round ring comes in Plan 2).
  - Reparent and anchor `Minimap` under the key `"minimap:map"` through `ns.Combat.after`; remember its original parent and points for turning off. `hooksecurefunc(Minimap, "SetParent", ...)` and `(Minimap, "SetPoint", ...)` re-queue the anchor when Blizzard moves it (guard against our own calls).
  - `Minimap:SetMaskTexture(MinimapRules.mask(shape))` under `"minimap:mask"`.
  - `Minimap:EnableMouseWheel(true)`; `OnMouseWheel` through `MinimapRules.zoom` when `wheelZoom` is on.
  - `ns.Units.Base.hideBlizzard({ "MinimapCluster" })` after the map is moved out, only while the module is on.
  - `GetMinimapShape` on `PLAYER_LOGIN` when nil.
  - UNVERIFIED comments on: `Minimap` reparenting without taint, `SetMaskTexture` with the two paths, `GetZoomLevels` / `SetZoom`, `MinimapCluster` hiding, `GetMinimapShape` use by other addons.
  - German: "Minimap" ("Minikarte"), "Map size" ("Kartengröße"), "Width and height of the map." ("Breite und Höhe der Karte."), "Shape" ("Form"), "Square or round map." ("Eckige oder runde Karte."), "Square" ("Eckig"), "Round" ("Rund"), "Mouse wheel zoom" ("Mausrad-Zoom"), "Zoom the map with the mouse wheel." ("Zoomt die Karte mit dem Mausrad.").
- [ ] **Step 4:** Docs: README (a short "Minimap" paragraph: shape, size, mouse wheel; for now Blizzard's mail, tracking, clock, calendar and zone name are hidden, they come back next), CHANGELOG (one bullet), DEVELOPMENT (layout row, module row, a "Minimap" section: reparent + hooks, mask, cluster hiding, GetMinimapShape), CHECKLIST: a "Minimap spike (gate)" section with: no taint lines (`/console taintLog 1`) and no blocked-action message while opening / closing Edit Mode, switching / resetting a layout, entering and leaving combat, zoning, /reload, queueing for a dungeon from the group finder; the map shows, clicks (pings) and tracks at both shapes; the square and round masks look right; the map stays in our frame after a layout switch; the wheel zooms; turning the module off and /reload brings Blizzard's minimap back. CLAUDE.md status line.
- [ ] **Step 5:** `lua tests/run.lua` and `luacheck AnotherHUD`: all pass, 0 warnings.
- [ ] **Step 6: Commit** `feat: minimap spike (map in our frame, shape, wheel zoom)`.

### Task 3: The player's client check (gate)

- [ ] The player runs the CHECKLIST "Minimap spike (gate)" section. Results go into that section (date, pass / fail, what was seen).
- [ ] Pass: write Plan 2 (elements, round ring, mail / queue / tracking). Fail (any taint or blocked action from AnotherHUD): stop and rethink with the player (the player's decision, spec "Order of the work").
