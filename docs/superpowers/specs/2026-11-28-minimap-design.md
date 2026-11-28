# Minimap (AnotherHUD)

Design, 2026-11-28. The minimap is part of AnotherHUD (decided 2026-11-28,
no separate addon). Look: `docs/mockups/7-minimap.html`, approved 2026-11-28
(`docs/mockups/APPROVED.md` section 7).

## Intent

The player wants the minimap in the suite's look, like the unit frames, and
a tidy map edge: every addon's minimap button goes into one container
button instead of sitting around the map, so the map's shape no longer
matters to those buttons.

## Goals

- An AnotherHUD minimap frame with its own Edit Mode entry and settings
  panel (like the unit frames), holding Blizzard's map.
- **Shape** setting: Square (the map fills the skin panel) or Round (the map
  masked to a circle inside the skin ring). Skins: Classic, Forge, Slate.
- Around the map (approved mockup):
  - above: zone name in the zone's PvP color;
  - on the map: mail (top left) and dungeon queue (top right), only when
    needed; the addon container (bottom left); tracking (bottom right).
    Inside the corners on Square, on the rim on Round;
  - below: clock and a calendar button (with Blizzard's pending-invite
    signal); coordinates under them, off by default.
- Each element can be turned off on its own.
- **Zoom:** no zoom buttons. A "Mouse wheel zoom" setting (on by default)
  lets the wheel over the map zoom in and out.
- **Container:** one button; a click opens a skinned panel left of the map
  with every addon minimap button (AnotherLedger's included), 4 per row. A
  second click, a click elsewhere or a click on one of its buttons closes
  it. Buttons are collected automatically; the player never sorts them.

## Non-goals

- No new map rendering (the client draws the minimap only in Blizzard's
  `Minimap` frame).
- No world map changes, no minimap tracking logic of our own.
- No Gilded skin (removed from all Another addons on 2026-11-28).
- No zoom buttons.

## Anti-goals

- Taint: opening Edit Mode, switching layouts, entering combat or queueing
  from the map's queue button must not produce a blocked-action message or
  a taint line from AnotherHUD.
- An addon button lost: an addon's minimap button that ends up neither in
  the container nor visible is a failure.
- A map that stays black, mis-masked or unclickable after a /reload, a zone
  change or a layout switch.

## Constraints

- Lua 5.1, WoW Forever (Interface 16001); tests in plain Lua with fakes;
  luacheck clean; secret-value rules (coordinates are client numbers: only
  formatted when plain).
- Combat lockdown: the map and its buttons are not secure frames, but
  Blizzard's are touched (reparenting, hiding): all of that out of combat
  through `ns.Combat.after`.
- Taint rules: never write to Blizzard tables; hide Blizzard art by
  reparenting to a hidden frame; `hooksecurefunc` for Blizzard re-layouts.
- Look values in `Core/Theme.lua`; texts through `ns.L` with German.
- Every unconfirmed client API gets `UNVERIFIED (check in client)` and a
  CHECKLIST line.

## Approaches

1. **Move Blizzard's map into an AnotherHUD frame (picked by the player).**
   Our frame (LibEditMode, our settings panel) holds Blizzard's `Minimap`
   and its working buttons; Blizzard's cluster art, zone text and clock are
   hidden; a mask texture gives the shape; the skin border goes around it.
   Same pattern as the unit frames. Risk: taint, because Blizzard's minimap
   cluster is an Edit Mode system; checked in the client first (a spike).
2. Restyle Blizzard's minimap in place. Less work at first, but Blizzard's
   layout code keeps moving its parts back, its round art fights the square
   shape, and the settings would live in Blizzard's panel. Dropped.
3. Draw a map of our own. Not possible (no API renders the minimap
   elsewhere). Dropped.

## The design

### Frames

- `AnotherHUDMinimap`: plain frame on `UIParent`, the Edit Mode frame
  (module `minimap`, kind `"frame"`, listed in the checklist box), default
  position top right of the screen, default size 180 x 180 (a Size slider).
- Blizzard's `Minimap` is reparented into it out of combat, anchored to the
  inner rect (inside the skin border), and sized with it. Its mask:
  a square mask for Square, a round mask for Round
  (`Minimap:SetMaskTexture`). UNVERIFIED (check in client).
- `GetMinimapShape()` global answers "SQUARE" or "ROUND" so libraries that
  ask for the shape place buttons right. Only defined when no other addon
  defined it. UNVERIFIED (check in client).
- Blizzard's `MinimapCluster` (border, zone text, header, clock, zoom
  buttons, expansion button) is hidden the same way as Blizzard's unit
  frames (`Base.hideBlizzard`), out of combat, with re-hide hooks.

### Elements

- Zone name: own font string, text from `GetMinimapZoneText()`, color from
  `C_PvP.GetZonePVPInfo()` / `GetZonePVPInfo()` mapped to Theme colors;
  updates on `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`,
  `ZONE_CHANGED_NEW_AREA`. A click opens the world map (as Blizzard's
  zone button does) — builder's call whether to keep this.
- Clock: own font string, local or realm time and 24 h / 12 h from
  Blizzard's clock settings (`GetCVarBool("timeMgrUseLocalTime")`,
  `"timeMgrUseMilitaryTime"`), updated once a second by a ticker; a click
  opens Blizzard's time manager.
