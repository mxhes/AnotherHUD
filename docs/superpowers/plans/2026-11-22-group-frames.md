# Group Frames (Plan 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Our own Party frames (player plus party1-4, role icons, leader crown, range fading, dead / offline states, dispel glow, aura row) and Boss frames (boss1-5 with cast bars and my debuffs) in the approved look, each moved as one block in Edit Mode; Blizzard's party and boss frames hidden.

**Architecture:** Plan 3's `Units/Base.lua` learns to build *member* frames (several secure unit buttons per module, each with its own combat key) next to the single-frame modules. A new `Units/Group.lua` holds one plain holder frame per group module (the Edit Mode frame), its member frames at fixed unit tokens, their order (sort by role, out of combat) and visibility. The pure rules (order, offsets, holder size, visibility conditions, role / crown geometry, dead / offline colors) live in `Core/`. Each group is one `ns.Units.defineGroup{...}` file (`Units/Party.lua`, `Units/Boss.lua`).

**Tech Stack:** Lua 5.1, WoW Forever client API (Interface 16001), LibEditMode (packager external), plain-Lua test harness (`lua tests/run.lua`), luacheck in CI, plain Python for the TGA art (`tools/render_units.py`).

**Spec:** `docs/superpowers/specs/2026-11-21-anotherhud-design.md` (Goals: the Party and Boss rows and section contents; Design: Unit frames, Edit Mode integration) and the approved art in `docs/mockups/APPROVED.md` section 3 (page `3-party-boss.html`, drawing rules in `units.js` / `kit.js`).

