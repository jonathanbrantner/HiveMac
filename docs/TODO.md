# HiveMac to do

## Next (written 2026-11-07, in the order to do it)
1. **Live test the new things**, with the stop key ready, then send `hivemac.log` and the newest `snapshots/`:
   Quests mode (Black Bear first, then the other four givers), Booster mode, memory match (16 and 20 tiles),
   the reworked pickup routes (treat, blueberry, strawberry, honeystorm), Keep balloon blessing.
2. **Take the "Balloon blessing" picture** (Settings, More, Danger zone, Pictures) and bundle it as
   `config/images/hud/balloon_blessing.png`, so nobody has to take it.
3. **Auto login back (reconnect)** after Wi-Fi drops or Roblox crashes: notice the drop, reopen Roblox or the private
   server link, walk to the hive, carry on; retry limit, pause between tries, log line and snapshot each time.
   Details in `docs/NATRO_GAP.md`. This decides whether an overnight run survives.
4. **Walk speed correction** (haste and buffs change walk speed, so timed routes miss).
5. **Quest objectives not built yet:** petals, rage tokens, fire ants, tokens, Honey Bee, "The Trick To Tickets".
6. **Coconut crab and king beetle**, then royal jelly and glue dispensers.
7. **Automatic UI scale** detection for other displays (an external monitor can make corner clicks miss).
8. Interrupt a long gather when something is due; start and pause hotkeys.
9. **Release housekeeping:** decide on Apple Developer ID signing and notarization (today the download is signed
   with a development certificate and macOS may block it on other Macs), and decide the licence.
10. **Ask YouTubers to review HiveMac for Mac users.** Do it after the live test of quests and pickups goes well, so
   a reviewer's first run works. Pick channels that already cover Bee Swarm macros and have a Mac. Say plainly that it
   is a beta and which parts are untested. Link the GitHub release. A draft message is not written yet.

## Older notes

What is not built yet, in the order to build it. Everything here is OFF by default and code only
until it has been tried in the real game. Source of the inventory: Natro Macro (GPLv3). Game facts
(timers, field lists, planter numbers) are free to use. Natro's path and pattern files are not:
keep its notice on them and do not share this repo until that is handled.

## Run steps (fields, pickups and bug runs tried in the real game on 2026-11-06; planters and Mondo Chick built, still in beta)
Pickups (clock, dispensers, passes, honeystorm, boosters): reset, Natro's route from `config/paths/natro/to_pickup`, E twice, timer. Bug runs: reset, travel to the mob's field, gather 90 s with the tool, timer. Planters: built the same day (inventory search, drag, Yes, harvest, replant; routes in `to_planter`, pictures in `config/images/natro`), also untested. Natro's spots are Windows window pixels, so the Mac scale may need `game.ui_scale` and `game.ui_offset_y`. Still missing: coconut crab, king beetle, black bear, mob detection by health bar colour, loot sweep.
- **Bug runs:** ladybug and rhino beetle first (every 330 s respawn), then spider (1830 s), mantis and
  scorpion (1230 s), werewolf (3630 s). Mobs are found by health bar colours 0x1fe744 and 0x6b131a.
  Also in the picker: coconut crab (36 h), king beetle (24 h), black bear quests.
- **Planters:** per slot a field and one of 12 planter types (bonus and growth hours per type).
  Manual mode first: fixed harvest interval per run. Placement needs the inventory drag, so it needs the game.
- **Quests:** last, hard. Needs quest log recognition.

## Easy additions (a route, a timer, an E prompt check)
Clock and dispensers, honeystorm, ant pass and robo pass: settings and timers are saved per run, the walking and E press are not built.
Still to list: field boosters (45 min), daily honey leaderboard.

## Hive profile
- Hive profile: field colour hints are in (community wiki data, only fields with a clear colour). Honey or minutes estimates are NOT built: no reliable rates are known.

## Future idea (not scoped, maybe too much for now)
A very simple website with just sign in and sign up, where you press Start and a few other basics to
control the macro from anywhere. Today the phone remote page covers this on the same Wi-Fi or Tailscale
without any account. A website would need a cloud relay between the site and the Mac, plus real auth.
Only worth it if the phone page is not enough.

## Checks
- Idle, window open, measured 2026-11-05: 30 MB real footprint, 0.0% CPU, 5 threads, 2.3 MB on disk (Python app: about 156 MB, 1.4% CPU, 60 MB on disk). Still to measure: while running a farm loop.
- First live session: `docs/LIVE_TEST_CHECKLIST.md`. Includes: does Esc R Enter empty the backpack?
