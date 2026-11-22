# AnotherHUD backlog

Ideas not built yet.

- Raid frames.
- Resource bar and totem bar (Plan 6): they replace what hiding `PlayerFrame` removes (class
  resources, totem bar, alternate power bar).
- Evoker empowered casts on the cast bar.
- Party Style.
- Pets & Targets.
- Shared "Another" suite core (code shared with AnotherLedger and the minimap addon).
- Hardening before a second way to turn frames on/off (Settings window, profile switch):
  `Base.apply` should also replace the queued `unit:<id>:edit` work when not editing, and a
  test should pin that every module's `apply` honors `Modules.isEnabled`.
- Turned-off unit frames could unregister their events.
