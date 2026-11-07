# Live test checklist

Nothing here can be checked without Roblox open. Work top to bottom, tick a stage only when it worked
three times in a row without help. **The stop key (F9 by default) stops everything at any moment.**
After any failure press **Save snapshot** in the Log tab (it saves a folder with the Roblox picture, the
readings, the settings and the log, and opens it) and send that folder back.

Data lives in `~/Library/Application Support/HiveMac` (log: `logs/hivemac.log`, snapshots: `snapshots/`).

## Before you start (once)

- [ ] Roblox settings: camera mode Classic, movement mode Keyboard, graphics set by hand to a low level,
      performance stats off, micro profiler off, camera not inverted, language English.
- [ ] macOS display colour profile sRGB. Roblox open (window or full screen, and the same choice in
      HiveMac under Macro, Roblox window).
- [ ] HiveMac: gear, top right: Screen Recording and Accessibility are on (reopen HiveMac after turning them on).
- [ ] Macro tab: hive colour, walk speed **without buffs** (from the in-game stats), travel, sprinkler, hotbar.
- [ ] Fields tab: your hive slot (1 to 6).

## Stage 0: readings

- [ ] Calibrate tab: stand in your hive, press **Detect Roblox**. It says "Roblox found".
- [ ] Gather a little by hand. The backpack reading follows the bar in the game (steps of 5 percent).
- [ ] The Esc, R, Enter test: fill the backpack to about 30 percent, reset, read the bar. Does it go to zero?
      Write down the answer; it decides whether "Reset" is a valid return method.

## Stage 1: practice mode (presses nothing)

- [ ] Macro tab: turn on **Practice mode**. Start.
- [ ] Walk the character by hand: hive, then a field, then die once. The log shows "Practice: would press ..."
      lines and the backpack, health and prompt readings change as you move.
- [ ] Stop. Turn practice mode off.

## Stage 2: reset and convert

- [ ] Fields tab: one field only. Start with a full backpack standing in the hive. Esc, R, Enter happens,
      the character ends at the hive, the camera faces away from the hive, E converts.

## Stage 3: one field, two minutes

- [ ] Sunflower, 2 minutes, 95 percent. Start. Check in order: walk to the field, sprinkler placed, pattern
      covers the field, stops at the time or the backpack, walks back, converts.
- [ ] If the walk ends outside the field: Calibrate, Advanced, Record a walk (needs Input Monitoring), walk it
      yourself. Your recording replaces Natro's for that field.
- [ ] Repeat three times.

## Stage 4: half an hour, two fields

- [ ] Two fields, 15 minutes each. Watch a death (or cause one), the pause and resume buttons, and the phone
      remote (gear, Phone remote) from a phone on the same Wi-Fi.
- [ ] The watchdog: it stops the run if nothing happens for 90 seconds.

## Stage 5: cannon and glider

- [ ] Needs the Red Cannon and the Glider. Macro tab, Default travel: Cannon. One field, watch the cannon trip.

## What to send back

- The snapshot folder of any failure, plus a line on which stage and what you expected.
- Memory and CPU of HiveMac from Activity Monitor while a farm loop runs (the idle number is 30 MB, 0.1 percent).
