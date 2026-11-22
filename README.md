# AnotherHUD

AnotherHUD replaces the default unit frames and action bars of WoW Forever with its own, and plugs them into Blizzard's Edit Mode so you can move and size them the usual way. It is part of a small suite of addons together with AnotherLedger.

**Status: in development.** There is nothing to install yet.

## Unit frames

AnotherHUD draws five unit frames and hides Blizzard's in their place. Turn single frames off in the AnotherHUD box under the Edit Mode window; turning one back to Blizzard's needs a /reload.

| Frame | Shows | Replaces |
| --- | --- | --- |
| Player | portrait ring, health and power bars with texts, buffs and debuffs, cast bar | Blizzard's Player frame and cast bar |
| Target | the same for your target, with the cast bar and the auras that matter to you | Blizzard's Target frame |
| Target of Target | a compact frame for your target's target | Blizzard's Target of Target |
| Focus | like Target, for your focus | Blizzard's Focus frame |
| Pet | the pet's health, power and auras | Blizzard's Pet frame |

Move every frame in Edit Mode: with Edit Mode open each one shows sample data, so you can place it without a target. Click a frame to open its settings panel. The sections are:

- **Size**: width and height.
- **Text**: what the name, health and power texts show, and the text size.
- **Look**: skin, class colors and bar texture.
- **Behaviour**: whether the frame also shows in a vehicle.
- **Cast Bar**: show it, its size, the spell icon, and (Player only) Detach cast bar.
- **Auras**: buffs, debuffs, icon size, rows, and only your own auras.
- **Fading**: opacity out of combat and showing fully on mouseover.

Not every frame has every section; a section only appears where it makes sense. The Player's cast bar can be detached ("Detach cast bar" in the Cast Bar section) and then moves as its own frame, "Player Cast Bar". Left off, it hangs under the Player frame.

Target, Target of Target and Focus only show while you have that unit; right click opens the unit menu, and hovering shows the tooltip.
