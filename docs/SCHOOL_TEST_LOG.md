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