- Calendar: Blizzard's `GameTimeFrame` moved below the map in the badge
  look, or an own badge calling `ToggleCalendar()` with the pending-invite
  glow from `C_Calendar.GetNumPendingInvites()`. Builder's call after the
  spike.
- Mail, tracking, queue: Blizzard's own buttons (they carry their menus and
  tooltips) re-parented onto our frame and re-skinned in the badge look.
  Mail and queue show only when Blizzard shows them. The queue button may
  live outside the minimap cluster on this client; if so it stays where
  Blizzard puts it and the badge slot stays empty. UNVERIFIED.
- Coordinates: `C_Map.GetBestMapForUnit("player")` and
  `C_Map.GetPlayerMapPosition`, formatted "42.1, 65.8" when plain, empty in
  instances; a ticker while shown.
- Settings per element: Zone name, Clock, Calendar, Mail, Queue, Tracking,
  Coordinates (off), Addon container.

### Container

- A badge button bottom left. A click toggles a skinned panel left of the
  map (approved layout: 26 px round buttons with the ring, 4 per row, 4 px
  gaps, panel padding 4).
- Collection: every child of `Minimap` (and of `MinimapBackdrop`, if it
  exists) that is a button and not Blizzard's own is taken into the panel,
  at login and again later (a short re-scan after `PLAYER_ENTERING_WORLD`
  and when LibDBIcon reports a new button through its callback if it is
  present). A button that is hidden by its addon stays hidden in the panel.
- While collected, a button's own dragging around the map is turned off
  (its `OnDragStart` / `OnDragStop` scripts saved and cleared) and it is
  anchored in the grid; it is never written into Blizzard tables.
- Blizzard's own addon compartment button, if this client has one, is
  hidden; addons registered only in the compartment are out of scope.
- Closing: a second click on the container, a click on one of its buttons,
  or a click elsewhere (a full-screen catcher frame below the panel).

### Zoom

- Mouse wheel zoom (default on): `OnMouseWheel` on the map calls
  `Minimap:SetZoom` within `0..GetZoomLevels() - 1`. Off: the wheel does
  nothing over the map. UNVERIFIED.

### Settings panel

Sections: Size (map size), Look (Skin: Classic / Forge / Slate; Shape:
Square / Round), Elements (one checkbox each, as above), Behaviour (Mouse
wheel zoom). Labels of 24 characters at most, tooltips, German texts.

### Order of the work

1. **Spike (client check first):** reparent `Minimap` into our frame, mask
   square / round, hide `MinimapCluster`; the player checks in the game
   that there is no taint in Edit Mode, layout switches, combat and queueing.
2. Frame, shape, skin, zone name, clock, calendar, coordinates, settings.
3. Mail, queue, tracking re-skinned on the map.
4. The addon container.

Each is its own plan task (or plan); later steps wait for the spike result.
The spike is a hard gate (the player's decision, 2026-11-28): if moving
Blizzard's map taints, work stops and the design is rethought with the
player; there is no automatic fallback to restyling in place.

## Calls made after the builder check (correct if wrong)

- **Blizzard re-layouts:** `Minimap` is reparented once and kept there by
  `hooksecurefunc` on its `SetParent` / `SetPoint` (re-anchored out of combat
  through `ns.Combat.after`), like the cast bar's `SetParent` hook. Blizzard's
  Edit Mode keeps its (now empty, hidden) Minimap entry; we ignore it.
- **Mail, tracking, queue:** first try Blizzard's own buttons re-parented
  with the same re-anchor hooks (menus and tooltips come free). If the spike
  shows Blizzard re-anchoring them every refresh or any taint, build own
  badges that mirror Blizzard's state instead (event-driven show / hide, a
  click opening the same menu).
- **Which buttons the container takes:** children of `Minimap` (and
  `MinimapBackdrop`) that are buttons and not Blizzard's, plus every button
  LibDBIcon knows (`LibDBIcon` objects, when that library is loaded), plus
  buttons anchored to `Minimap` but parented elsewhere. A frame we can't
  recognise is left where its addon put it (never hidden), so no button is
  lost. Grid order: alphabetical by the button's name, stable across
  re-scans.
- **Frame bounds and size:** the Edit Mode frame is the map only; zone
  name, clock, calendar and coordinates hang outside it at the approved
  places. The Size slider sizes the map; texts and badges keep their size.
- **Masks:** no new art. Square uses a plain white texture
  (`Interface\Buttons\WHITE8x8`), Round Blizzard's round minimap mask
  (`Textures\MinimapMask`). UNVERIFIED (check in client).
- **`GetMinimapShape`:** defined at `PLAYER_LOGIN` only when it is still nil;
  it reads the Shape setting on every call, so a change applies at once.

## Left to the builder

- Exact Blizzard frame names on this client (found by the spike and noted
  in DEVELOPMENT / CHECKLIST).
- Whether the calendar and the zone click reuse Blizzard's buttons or own
  badges.
- How LibDBIcon (if loaded by another addon) is told about the collection.
- Tests: rules in a `Core/` file (coordinate text, zone colors, the
  container grid layout, which children count as addon buttons) tested
  with `h.load`; the module with fakes like the other modules.
