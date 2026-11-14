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
