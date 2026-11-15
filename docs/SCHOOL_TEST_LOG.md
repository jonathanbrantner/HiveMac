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

## 2026-11-14 morning
- Hive slot changes when Roblox rejoins (slot 1 yesterday, slot 6 after the lock and rejoin). A wrong slot sends every route to the wrong place. Set it again after any rejoin.
- Field cannon routes still land in the hub area (route matches Natro, cause not found). Travel is set to walk, which works: Pine Tree reached and gathered, full cycle with convert, balloon, wealth clock.
- A failed pickup used to wander for minutes (sideways, star, creep search, then a repeat). Now one short search, no repeat.
- Bear morph adds 4 speed, the stats panel is not open so walks use the settings speed (29). Not fixed yet.
- The Mac must be kept awake (caffeinate) or it locks and the run dies.
- 12:35 Pine Tree CANNON now arrives in the field. Cause: a screenshot was taken between the cannon steps (trace default on) and delayed the glider. Fixed: no pictures during cannon routes, trace default off, quick double jump step (jump2), 5 zoom taps, 10 s cannon prompt wait.
- Bamboo and Blue Flower cannon tested once each: did NOT arrive (Bamboo ended at the hive, Blue Flower ended on a blue pad outside a field). Other 9 field cannon routes untested. Travel setting stays walk.
- Wealth clock walk passes after widening the ladder search to the right.

## 2026-11-14 evening (buff bar, cannon, long run)
- Buff bar reader (Natro style): a real Haste icon (running figure) is detected on the live game, speed 31.9 with haste x1. Detection takes about 1 ms. Bear +4 still unverified.
- The balloon wait in convert could be longer than the watchdog (about 8 min balloon): it now posts a status every 20 s, so the watchdog no longer stops it.
- Gather stall guard (4 min without backpack percent gain) reset a correct field: Diamond Drain and Conversion Link keep the bag at 0%. Default is now off (game.gather_stall_s = 0).
- Walk efficiency 0.9 made the Pine Tree walk overshoot into Strawberry: default back to 1.0 (setting game.walk_efficiency kept).
- Cannon flight timings (Natro uses fixed real seconds) now shrink by settings speed / live speed when buffs show, so Haste does not carry the landing past the field. Pine Tree cannon landed in the field 2 of 3 times in the route test, then cycled 4 full gather and convert rounds from 5:33 to 6:40 PM with one cannon retry and a wealth clock walk fallback.
- Walk learned speed on the wealth clock walk: real speed about 27 against 29 in the settings.
- Open: why a cannon run sometimes misses (pad position or glide), wrong field detection without the stall guard, Bamboo, Blue Flower and the other 9 cannon fields, Pine Tree walk drifting into the cactus and gate.

## 2026-11-14 late night (code only, Roblox was closed, NOT tested in the game)
- Copied Natro: speed is the settings speed times the buffs only (the learned arrival factor is removed); the cannon scan holds Right while it looks for the prompt, 20 s, up to 10 tries; all 21 cannon routes that still used two slow taps for the double jump now use the quick jump2 (wealth clock, planter, quest and pickup cannons). The field cannons already had it. The slow double jump is the likely reason the wealth clock cannon never arrived.
- Removed: gather stall guard, walk efficiency setting, learned speed code.
- Added: sprinkler refusal check (the game's red "You must be standing in a field" message makes it step left and place again, then fail the trip), stop requests log their source, return to hive looks for the prompt in short steps, the run start line shows the hive slot.
- To test next: five cannon trips in a row (landing count), wealth clock cannon, the sprinkler check, the return to hive, then a 30 minute run. Still open: Pine Tree walk drift into the cactus and gate, unexplained mid route stops (read the new labels), Bamboo, Blue Flower and the other 9 cannon fields.

## Code-only change 2026-11-14 (not tried in the real game yet)
- Double convert per cycle (27 converts for 16 cycles) has a code cause: the walk back converted, then the reset and a second convert pressed E on an empty bag. The second one is skipped now, and the stats count only converts that found pollen. Check on the school MacBook that a cycle now shows one convert.

## Window size fix 2026-11-14 (code only, check live)
- On a 2560 x 1298 window the saved HUD shares from a 1429 x 885 window cut the hive banner ("hive prompt not seen"), read the backpack bar wrong (40 % with an empty bag) and clicked the chat icon instead of the menu button. Spots are now worked out from the window at every read, Start refits them, Respawn is found by its text. After the next build: Save snapshot at the hive must show "Hive prompt seen: true" and backpack 0 %; test once on each Mac and after resizing the window.

## 2026-11-15 (code only, Roblox closed, NOT tested in the game)
- Wealth clock cannon: two causes found in the code. The route used two slow taps for the glider (now the quick jump2, like every cannon route), and the Haste flight shortening only counted a flight when the route held d (the clock route holds w and a); any held movement key counts now.
- Tool: a held mouse button counts as one click on macOS Roblox, so a helper thread clicks about 4 times a second during every gather (log line "tool: clicking about 4 times a second").
- Sleep: HiveMac holds a power assertion (display and system) while a run is going, so the Mac never goes idle after 20 minutes and the pointer is never moved.
- Cannon prompt: picture match first like Natro (fast), the words are read at most twice a second as the second look.
- Pulled 6 commits from the other Mac (HUD spots follow the window size, Respawn found by text, skip the second convert after a walk back).
- Still to prove in the game: cannon landing count (5 trips), clock cannon, sprinkler check, return to hive, tool swing, Pine Tree walk drift into the cactus and gate, Bamboo, Blue Flower and the other cannon fields.
