# AnotherHUD

AnotherHUD replaces the default unit frames of WoW Forever with its own, and plugs them into Blizzard's Edit Mode so you can move and size them the usual way. It is part of a small suite of addons together with AnotherLedger; action bars will come in a separate addon of the suite.

**Status: in development.** There is nothing to install yet.

## Unit frames

AnotherHUD draws seven unit frames and hides Blizzard's in their place. Turn single frames off in the AnotherHUD box to the right of the Edit Mode window: the frame goes away at once and stays away until you turn it back on. Getting Blizzard's frame back in its place needs a /reload.

| Frame | Shows | Replaces |
| --- | --- | --- |
| Player | portrait ring, health and power bars with texts, buffs and debuffs, cast bar | Blizzard's Player frame and cast bar |
| Target | the same for your target, with the cast bar and the auras that matter to you | Blizzard's Target frame |
| Target of Target | a compact frame for your target's target | Blizzard's Target of Target |
| Focus | like Target, for your focus | Blizzard's Focus frame |
| Pet | the pet's health, power and auras | Blizzard's Pet frame |
| Party | you and your party members in one block, each with a role badge, a crown for the leader, a glow when a debuff you can dispel is on them, and a faded look when they are out of range | Blizzard's party frames |
| Boss | the bosses of an encounter, mirrored, each with its cast bar and your debuffs on it | Blizzard's boss frames |

Move every frame in Edit Mode: with Edit Mode open each one shows sample data, so you can place it without a target. Click a frame to open its settings panel. The sections are:

- **Group** (Party and Boss): how the frames are stacked (vertical or horizontal), which way new frames are added and the gap between them; stacked horizontally, each party member's auras sit under its frame instead of beside it; Party also has Sort by role (tanks, then healers, then damage) and Show player.
- **Size**: width and height, portrait scale and power bar height.
- **Text**: what the name, health and power texts show, and the text size.
- **Look**: skin, class colors and bar texture.
- **Behaviour**: whether the frame also shows in a vehicle.
- **Cast Bar**: show it, its size, the spell icon, and (Player only) Detach cast bar.
- **Resource Bar** (Player only): show it, Detach resource bar, its size when detached, and the recharge timers.
- **Auras**: buffs, debuffs, icon size, rows, and only your own auras.
- **Fading**: opacity out of combat and showing fully on mouseover.

Not every frame has every section; a section only appears where it makes sense. The Player's cast bar can be detached ("Detach cast bar" in the Cast Bar section) and then moves as its own frame, "Player Cast Bar". Left off, it hangs under the Player frame.

## Class resources

The Player frame brings a class resource bar: combo points (Rogue, and Druid in Cat Form), holy power (Paladin), runes in the color of your spec (Death Knight), soul shards with the next shard filling up (Warlock), chi (Windwalker Monk), arcane charges (Arcane Mage) and essence (Evoker). Classes and specs without one of these get no bar. It sits right under the Player frame, next to the portrait, and the cast bar and auras move down to make room. Turn on "Detach resource bar" in the Resource Bar section to move it as its own frame, "Player Resource Bar", with its own width and height. Recharging runes and the regenerating essence show the seconds left on their segment; turn that off with "Show recharge timers". In Edit Mode the bar shows a sample.

Party shows while you are in a party and hides in a raid; Boss shows while a boss encounter has boss units. In Edit Mode both show sample frames so you can place the whole block. Someone who joins your party in a fight appears in the next free place and is sorted when combat ends.

Dead and offline units show a grey bar and grey text on every unit frame (Target, Focus, Target of Target and Pet included).

Target, Target of Target and Focus only show while you have that unit, and Pet only while you have a pet; right click opens the unit menu, and hovering shows the tooltip.

## XP and reputation

A bar at the bottom of the screen shows your experience while you can still gain XP (not at the level cap, not with XP gain turned off), with your rested XP as a lighter band ahead of it, and the reputation of the faction you watch in its standing's color. With both, XP is on top. Watch a faction in the reputation pane and its bar appears at once; reach the level cap and the XP bar goes away. With nothing to show the bar hides. Turn on "Show honor" in the Behaviour section for a third bar under them with your honor and honor level. Out of combat, a click on the reputation bar opens the reputation pane and a click on the honor bar opens the PvP pane.

The numbers (level, XP and percent, rested XP; faction, standing and progress; honor level and honor) show while the mouse is over the bar; "Show text" in the Text section makes them show always or never. In Edit Mode the bar shows a sample of both, so you can move it, and its panel sets the width, bar height, text size, skin, bar texture, which bars to show and the fading. It replaces Blizzard's experience and reputation bars; turned off in the AnotherHUD box, Blizzard's come back after a /reload.

## Minimap

The minimap sits in an AnotherHUD frame at the top right of the screen, in the same skin as the unit frames. "Shape" in the Look section makes it square (inside the skin's border) or round, and "Map size" sets its size. The mouse wheel over the map zooms in and out; turn "Mouse wheel zoom" off in the Behaviour section and the wheel does nothing there. Move it in Edit Mode like the other frames.

For now Blizzard's mail, tracking, clock, calendar and zone name around the map are hidden with Blizzard's minimap border; they come back on the AnotherHUD map in the next step. Turned off in the AnotherHUD box, Blizzard's minimap comes back after a /reload.

## Known gaps

- Totems and the extra power bar of some fights are not shown while the AnotherHUD Player frame is on. Totems come back with the suite's action bar addon.
