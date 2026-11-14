# School MacBook test log

## Summary (2026-11-13, first live session)
Proven in the real game on the school MacBook Air, hive slot 2, windowed Roblox:
- Detect Roblox finds the window. The backpack reads the pollen bar text ("0/164.038.875" = 0 percent).
- Practice mode: reset, convert, travel to Sunflower and gather were logged and nothing was pressed.
- A real run of one field (Sunflower, 2 minutes, Corner X Snake) went by itself for 53 minutes, 17 gather rounds:
  gather, walk back, convert, reset, travel, repeat. The app counted 16 cycles, 27 converts, 4 deaths. The game showed
  "+15,312 Honey (from Sunflower Field)".

Not proven or still odd:
- "At the hive" reads no and the log says "no hive prompt template, assuming at hive". The first reset needed a second try.
- Two converts per cycle (27 converts for 16 cycles). Needs a look.
- Some gathers ended early (about 30 s) when the character died (4 deaths).
- Run modes, quests, balloon blessing, memory match and the reworked pickups were NOT tested yet.
- No Xcode on this Mac, so swift test cannot run here.

## Fixes made
- Screen reads left out HiveMac's own window (it covered the game HUD).
- Screen reads now capture the Roblox window itself, so windows on top (HiveMac, a terminal) cannot spoil them.
- Build script prefers a permanent self-signed certificate named "HiveMac Local Signing", so macOS keeps its permissions across rebuilds.

## Log
- 15:5x Built and installed. Granted Screen Recording and Accessibility.
- 16:1x Detect Roblox: blank backpack picture. Cause 1: Roblox had disconnected for being idle (error 278), reconnected. Cause 2: windows on top of Roblox. Fixed as above.
- 16:19 Practice mode run: worked.
- 16:20 to 17:14 Live Sunflower run: worked, see summary.

## Pickups live test (2026-11-13, 17:17 to 17:33, Clock and dispensers, All ticked)
Result per pickup, from hivemac.log and the snapshots in ~/Library/Application Support/HiveMac/snapshots:
- Wealth clock: FAILED. Walk of 48 s ended on grass about 300 px short of the clock. No prompt.
- Honey dispenser: FAILED. The route was done after 12 s, no prompt.
- Treat dispenser: FAILED. The character ended in the Blue Flower field. The "top prompt" region read the
  Honey and Pollen HUD text, so that region also covers the HUD on this Mac.
- Blueberry dispenser: collected. Strawberry dispenser: collected.
- Honeystorm: FAILED. Camera was zoomed into the pile of pets and gifts, no prompt.
- Ant pass: FAILED. Robo pass: FAILED (walked 90 s, no prompt).
Likely causes (not yet proven): the Natro routes are timed key holds, and the walk speed setting (28) may not match this
account's real speed with buffs; the camera zoom is not always reset; the prompt region overlaps the HUD.
Next: read the real walk speed in game and test one route (honey dispenser, the shortest) until it arrives, then the rest.

## Layer table (route test: POST /api/testroute?name=<pickup>&n=<times>, reset + camera + walk + prompt check)
| Layer | Result | What fixed it |
|---|---|---|
| Reset (Esc, R, Enter) | works when the menu state is read first | The Roblox menu was left open by earlier presses, so blind Esc toggled it shut. pressReset now reads the menu (OCR) and only then presses R and Enter. |
| Camera facing away from the hive | works: the scan shows one clear peak (about 65 percent honeycomb) and the macro turns half a circle from it | My smoothing change turned 90 degrees to the side; restored peak plus half a circle. The result is checked from the screen (share after the turn). |
| Walk speed | 26 fits the honey dispenser route | 28 ended a second short, 24 overshot to the shop. Real speed varies a little run to run (Haste), so a fixed value cannot be exact. |
| Honey dispenser route | 4 of 4 completed runs passed (run 5 was stopped by the user) | One run ended short and the creep search found the prompt after 5 steps. |
| Wealth clock | NOT passing | Open-loop route ends beside the ladder; a sideways ladder search is built but untested in a clean run. Camera facing was the likely cause of the earlier odd endpoints. |
| Other pickups, booster mode, quests, memory match, planters, bug run | not tested since the fixes | |

Tools added: route frame traces (traces/<time>-<route>/NN-step.png, reset frames too), the route test, the creep and ladder searches.

## Status 2026-11-13 20:30 (end of first long session)
Works in the real game: reset (menu button, Respawn, Enter), camera facing check, screen capture of the Roblox window, live walk
speed from the stats panel (Movespeed line, pairs label and number by row), prompt probe that stops a pickup walk when the prompt
shows, honey dispenser route (most runs pass), Sunflower field loop (53 min live run earlier), route frame traces, the one-route test
(POST /api/testroute?name=&n=&travel=&prefix=).
Not working: wealth clock, treat dispenser, blueberry dispenser end up in the Blue HQ area; the blueberry machine stands on a raised
ledge behind a blue wall (frames in ~/Library/Application Support/HiveMac/traces). Strawberry, honeystorm, ant pass, robo pass, cannon
variants, memory match, bug runs, planters, Booster mode, Quests, balloon blessing: not verified.
Gotchas found: the stop key "-" is global during a run (typing a hyphen stops it); Esc does not open the Roblox menu on this client;
Roblox must be the active app for clicks and keys; stray runs were killed by relaunching the app.
Next: find the first step where each failing route leaves Natro's path (frames), starting with blueberry (needs a jump onto the ledge).
