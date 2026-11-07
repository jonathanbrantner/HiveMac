# Plan: quests, Black Bear first

Status of the four items from the last round, then the quest plan.

## 1. Dispensers: done, needs one live look
- Clock and dispensers has All, Dispensers (strawberry, treat, blueberry, honey), Tickets (Ant Pass, Robo Pass) and None.
- Open question for the owner: should Tickets always stay ticked whichever button is pressed? Today it is its own button.
- Live check: press each button, run, read the log for "collected" or "not ready yet" per pickup.

## 2. Planters: done, needs one live look
- Grow time is calculated per slot from Natro's table (`PlanterGrowth.swift`), shown as "Grows 8.7 h" and then "Ready in ...".
- Festive planter has no Natro number, so it uses 4 hours.
- Live check: plant one planter, compare "Ready in" with the planter's own timer in the game after a few minutes.

## 3 and 4. Quests: not built, blocked on two screenshots

Why blocked: Natro finds the quest and its progress by searching the quest log with pictures cut for its Windows
screen. HiveMac reads text instead, and which text and where is only knowable from a real quest log on the owner's Mac.

### Needed from the owner (one time)
1. Roblox open, quest log open, one quest with objectives showing (a Black Bear quest is best).
2. Standing at the Black Bear with the dialog open, and one more after the quest is turned in if possible.
Drop them in `~/Library/Application Support/HiveMac/snapshots/` or paste them in the chat.

### What is already in the repo
- `config/quests.json`: Natro's tables for Polar, Black, Bucko and Riley (about 170 quests, objectives as Collect, Kill, Get, Feed).
- `config/paths/natro/to_quest/*`: walking routes to all six quest givers (walk and cannon).
- `QuestBook.swift`: finds a quest by its name in OCR text and turns objectives into actions (gather a field, gather a pollen colour, kill mobs, unsupported).
- `Game.hunt`, `Game.collect`, gathering, convert: reused as they are.

### Build order
1. **Read the quest log (pure, tested):** from the screenshot, decide the OCR region, how a quest title and its objective lines
   look as text, and how a finished objective looks (a tick, a full bar, or text). Tests use the owner's screenshots as fixtures.
2. **Black Bear quest step:** go to the Black Bear, press E through the dialog until the quest text shows, read the log,
   pick a field of the asked colour (`QuestBook.field(forColor:preferring:)`, preferring the run's own fields),
   gather it until the log shows the objective done, walk back, talk again to turn it in. A new quest starts after
   an hour (Natro waits 3600 s). Every click and E only after the text it needs has been read.
3. **Add "Quests" to the Add popover** with one tick per giver and the usual All and None. Timers per giver in `MobTimers`.
4. **Polar Bear** (Collect and Kill objectives, mobs through `hunt`), then **Bucko** and **Riley** (Kill, Get Ant is skipped and logged),
   then **Brown Bear** and **Honey Bee** (their routes are converted, their quest tables are not in Natro as maps).
5. **Ant, feed and boost objectives** stay "unsupported": the quest is skipped for now and the log says why.

### Safety rules
- No guessing: if the log cannot be read, the step logs it, saves a snapshot, and moves on.
- A quest that makes no progress after one gather round is left alone for 30 minutes.
- Practice mode shows what it would press without pressing anything.

### Done when
- Black Bear: one quest started and finished on its own, twice in a row, from the live log and snapshots.
- Tests: quest finder, objective-to-action mapping, the step on a simulated log (objective done after N gathers, never done, unreadable).

## Update 2026-11-07: quests are a run mode
Quests are no longer a step. The Fields tab has one "Run mode": Fields, Booster mode or Quests. Quests mode has one giver.
Only the wealth clock runs between quest work and the fields. Black, Polar and Brown have an hour cooldown, during which the
normal fields run. Bucko and Riley have none and chain. An objective that is not supported (petals, rage tokens, fire ants)
skips the quest for 30 minutes and the fields run meanwhile. Not yet proven in the game.

## Update 2026-11-07 (later): modes cleaned up
Modes are None (default, the field list and its steps), Booster mode and Quests. Booster and Quests keep one idle field and no steps,
and ask before removing anything. Options in both: Wealth clock, Keep balloon blessing (needs the Balloon blessing picture; the
return comes 10 minutes before it runs out, learned from the first time the icon vanishes). A kill objective only sends the macro out
when the mob's respawn timer is up; otherwise the idle field runs until the mob is back.
