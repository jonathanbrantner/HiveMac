# What Natro Macro has that HiveMac does not (2026-11-06)

Source: the checkboxes, tabs and functions of Natro's `natro_macro.ahk` (Gather, Collect/Kill, Boost, Quests,
Planters, Status, Settings, Misc). "Live" means it ran in the real game. "Beta" means built and tested only against a
simulated game. Effort: S under an hour, M a few hours, L a day or more. "Game" means it needs a live session to build well.

## Works live
Gathering fields (12 patterns, sprinkler, shift lock, mirror options, minutes, stop at percent), convert at the hive
(walk back or respawn, balloon), walking and cannon travel, the clock, honey, treat, blueberry, strawberry and coconut
dispensers, ant pass, robo pass, honeystorm, the three field boosters, bug runs (ladybug, rhino beetle, spider, mantis,
scorpion, werewolf), stop key, watchdog, phone remote.

## Beta (built, not proven live)
Planters (manual: plant, harvest, replant), Mondo Chick, memory match (Normal, Mega, Extreme), booster mode (rotate
boosters, gather the boosted field), pickups that read the prompt countdown.

## Not built
| Feature in Natro | Effort | Game | Value | Notes |
|---|---|---|---|---|
| Disconnect check, reconnect, public server fallback | L | yes | very high | Long runs end the first time Roblox drops. Natro has `DisconnectCheck`, `CloseRoblox`, rejoin. |
| MoveSpeed correction (haste, buffs change walk speed) | M | yes | high | Routes are timed; buffs make them miss. Natro reads the speed buff. |
| Quests: Polar, Honey, Black bear, Brown bear, Bucko, Riley | L each | yes | very high | Quest log recognition, then gather or kill what is asked. |
| Auto field boost (dice, glitter, free boosters per gathering field) | M | yes | high | Builds on booster mode. |
| King beetle, tunnel bear, coco crab, stump snail, commando chick | M each | yes | high | Fixed routes plus health bar fights. Coco crab and king beetle are the best first two. |
| Vicious bee and stinger hunt, night mode, night memory match | L | yes | medium | Only at night in game. |
| Royal jelly dispenser, glue dispenser | S | yes | medium | Routes exist (`gtc-royaljellydis`, `gtc-gluedis`); glue needs a dialog. |
| Blender | M | yes | medium | Menu with item picking. |
| Wind shrine | M | yes | medium | Donation dialog, item rotation. |
| Sticker stack, sticker printer | M | yes | medium | Dialogs and pictures. |
| Beesmas items (stockings, wreath, feast, de-level, gingerbread, snow machine, candles, samovar, lid art, gummy beacon, winter memory match) | S each | yes | seasonal | Same walk, E and prompt pattern as the pickups; only during the event. |
| Planters, automatic mode (Planters+) | L | yes | medium | Picks fields by nectar. Manual mode exists. |
| Drift compensation while gathering | M | yes | medium | Corrects sideways drift of patterns. |
| Custom gather patterns and a pattern editor | M | no | low | The 12 built-in patterns cover most fields. |
| Interrupt a long gather when something is due | M | no | medium | Natro stops gathering for a bug run or booster; HiveMac only runs extras between fields. |
| Start and pause hotkeys | S | no | low | Only the stop key exists. |
| Discord webhook and status screenshots | M | no | low | HiveMac has a phone page and snapshots instead. |
| "Disable tool use", auto start on launch | S | no | low | Tiny settings. |

## Suggested order
1. Reconnect and disconnect handling (it decides whether a long run survives).
2. Coco crab and king beetle (the bug run machinery and health bars are ready).
3. MoveSpeed correction.
4. Royal jelly and glue dispensers (small).
5. Quests, one giver at a time, starting with the one Jonathan uses most.
6. Auto field boost, then the rest by interest.

## Future: automatic UI scale
The inventory and quest log buttons are clicked at pixel spots measured from the window corner, times one "UI scale" setting.
That setting is not detected. On a display with a different scale (an external monitor) those corner clicks could land off.
Not built. If the "?" or inventory click misses on a second display, add detection (for example by measuring the distance
between two known icons) and set the scale from that.

## Todo: auto login back (reconnect)
When the Wi-Fi drops or Roblox crashes, the run should get back into the game by itself and carry on, instead of the watchdog
stopping it. Not built. Ideas to cover:
- Notice it: the Roblox window is gone, or the "Disconnected" box shows, or the screen stops changing for a while.
- Get back in: reopen Roblox or the private server link, wait for the game to load, walk to the hive, then continue the loop.
- Safety: a retry limit and a pause between tries, a stop that still works, and a log line plus snapshot for each reconnect.
- Natro has this (its disconnect and reconnect settings), so its approach is the place to start.