**Calls made here (the player may overrule):**
- **Fixed member frames instead of `SecureGroupHeaderTemplate`** (the spec said header): five `SecureUnitButtonTemplate` buttons at fixed tokens (`player`, `party1`-`party4`; `boss1`-`boss5`), each with its own state driver. Their order (sort by role, existing members first) is set out of combat on roster / role changes. Cost: someone who joins mid-fight shows in the next free slot and moves into role order when combat ends. Gain: it reuses Plan 3's Base unchanged in spirit, no restricted-environment snippets, and it's fully testable.
- **In a raid the party frames hide** (the player's answer, 2026-11-22): Blizzard's raid frames take over.
- **Both Blizzard party frames are hidden**: `PartyFrame` and `CompactPartyFrame` (the "raid-style party frames" look), else one of them doubles ours. Raid frames are left alone.
- **No raid target icon** yet: it is not in the approved mockup (backlog).
- Boss cast bar 4 px under the frame and a default Frame Gap of 12, so the blocks are 74 px apart as in the mockup (42 + 4 + 16 + 12).

## Global Constraints

- Lua 5.1 code (CI runs 5.1 and 5.4): no `goto`, `//`, `table.unpack` (use `unpack or table.unpack` only in tests), integer-only APIs.
- Secret values: no arithmetic, comparison, `tostring`, `..` or boolean test on health, power, cast, aura, range or duration values from the client. They only travel to widget calls (`SetValue`, `SetFormattedText`, `SetAlphaFromBoolean`, ...). A value that may be secret and must be read (role, leader flag, dead / connected flags, range `checked`) is read only after `ns.Util.isSecret(v)` is false; else the documented fallback.
- Combat lockdown: everything that creates, shows / hides, anchors, sizes or sets attributes / state drivers on a secure frame (and on the holder, which has secure children) goes through `ns.Combat.after(key, fn)`. Keys are unique per member frame (`"unit:party:2"`), never shared by two frames.
- Taint: Blizzard frames are only hidden with `Base.hideBlizzard`; no writes into Blizzard tables.
- Files in `Core/` are pure: client calls only inside functions, never at file load; tested with `h.load`.
- Look values (colors, sizes, textures, fonts) live in `Core/Theme.lua`.
- Options: a default in the module's `defaults`, label at most 24 glyphs (English and German), a `tooltip`; read with `ns.Options.get`. A module's `apply` honors `ns.Modules.isEnabled` (off = hidden, no state driver).
- Texts go through `ns.L`; every new English key gets a German text in `Locales/deDE.lua`.
- Every unconfirmed client API: `-- UNVERIFIED (check in client)` comment plus a line in `docs/CHECKLIST.md`.
- New `.lua` file: `.toc` line and a row in the layout table of `docs/DEVELOPMENT.md`.
- Other addons are read only to learn which APIs work; no code or art is copied from them. AnotherLedger code may be copied.
- Approved art values, verbatim (APPROVED.md 3):
  - Party: vertical, 5 frames (player included), 8 px gap; frame 160 x 40, power 5; ring = the Player rule at 92% Portrait Scale (46 px); no level badge; texts 10 pt.
  - Role icon: our own glyphs (tank: blue shield, healer: green cross, damage: silver sword with red hilt) on a 15 px round badge (ring lines, panel fill) at the ring's lower left. Leader: gold crown (12 px) on top of the ring.
  - Auras: 20 px icons, 2 px gap, 6 px right of the frame, vertically centered; debuffs first, then my buffs (same icon rules as mockup 2).
  - States: out of range = whole frame at 55% opacity; dead = grey bar (0.35, 0.35, 0.35), "Dead" in grey text, empty power; offline = grey bar (0.3, 0.3, 0.3), "Offline"; dispellable debuff = 2 px edge plus 8 px glow around the frame in the debuff type color.
  - Boss: 180 x 42, power 6, mirrored like the Target, gold (elite) ring, 14 px "??" level badge, 74 px apart, cast bar 180 x 16 under each (icon left), my debuffs 22 px to the left of the frame growing leftward.
  - Glyph shapes (24 x 24 box, from `3-party-boss.html`): tank shield `M12 2 L20 5 L19 13 Q17 19 12 22 Q7 19 5 13 L4 5 Z` fill #4aa3ff, stroke #0b1a2e 1.5, center line `M12 5 V19` #cfe6ff 1.5; healer cross `M9 3 H15 V9 H21 V15 H15 V21 H9 V15 H3 V9 H9 Z` fill #46d65a, stroke #0b2410 1.5; damage blade `M18 3 L21 3 L21 6 L10 17 L7 14 Z` fill #e8e8ee, stroke #2a1010 1.2, hilt lines `M5 13 L11 19` and `M4 20 L7 17` #d24a3a 2.4 round caps; crown (24 x 18 box) `M2 16 L3 4 L8 9 L12 2 L16 9 L21 4 L22 16 Z` fill `gold`, stroke #3a2600 1.5. The glyph is drawn at 72% of the badge diameter, centered.

## Review Focus

1. **Roster changes in combat** (someone joins, leaves, goes offline, is promoted): no Lua error, nothing secure touched; frames show / hide by their drivers at once and are re-sorted when combat ends. Test in Task 6 (`"roster change in combat re-sorts after combat"`).
2. **Joining a raid / leaving the group**: the party block hides (raid), and comes back as a party; solo it is hidden outside Edit Mode. Test in Task 1 (`"party holder visibility hides in raids and solo"`) and Task 6 (`"holder gets the party driver, Edit Mode shows it"`).
3. **Secret roles, leader flags, range and dead / connected values**: role badge hidden, crown hidden, frame at full opacity unless the client's boolean picks the faded alpha. Tests in Tasks 4 and 5 run with `fakes.secret` for each.
4. **Edit Mode with nobody in the group / no boss**: both blocks visible with samples (party states shown: far, dead, dispel), draggable as one; leaving restores the drivers. Toggling Show Player in Edit Mode resizes the block. Test in Task 6 (`"edit mode samples every slot and restores drivers"`).
5. **Turning a group off and on in one combat outside Edit Mode** (the parked Plan 3 hardening): it ends up shown with its drivers. Test in Task 5 (`"off and on in one combat ends shown"`).

---

### Task 1: Pure group rules and theme values

**Files:**
- Create: `AnotherHUD/Core/GroupLayout.lua`
- Modify: `AnotherHUD/Core/UnitColor.lua`, `AnotherHUD/Core/UnitText.lua`, `AnotherHUD/Core/UnitLayout.lua`, `AnotherHUD/Core/Theme.lua`, `AnotherHUD/AnotherHUD.toc` (after `Core/UnitLayout.lua`), `docs/DEVELOPMENT.md` (layout table)
- Test: `tests/test_group_rules.lua`, `tests/test_unit_rules.lua`, `tests/test_unit_layout.lua`

**Interfaces:**
- Produces:
  - Theme: `unitColors.dead = { 0.35, 0.35, 0.35, 1 }`, `unitColors.offline = { 0.3, 0.3, 0.3, 1 }`, `unitColors.deadText = { 0.73, 0.73, 0.73, 1 }` (the mockup's #bbb); `sizes.unit` gains `roleBadge = 15, crown = 12, crownLift = 7, rangeAlpha = 0.55, rangeTick = 0.5, partyAuraGap = 6, bossAuraGap = 4, bossCastGap = 4, glow = 8, glowEdge = 2`.
  - `UnitColor.health(info)`: `info.dead == true` → `unitColors.dead`, `info.offline == true` → `unitColors.offline` (checked first, plain booleans only; dead wins).
  - `UnitText.bar`: dead / offline return `"|cffbbbbbb%s|r", { L["Dead"] }` / `{ L["Offline"] }` (the hex from `deadText`, built once from Theme at call time).
  - `UnitLayout.frame(o)` with `o.role = true`: `L.role = { size = roleBadge, cx = ring.cx - 0.33 * dia (mirrored +), cy = ring.cy + 0.33 * dia }` and `L.crown = { size = crown, cx = ring.cx, top = ring.cy - dia / 2 - crownLift }`; without `o.role` both nil.
  - `GroupLayout.order(slots, o) -> { index, ... }`: `slots` = array of `{ index, unit, role, exists }` (role `"TANK" | "HEALER" | "DAMAGER" | "NONE"` or secret / nil = `"NONE"`; `exists` plain or secret = true); `o = { sortByRole, showPlayer }`. Drops the `unit == "player"` slot when `showPlayer` is false; existing slots before missing ones; with `sortByRole` TANK, HEALER, DAMAGER, NONE within each; ties by `index`.
  - `GroupLayout.offsets(count, o) -> list, w, h`: `o = { orientation = "Vertical" | "Horizontal", growth = "Down / Right" | "Up / Left" | "Down" | "Up", w, h (block size of one member: frame plus cast bar below when on), gap }`. Returns `list[i] = { point, x, y }` relative to the holder and the holder's size. Vertical down: `TOPLEFT, 0, -(i-1)*(h+gap)`; vertical up: `BOTTOMLEFT, 0, (i-1)*(h+gap)`; horizontal right: `TOPLEFT, (i-1)*(w+gap), 0`; horizontal left: `TOPRIGHT, -(i-1)*(w+gap), 0`. Size: vertical `w, count*h + (count-1)*gap`; horizontal `count*w + (count-1)*gap, h`; `count == 0` → `w, h`.
  - `GroupLayout.partyVisibility() -> "[petbattle] hide; [group:raid] hide; [@raid1,exists] hide; [@party1,exists] show; hide"`; `GroupLayout.bossVisibility() -> "[petbattle] hide; show"`.
  - `GroupLayout.ROLES = { "TANK", "HEALER", "DAMAGER" }` (the badge textures' keys).

- [ ] **Step 1: Write the failing tests:**
  - `test_group_rules.lua`: `"order: existing first, player dropped"` (slots 0-4, party3 missing, sortByRole off, showPlayer off → `{1, 2, 4, 3}`); `"order by role with ties by index"` (roles DAMAGER, TANK, NONE, HEALER, DAMAGER at 0-4 → `{1, 3, 0, 4, 2}`); `"order: secret role and secret exists"` (secret role sorts as NONE, secret exists counts as existing); `"offsets: four directions and sizes"` (count 5, w 160, h 40, gap 8: vertical down 5th = `TOPLEFT, 0, -192`, size `160, 232`; up `BOTTOMLEFT, 0, 192`; horizontal right 5th `TOPLEFT, 672, 0`, size `832, 40`; left `TOPRIGHT, -672, 0`); `"boss blocks are 74 apart"` (h = 42 + 4 + 16, gap 12 → 2nd at `-74`); `"party holder visibility hides in raids and solo"` (exact string); `"boss visibility"`.
  - `test_unit_rules.lua`: `"dead and offline colors win"` (dead + class color → dead grey; offline → offline grey; secret dead → class color); `"dead text is grey"` (fmt `"|cffbbbbbb%s|r"`).
  - `test_unit_layout.lua`: `"party ring with role badge and crown"`: 160 x 40, ps 92, `o.role` → `ring.dia == 46`, `ring.cx == 15`, `role.cx == 15 - 0.33 * 46`, `role.cy == 20 + 0.33 * 46`, `crown.top == 20 - 23 - 7`; mirrored: `role.cx == 145 + 0.33 * 46`.
- [ ] **Step 2:** Run `lua tests/run.lua`. Expected: FAIL.
- [ ] **Step 3:** Implement; update existing tests that pinned the old dead / offline format.
- [ ] **Step 4:** Run `lua tests/run.lua` and `luacheck AnotherHUD`. Expected: PASS, no warnings.
- [ ] **Step 5: Commit** `feat: pure group layout rules, dead and offline looks`.

### Task 2: Role, crown and glow art

**Files:**
- Modify: `tools/render_units.py`, `AnotherHUD/Core/Theme.lua` (`textures`)
- Create: `AnotherHUD/Media/Units/RoleTank.tga`, `RoleHealer.tga`, `RoleDamage.tga`, `Crown.tga`, `Glow.tga`
- Test: `tests/test_unit_rules.lua` (or the existing texture test)

**Interfaces:**
- Produces: `Theme.textures.role = { TANK = ..., HEALER = ..., DAMAGER = ... }`, `Theme.textures.crown`, `Theme.textures.glow` (paths in the style of the existing `textures.disc`); `Theme.sizes.unit.glowSlice = 12` (texture slice margin in px of the 32 x 32 file).

- [ ] **Step 1: Write the failing test** `"group textures exist"`: every path in `textures.role`, `crown`, `glow` maps to a file under `AnotherHUD/Media/Units/` (same check the existing texture test does for `disc`).
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Extend `tools/render_units.py`: a polygon filler with 4 x 4 supersampling and stroke (distance to segment ≤ width / 2), quadratic segments flattened to 8 lines each, rendering the Global Constraints glyph paths in color on transparent: role glyphs 32 x 32 (box 24 scaled), crown 32 x 24. `Glow.tga` 32 x 32 white: a 2 px solid line inset 8 px from the edge (the frame edge) and outside it alpha falling from 0.75 to 0 over 8 px (smoothstep), transparent inside; the frame's middle is cut out. Run it; add the files and the Theme entries.
- [ ] **Step 4:** Run tests. Expected: PASS. Open the TGAs in an image viewer and compare with the mockup page at 300% (crown, three glyphs); note the comparison in the task report.
- [ ] **Step 5: Commit** `feat: role, crown and glow textures`.

### Task 3: Group settings section

**Files:**
- Modify: `AnotherHUD/Units/Settings.lua`, `AnotherHUD/Locales/deDE.lua`
- Test: `tests/test_unit_settings.lua`

**Interfaces:**
- Produces: builder `"Group"` with option flags in `parts`: `orientation` (party), `roles` (party). Controls in order and defaults:
  - `orientation` (only with `parts.orientation`): dropdown `"Orientation"` values `{ "Vertical", "Horizontal" }`, default `"Vertical"`, tooltip "Stack the frames on top of each other or side by side."
  - `growth`: dropdown `"Growth"`; with `parts.orientation` values `{ "Down / Right", "Up / Left" }` default `"Down / Right"`, else `{ "Down", "Up" }` default `"Down"`; tooltip "Which way new frames are added."
  - `gap`: slider `"Frame gap"` 0-40 step 1, default 8, tooltip "Space between the frames."
  - `sortByRole` (only with `parts.roles`): checkbox `"Sort by role"`, default true, tooltip "Tanks first, then healers, then damage."
  - `showPlayer` (only with `parts.roles`): checkbox `"Show player"`, default true, tooltip "Show your own frame in the group."
- German: Orientation → "Ausrichtung", Vertical → "Senkrecht", Horizontal → "Waagerecht", Growth → "Wachstum", "Down / Right" → "Unten / Rechts", "Up / Left" → "Oben / Links", Down → "Unten", Up → "Oben", "Frame gap" → "Abstand", "Sort by role" → "Nach Rolle sortieren", "Show player" → "Eigenen Rahmen zeigen", plus the tooltips.

- [ ] **Step 1: Write the failing tests:** `"group section for party"` (controls and defaults as above, in order); `"group section for boss"` (only growth Down / Up and gap); `"German group labels fit 24 glyphs"`.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: group settings section`.

### Task 4: Parts: role badge and crown, dispel glow, aura line

**Files:**
- Create: `AnotherHUD/Units/Parts/Role.lua`, `AnotherHUD/Units/Parts/Dispel.lua`
- Modify: `AnotherHUD/Units/Parts/Auras.lua`, `AnotherHUD/AnotherHUD.toc` (after `Units/Parts/Auras.lua`), `docs/DEVELOPMENT.md`, `tests/fakes.lua` (`UnitGroupRolesAssigned`, `UnitIsGroupLeader`, `UnitInRange` in `fakes.units` from fields `role`, `leader`, `inRange`, `rangeChecked`; fake textures `SetTextureSliceMargins`)
- Test: `tests/test_unit_parts.lua`

**Interfaces:**
- Consumes: `L.role`, `L.crown` (Task 1), `Theme.textures.role / crown / glow` (Task 2), `Ring`'s disc stack technique (`Units/Parts/Ring.lua`: ring lines from the skin shades, `panelTint` fill).
- Produces:
  - `Role.create(parent) -> role` with `role:layout(L, { skin })` (badge lines + fill + glyph at 72% of the badge, crown above the ring, both hidden when `L.role` is nil), `role:setRole(r)` (plain `"TANK" | "HEALER" | "DAMAGER"` shows that glyph; anything else, secret included, hides the badge), `role:setLeader(b)` (plain `true` shows the crown; else hidden), `role:setUnit(unit)` (reads `UnitGroupRolesAssigned(unit)` and `UnitIsGroupLeader(unit)` and calls the two setters).
  - `Dispel.create(parent, unit) -> dispel` with `dispel:layout()` (the glow texture reaches `Theme.sizes.unit.glow` px outside the frame on every side, slice margins `glowSlice`; the file's 2 px line then sits on the frame edge), `dispel:sample(colorOrNil)` (our own texture tinted, shown only in Edit Mode; nil hides it). The live glow: one `AuraContainer` (`CustomAuraContainerTemplate`, created at login as in `Auras`) with `AddAuraSlot("dispel", "HARMFUL|RAID", { initializeFrame = ... })` whose button covers the frame, takes no mouse, and gets our glow texture through `AddDispelTypeTexture(tex, { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset, showWhenHarmful = true, showWhenHelpful = false })`. Every call `pcall`ed; without the template / slot API nothing shows and nothing errors (`available` false). UNVERIFIED: `AddAuraSlot`, the `HARMFUL|RAID` filter (debuffs I can dispel), `PreserveAsset` tinting a white texture, `SetTextureSliceMargins`.
  - `Auras.create(parent, unit, mode)`: `mode` `"rows"` (default, Plan 3 behavior) or `"line"`: one container holding `debuffMine`, `debuffOther`, `buffMine` in that order (no other players' buffs), one clip frame; `layout(opts)` sizes it to `rows` lines of `width`; `sample` shows the placeholders in one line (debuffs first). Plan 3 callers unchanged.

- [ ] **Step 1: Write the failing tests:** `"role badge shows plain roles only"` (TANK / HEALER / DAMAGER set the matching texture and show; `"NONE"`, nil and `fakes.secret("TANK")` hide); `"crown only for a plain leader"`; `"role and crown hidden without L.role"`; `"dispel slot uses the raid filter and our glow"` (fake container records `AddAuraSlot` key / filter; `initializeFrame` on a fake button calls `AddDispelTypeTexture` with our texture and `showWhenHarmful = true`); `"dispel without the template does nothing"`; `"dispel sample tints and hides"`; `"aura line holds debuffs then my buffs"` (group keys and filters in order, no `buffOther`); `"aura line samples in one row"`.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement the parts and fakes; CHECKLIST lines come in Task 8.
- [ ] **Step 4:** Run tests and luacheck. Expected: PASS.
- [ ] **Step 5: Commit** `feat: role badge, leader crown, dispel glow and aura line parts`.

### Task 5: Base learns member frames

**Files:**
- Modify: `AnotherHUD/Units/Base.lua`, `AnotherHUD/Units/Define.lua` (only if a signature changes)
- Test: `tests/test_unit_base.lua`

**Interfaces:**
- Consumes: Task 1 rules, Task 4 parts.
- Produces:
  - `Base.create(spec, o)` takes the Plan 3 fields plus: `key` (combat key and event identity, default `spec.id`), `parent` (default `UIParent`), `member` (true: `spec.frame` is not set; the caller keeps the frame), `sample` (function(frame) → `{ name, class, role, leader, dead, offline, far, dispel (debuff kind), healthPct }` or nil; nil = the Plan 3 sample), `castGap` (px between frame and cast bar; default `L.below`), `auraMode` (`"rows" | "line"`), `auraSide` (nil = below as Plan 3; `"right"`: aura frame `LEFT` at the frame's `RIGHT` + `partyAuraGap`, vertically centered; `"left"`: `RIGHT` at `LEFT` − `bossAuraGap`, centered, growing left), `range` (fade out of range), `role` (role badge, crown, `L.role` in the layout), `dispel` (dispel glow). Every combat key uses `frame.key`: `"unit:" .. key`, `":edit"`, `":cast"`, `":init"`.
  - `Base.applyFrame(frame)` and `Base.editModeFrame(frame, active)`: the Plan 3 bodies on one frame; `Base.apply(spec)` / `Base.editMode(spec, active)` call them on `spec.frame` (Plan 3 behavior and tests unchanged). `frame.slotOn` (default true): false hides the frame like a turned-off module (the group's Show Player off).
  - Hardening (BACKLOG, Plan 3 review): `applyFrame` on an enabled frame outside Edit Mode first queues a no-op under `"unit:" .. key .. ":edit"`, so an earlier queued turn-off can't hide the frame after the apply.
  - Change events: units `party1`-`party4` and the player in a group register `GROUP_ROSTER_UPDATE`; `boss1`-`boss5` register `INSTANCE_ENCOUNTER_ENGAGE_UNIT` and `UNIT_TARGETABLE_CHANGED` (unit event). Frames with `role` also take `PLAYER_ROLES_ASSIGNED`, `PARTY_LEADER_CHANGED`, `GROUP_ROSTER_UPDATE` → `role:setUnit`.
  - Dead (plain true): health color dead grey, `bars:setPower(0, 1)`. Offline: offline grey.
  - `Base.fade(frame)`: with `frame.range`, a unit that is not the player, outside Edit Mode: `inRange, checked = UnitInRange(unit)`; `checked` plain false → `SetAlpha(a)`; else `SetAlphaFromBoolean(inRange, a, a * rangeAlpha)` (pcall; on failure `SetAlpha(a)`). In Edit Mode a sample with `far` → `SetAlpha(a * rangeAlpha)`. `a` is the `UnitState.alpha` value.
  - Sample: with `o.sample`, the frame shows that member (name, class color via `UnitColor.health{ isPlayer = true, class }`, dead / offline looks, role, crown, dispel sample color, `healthPct` as the bar value and percent text), else Plan 3's.

- [ ] **Step 1: Write the failing tests** (Plan 3 tests stay green unchanged): `"member frames keep their own combat keys"` (two members of one spec, both queued in combat, both laid out after `PLAYER_REGEN_ENABLED`); `"member frame does not take spec.frame"`; `"off and on in one combat ends shown"` (toggle off, toggle on, flush → shown, driver registered); `"party member registers roster and role events"`; `"boss member registers encounter events"`; `"range: secret inRange goes to SetAlphaFromBoolean"` (`_alphaFrom[1]` is the very secret); `"range: unchecked is full alpha"`; `"range never fades the player"`; `"dead member: grey bar, empty power"`; `"secret dead flag keeps class color"`; `"sample member shows its state"` (far → alpha × 0.55; dead → grey and Dead text; role badge; crown; dispel sample); `"auras on the side"` (right: anchor `LEFT`, frame, `RIGHT`, 6, 0; left: `RIGHT`, frame, `LEFT`, -4, 0); `"cast gap override"` (castGap 4 → cast bar 4 px under the frame).
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run tests and luacheck. Expected: PASS.
- [ ] **Step 5: Commit** `refactor: unit base builds member frames for groups`.

### Task 6: The group helper

**Files:**
- Create: `AnotherHUD/Units/Group.lua`
- Modify: `AnotherHUD/AnotherHUD.toc` (after `Units/Define.lua`), `docs/DEVELOPMENT.md`
- Test: `tests/test_group.lua`

**Interfaces:**
- Consumes: `GroupLayout` (Task 1), `Settings.build` with `"Group"` (Task 3), `Base.create{ member = true, ... }`, `Base.applyFrame`, `Base.editModeFrame` (Task 5).
- Produces: `ns.Units.defineGroup(o) -> spec` with `o = { id, label, name (holder's global name; members get name .. i), units (array of tokens in slot order), visibility (function → driver string for the holder), mirror, castBar, auras, auraMode, auraSide, castGap, badge, range, role, dispel, roles (sort and Show Player apply), samples (array, one per slot, the Task 5 sample tables), parts, defaults, blizzard, defaultPosition }`. It calls `ns.Modules.define{ kind = "unit", ... }` with:
  - `create`: a plain `Frame` holder on `UIParent` (`spec.frame`), one member per unit (`Base.create(spec, { member = true, parent = holder, key = id .. ":" .. i, unit = units[i], sample = function() return samples[i] end, ... })`), then `apply`, then `Base.hideBlizzard(blizzard)`; events on the holder: `GROUP_ROSTER_UPDATE`, `PLAYER_ROLES_ASSIGNED` (with `roles`) → `Combat.after("group:" .. id .. ":order", place)`; a holder `OnUpdate` every `rangeTick` s calling `Base.fade` on shown members (with `range`).
  - `place`: `GroupLayout.order` (slots from `UnitExists` and `UnitGroupRolesAssigned`; in Edit Mode all slots exist and keep their index order), member `slotOn` (`showPlayer` for the player slot), `GroupLayout.offsets` with block height `height + (castOn and castGap + castHeight or 0)` and the `gap` option; members re-anchored to the holder, holder sized; all inside `Combat.after("group:" .. id .. ":order")`.
  - `apply`: honors `isEnabled` (off: every member off, holder driver gone and holder hidden); else every member `Base.applyFrame`, `place`, holder driver `o.visibility()` (outside Edit Mode) through `Combat.after("group:" .. id)`.
  - `onEditMode(spec, active)`: holder shown without driver while open (driver back on close), every member `Base.editModeFrame`, `place`.
- Party sample members (slot order, from the mockup): Arthelis PALADIN TANK leader 84%; Lunaria PRIEST HEALER 97%; Brakka WARRIOR DAMAGER 41% dispel Magic; Ssylith MAGE DAMAGER 66% far; Torvald HUNTER DAMAGER dead. Boss samples: Vyrastra 62%, Ironmaw 88%, The Hollow King 31%, Grimscale 54%, Sister Vexa 77% (hostile color, "??" level).

- [ ] **Step 1: Write the failing tests:** `"holder is the Edit Mode frame, members are its children"`; `"holder gets the party driver, Edit Mode shows it"`; `"members sorted by role after roster change"`; `"roster change in combat re-sorts after combat"`; `"show player off hides the player slot and shrinks the block"`; `"growth and orientation move the members"`; `"boss blocks include the cast bar"` (2nd boss at y −74 with defaults); `"group off hides holder and members"`; `"edit mode samples every slot and restores drivers"`; `"range ticker fades shown members"`.
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run tests and luacheck. Expected: PASS.
- [ ] **Step 5: Commit** `feat: group helper for party and boss frames`.

### Task 7: Party and Boss modules

**Files:**
- Create: `AnotherHUD/Units/Party.lua`, `AnotherHUD/Units/Boss.lua`
- Modify: `AnotherHUD/AnotherHUD.toc` (after `Units/Pet.lua`), `AnotherHUD/Locales/deDE.lua` ("Party" → "Gruppe", "Boss" → "Boss"), `docs/DEVELOPMENT.md` (layout table rows replace "planned"), `tests/test_checklist.lua` (`lem.frames` 6 → 8)
- Test: `tests/test_units.lua`

**Interfaces:**
- Party: `defineGroup{ id = "party", label = "Party", name = "AnotherHUDParty", units = { "player", "party1", "party2", "party3", "party4" }, visibility = GroupLayout.partyVisibility, auras = true, auraMode = "line", auraSide = "right", range = true, role = true, dispel = true, roles = true, parts = { "Group", "Size", "Text", "Look", "Behaviour", "Auras", "Fading", orientation = true, roles = true, portrait = true, power = true }, defaults = { width = 160, height = 40, portraitScale = 92, powerHeight = 5, fontSize = 10, healthText = "Percent", powerText = "None", auraSize = 20 }, blizzard = { "PartyFrame", "CompactPartyFrame" }, defaultPosition = { point = "LEFT", x = 40, y = 120 } }`.
- Boss: `defineGroup{ id = "boss", label = "Boss", name = "AnotherHUDBoss", units = { "boss1", ..., "boss5" }, visibility = GroupLayout.bossVisibility, mirror = true, castBar = true, castGap = bossCastGap, auras = true, auraSide = "left", badge = focusBadge, parts = { "Group", "Size", "Text", "Look", "Cast Bar", "Auras", portrait = true, power = true }, defaults = { width = 180, height = 42, powerHeight = 6, fontSize = 10, healthText = "Percent", powerText = "None", castWidth = 180, castHeight = 16, buffs = false, onlyMine = true, gap = 12 }, blizzard = { "BossTargetFrameContainer" }, defaultPosition = { point = "RIGHT", x = -120, y = 120 } }`.

- [ ] **Step 1: Write the failing tests:** `"party and boss register with Edit Mode"` (Core.init with a fake LibEditMode: 8 frames, holders named `AnotherHUDParty` / `AnotherHUDBoss`); `"party hides both Blizzard party frames"`; `"boss hides the Blizzard boss container"`; `"every module's apply honors isEnabled"` (after Core.init, for every module with a frame: off + apply + flush → frame hidden, no visibility driver; on again → shown or driven; the parked Plan 3 contract test); `"party panel sections in spec order"` (Group, Size, Text, Look, Behaviour, Auras, Fading); `"boss panel sections"` (Group, Size, Text, Look, Cast Bar, Auras).
- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run tests and luacheck. Expected: PASS.
- [ ] **Step 5: Commit** `feat: party and boss frames`.

### Task 8: Docs

**Files:**
- Modify: `README.md`, `CHANGELOG.md`, `docs/CHECKLIST.md`, `docs/DEVELOPMENT.md`, `docs/BACKLOG.md`, `CLAUDE.md`

- [ ] **Step 1:** README: Party and Boss in the unit frames section (what shows, the Group settings, hidden in raids, Edit Mode samples), no API names / texture paths / pixel sizes. CHANGELOG Unreleased: one bullet each for Party, Boss, dead / offline grey texts.
- [ ] **Step 2:** CHECKLIST "Group frames (Plan 4)" block: every UNVERIFIED from Tasks 4-7 (`AddAuraSlot`, `HARMFUL|RAID`, `PreserveAsset`, `SetTextureSliceMargins`, `UnitInRange` secret pair with `SetAlphaFromBoolean`, `UnitGroupRolesAssigned` / `UnitIsGroupLeader` plain or secret, `INSTANCE_ENCOUNTER_ENGAGE_UNIT` / `UNIT_TARGETABLE_CHANGED`, the `[group:raid]` driver, hiding `PartyFrame` / `CompactPartyFrame` / `BossTargetFrameContainer` with no taint and no reappearing after a layout switch or "raid-style party frames" toggle), plus play checks: join / leave a party, a raid hides the block, role and leader changes, someone going offline, out of range at about 40 yards, a dispellable debuff on a member, a boss encounter with casts and my debuffs, sort by role after a fight in which someone joined.
- [ ] **Step 3:** DEVELOPMENT: member frames and combat keys, the group helper, the fixed-frames call and its cost. BACKLOG: raid target icon; remove the two Plan 3 hardening lines that Tasks 5 and 7 did. CLAUDE.md status line: Plan 4 built, client check next, then Bars (Plan 5).
- [ ] **Step 4:** Run tests and luacheck. Expected: PASS.
- [ ] **Step 5: Commit** `docs: party and boss frames`.

### Task 9: Finish

- [ ] **Step 1:** Full run: `lua tests/run.lua`, `luacheck AnotherHUD`.
- [ ] **Step 2:** Push the branch, open the MR, CI `test` and `lint` green.
- [ ] **Step 3:** Ask the player to run the client checks (other party and boss frame addons off for the test); record the results in `CHECKLIST.md`.
- [ ] **Step 4:** Merge once the player is happy.
