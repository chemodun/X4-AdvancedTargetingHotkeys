# Advanced Targeting Hotkeys

Filtered target acquisition for X4: Foundations, bindable through the native game keybinding UI. Pick the nearest enemy, incoming missile, own ship, station, gate, collectable, asteroid or surface element, then cycle **only within that category** instead of through everything in the sector.

Built on the [Native Hotkey API](https://www.nexusmods.com/x4foundations/mods/2181). No external process, no pipe server.

## Overview

Vanilla gives you "Next Target" and "Previous Target", and they cycle through every object around you. That is fine until you are in a fight next to a station, where getting back to the fighter that is shooting at you means pressing the key past a dozen storage modules and a lockbox.

This mod adds a **sticky filter**. Every acquisition hotkey does two things: it targets the nearest matching object, and it remembers what kind of thing you asked for. From then on Next/Previous only walk that category. Press "Target Nearest Enemy" and Next cycles enemies. Press "Target Nearest Station" and Next cycles stations. Press "Target Turret on Selected Object" and Next walks the turrets of the hull you are attacking, which is what you actually want while preparing a boarding operation.

The filter is dropped again the moment you change target by any other means: a mouse click, one of the vanilla targeting keys, or the target leaving the sector. Next/Previous then go back to cycling everything, exactly as they do in vanilla. Nothing gets stuck.

### When your target goes away

Losing a target is the one case where the filter is *not* dropped. In the categories where you are working through a list of things - enemies of any size, incoming missiles, collectables, and all four surface-element filters - the mod picks up where you left off instead:

- **The next one is selected automatically**, and "next" means the entry that followed the one you lost, not merely the closest one. Strip a hull of turrets, clear a wing of fighters, or fly through a field of dropped containers without touching the acquisition key again.
- **Collectables count as lost when they are collected**, not only when they are shot, so chain-collecting drops works the same way.
- **Running out of one type** of surface element (say, the last engine) widens the filter to the remaining surface elements of that same hull rather than dumping you back out to free targeting.
- **A hull stripped bare** hands you the hull itself.
- When the category is genuinely empty, **nothing happens at all** - no sound, no message, and your target is left alone. This is a reaction to something dying, not to a key press, so it stays quiet.

Navigation categories - your own ships, stations, gates, asteroids, mission targets - deliberately do *not* do this. Having a station silently swapped for another one because the first blew up would be surprising rather than helpful.

## Requirements

- **X4: Foundations** version **8.00** or higher.
- **Native Hotkey API** version **8.00.07** or higher, which in turn requires **UI Extensions and HUD** by [kuertee](https://next.nexusmods.com/profile/kuertee?gameId=2659). It also hosts this mod's own settings and its debug-logging switch, so there is nothing else to install for those.
- **Print Extension List** version **1.00** or higher. It writes the game version and the full list of enabled DLCs and extensions to the debug log at startup, so any log you send with a bug report already identifies exactly what you were running.

## Hotkeys

All 19 actions are **pilot-area**: they fire while you are at the controls of a ship with no menu open. None of them come bound to a key. Assign the ones you want under **Options > Hotkey Management > Hotkey Bindings**.

### Acquisition

Each of these targets the nearest match and switches the filter to that category.

| Hotkey | What it picks |
|---|---|
| Target Nearest Enemy | Nearest hostile ship, drone, mine, missile or explosive |
| Target Nearest Enemy \(XS-M\) | Nearest hostile fighter-class or medium ship |
| Target Nearest Enemy \(L-XL\) | Nearest hostile capital ship |
| Target Nearest Incoming Missile | Nearest missile actually aimed at you, so you can shoot it down |
| Target Nearest Own Ship | Nearest ship you own, excluding the one you are flying |
| Target Nearest Own Ship for Landing | Nearest ship you own with a docking bay that fits your current hull, for when you need somewhere to run to |
| Target Nearest Station | Nearest known station |
| Target Nearest Gate | Nearest known gate, accelerator or highway entry |
| Target Nearest Collectable | Nearest known dropped ware or lockbox |
| Target Nearest Asteroid | Nearest known asteroid, for manual mining |
| Target Surface Element on Selected Object | Nearest working surface element of the ship or station you have selected |
| Target Engine on Selected Object | Same, restricted to engines |
| Target Turret on Selected Object | Same, restricted to turrets and launchers |
| Target Shield Generator on Selected Object | Same, restricted to shield generators |
| Target Active Mission Object | The object your current mission points at |

These four are named after what they actually do: they work on the object **you have selected**, and on nothing else. Select a carrier across the sector and "Target Turret on Selected Object" gives you that carrier's turrets, not the turrets of the fighter next to you. If a surface element is already selected, they stay on the same hull, and so does Next/Previous. With nothing selected they use the last hull you worked on; with nothing selected and no previous hull they do nothing at all and tell you so, rather than grabbing a turret off whatever happens to be closest. Docked ships are never included either, so cycling a carrier's turrets will not wander into the fighters sitting in its bays.

### Navigation

| Hotkey | What it does |
|---|---|
| Select Next Target \(Filtered\) | Next object in the active filter, by distance, wrapping around |
| Select Previous Target \(Filtered\) | Previous object. With no target selected, starts from the farthest one |
| Deselect Target and Reset Filter | Clears the target **and** the filter |
| Target Along Line of Sight | Picks whatever you are looking at |

**Target Along Line of Sight** starts from a one-degree cone dead ahead and widens in steps to 25 degrees, stopping as soon as it finds something. Whatever is actually under your crosshair therefore always wins over something merely in front of the ship. Surface elements are searched at each step too, with a range limit that tightens as the cone widens, so a wide-angle sweep cannot snap you onto a random turret on a distant station.

Range rules follow the radar: ordinary objects have to be inside your ship's radar range, while capital ships, stations and gates stay pickable considerably further out, since you can see them anyway.

### When nothing matches

A hotkey never substitutes a different kind of object for the one you asked for. Press "Target Nearest Station" with no station in range and your current target is left exactly as it was, with a fail sound and a message naming the category that came up empty. The same applies to Next/Previous: if the active filter has nothing left in it, they do nothing rather than silently dropping you back into cycling everything.

The one exception is deliberate and stays inside the category you asked for: if the hull you are attacking has no engines left, "Next" in engine mode widens to that hull's remaining surface elements rather than stranding you.

## Relationship to the vanilla targeting hotkeys

X4 already has a **Target Management** group under **Options > Controls**. Four of its entries do a simpler version of what this mod does, and running both at once on different keys is confusing, because the vanilla ones ignore the filter completely.

Recommendation: bind this mod's versions and clear the vanilla ones.

| Vanilla control | This mod's replacement | Difference |
|---|---|---|
| Target Closest Hostile | Target Nearest Enemy | Also sets the filter; also finds mines and explosives |
| Target Object | Target Along Line of Sight | Widening cone from dead centre instead of simply the closest object |
| Next Target | Select Next Target | Cycles the filter, not everything |
| Previous Target | Select Previous Target | Same |
| Deselect Target | Deselect Target and Reset Filter | Also clears the filter |

Two vanilla controls are left alone on purpose and remain useful alongside this mod:

- **Toggle Target Lock** is not duplicated here at all.
- **Next / Previous Surface Element** already cycle surface elements. They have no type filter, which is exactly the gap the engine/turret/shield hotkeys fill.

## Settings

Everything is configurable in game under **Options > Hotkey Management > Advanced Targeting Hotkeys**, reached from the same page you bind the keys on, rather than from a separate Extensions entry.

| Section | Setting | Default | Effect |
|---|---|---|---|
| Hotkey Groups | Combat Targets | on | Register the four enemy/missile hotkeys |
| | Own Fleet | on | Register the two own-ship hotkeys |
| | Navigation Objects | on | Register the station and gate hotkeys |
| | Resources | on | Register the collectable and asteroid hotkeys |
| | Surface Elements | on | Register the four surface-element hotkeys |
| | Mission Object | on | Register the mission-object hotkey |
| Targeting | Keep the filter after acquiring a target | on | Turn off to make Next/Previous always cycle everything, vanilla-style |
| | Extended range multiplier | `2` | How far beyond radar range large and already-known objects stay pickable |
| | Own ships checked for a free dock | `12` | Caps the docking-bay scan behind "Target Nearest Own Ship for Landing" |
| Feedback | Play a sound | on | Confirmation blip on success, fail blip when nothing matched |
| | Show a message when nothing is found | on | Names the category that came up empty |

Turning a whole group off means those hotkeys are never registered, so they do not occupy one of the Native Hotkey API's 48 shared slots. Turning a group **on** takes effect immediately; turning one **off** only releases its slots on the next reload, because the Hotkey API's registry has no unregister path. To free a single hotkey's slot right away, disable it on the API's own **Hotkey Requests** page instead.

Settings are stored per profile, alongside your key bindings, rather than in the save - so they follow you across saves the same way the bindings do.

### Debug logging

This mod has no debug switch of its own. It follows the Native Hotkey API's **Debug Logging** setting, one level up on the **Options > Hotkey Management** page itself: switching it on turns on the logging of the API and of every mod built on it, this one included. Leave it off unless you are chasing a problem.

Once on, you get one line per key press - which hotkey fired, which filter it resolved to, what got targeted, or why nothing did - plus the detail behind it: candidate counts, cycle index steps, each line-of-sight cone pass, and every target change with whether this mod caused it.

Lines are prefixed `AdvancedTargetingHotkeys:` and use the `general` filter. To capture them, start the game with `-debug general -logfile debuglog.txt`.

### Settings not on the page

One setting is deliberately left out of the UI, since it exists for troubleshooting rather than taste: `$targetingBackend`, in the `__ADVANCED_TARGETING_HOTKEYS_DATA` profile data. `'lua'` (the default) applies the target through this mod's small UI script using the same engine call the game itself uses for component slots, which covers surface elements. `'md'` uses the Mission Director's own `set_player_target` instead, which is simpler but is not confirmed to work on surface elements.

## Limitations

- The hotkeys only fire while you are piloting a ship with no menu open. There are no map-mode or on-foot variants.
- Candidate lists are rebuilt on every key press, so they always reflect the current situation. On a very large station with hundreds of surface elements this is measurable work per press.
- The Native Hotkey API's 48-slot pool is shared with every other mod using it. This mod asks for 19 of them with everything enabled.
- Key bindings in X4 are stored per profile, not in the save, so bindings created in one game carry over to any other save using the same profile.

## Credits

- **Author**: Chem O`Dun, on [Nexus Mods](https://next.nexusmods.com/profile/ChemODun/mods?gameId=2659) and [Steam Workshop](https://steamcommunity.com/id/chemodun/myworkshopfiles/?appid=392160)
- *"X4: Foundations"* is a trademark of [Egosoft](https://www.egosoft.com).

## Acknowledgements

- [EGOSOFT](https://www.egosoft.com) for the X series.
- **Trajan von Olb**, whose *More Hotkeys: Advanced Targeting* is where the sticky-filter idea comes from. This mod is an independent implementation of that concept on a different foundation, sharing no code with it.
- [kuertee](https://next.nexusmods.com/profile/kuertee?gameId=2659) for *UI Extensions and HUD*, which the Native Hotkey API is built on.

## Changelog

### [1.00] - 2026-07-29

- **Added**
  - Initial version: 19 pilot-area targeting hotkeys, sticky category filter with automatic invalidation, type-filtered surface-element targeting with widening fallback, widening-cone line-of-sight pick, and configurable hotkey groups.
  - A hotkey that finds nothing leaves the current target untouched and reports which category came up empty, rather than substituting a different kind of object.
  - Settings for hotkey groups, targeting behaviour and feedback, on their own page under the Native Hotkey API's **Hotkey Management** options page and stored per profile alongside the key bindings.
  - Debug logging follows the Native Hotkey API's own Debug Logging switch, so one setting covers the API and every mod built on it.
