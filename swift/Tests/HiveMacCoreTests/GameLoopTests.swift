import XCTest
@testable import HiveMacCore

/// A tiny model of the game: the backpack fills while the tool is down in a field, empties
/// while converting, a reset puts you at the hive, and a death can be scheduled.
final class FakeWorld: Sensors {
    let clock: FakeClock
    let act: FakeActuator
    var fillPerS: Double
    var dieAt: Double?
    var backpack = 0.0
    var atHive = false
    var inField = false
    var convertingSince: Double?
    var dead = false
    var respawnAt: Double?
    var hivePrompt: Bool?  = true          // nil = no hive prompt check configured
    var hivePromptOverride: Bool?          // force the prompt to read this
    var hiveView: Bool? = true
    var resets = 0
    var filterResets = 0
    var lastT = 0.0
    var unreadable = 0

    init(clock: FakeClock, act: FakeActuator, fillPerS: Double = 10, dieAt: Double? = nil) {
        self.clock = clock; self.act = act; self.fillPerS = fillPerS; self.dieAt = dieAt
    }

    func advance() {
        let dt = clock.now() - lastT
        lastT = clock.now()
        if dead, let r = respawnAt, clock.now() >= r { dead = false }
        if let d = dieAt, clock.now() >= d, !atHive {
            dead = true; respawnAt = nil; dieAt = nil; inField = false   // stays dead until the macro resets
        }
        if inField && act.mouse && !dead { backpack = min(100, backpack + fillPerS * dt) }
        if atHive && convertingSince != nil { backpack = max(0, backpack - 40 * dt) }
    }

    /// The game's Esc R Enter is observed through the actuator's taps.
    func observeReset() {
        let n = act.events.filter { $0 == "tap enter" }.count
        if n > resets {
            resets = n; dead = true; respawnAt = clock.now() + 1.0
            atHive = true; inField = false; convertingSince = nil
        }
    }

    func robloxPresent() -> Bool { true }
    func backpackPercent() -> Int {
        observeReset(); advance()
        return unreadable > 0 ? 0 : Int((backpack / 5).rounded()) * 5
    }
    func backpackUnreadableStreak() -> Int { unreadable }
    func resetBackpackFilter() { filterResets += 1 }
    func healthGrey() -> Bool { observeReset(); advance(); return dead }
    func hivePromptVisible() -> Bool? {
        observeReset(); advance()
        if let o = hivePromptOverride { return o }
        if hivePrompt == nil { return nil }
        if atHive && convertingSince == nil && act.events.suffix(3).contains("tap e") { convertingSince = clock.now() }
        return atHive
    }
    func hiveViewVisible() -> Bool? { hiveView }
    func cannonPromptVisible() -> Bool? { nil }
    func deathTextVisible() -> Bool? { nil }

    func onTap(_ key: String) {
        if key == "e" && atHive && convertingSince == nil { convertingSince = clock.now() }
    }
}

final class StatusLog { var items: [(String, String)] = [] }

final class GameFixture {
    let game: Game
    let world: FakeWorld
    let act: FakeActuator
    let clock: FakeClock
    let log: StatusLog
    var statuses: [(String, String)] { log.items }

    init(fillPerS: Double = 10, dieAt: Double? = nil, stop: Signal = Signal()) {
        let clock = FakeClock(), act = FakeActuator()
        let world = FakeWorld(clock: clock, act: act, fillPerS: fillPerS, dieAt: dieAt)
        var s = GameSettings()
        s.resetWaitS = 1; s.deathExtraWaitS = 5; s.zoomOutTaps = 3
        act.onTap = { world.onTap($0) }
        // Entering the field: the travel path ends with a long right walk after the camera turn.
        act.onKeyDown = { k in
            if k == "d" && act.events.contains("tap .") && world.atHive { world.atHive = false; world.inField = true }
        }
        let log = StatusLog()
        self.log = log
        self.clock = clock; self.act = act; self.world = world
        game = Game(actuator: act, sensors: world, settings: s, clock: clock, stop: stop,
                    status: { a, b in log.items.append((a, b)) },
                    windowSize: { (0, 0, 1600, 900) },
                    pathLookup: { kind, name, variant in
                        if kind == "to_field" {
                            if variant == "cannon" { return nil }
                            return PathFile(name: name, steps: [Step(type: "gotoramp"), .walk(["s"], tiles: 9),
                                                                .rotate("right", count: 2), .walk(["d"], tiles: 29)])
                        }
                        return PathFile(name: name, steps: [.walk(["a"], tiles: 29)])
                    })
    }

    var traveled: [String] { statuses.filter { $0.0 == "traveling" }.map(\.1) }
}

final class GameLoopTests: XCTestCase {
    func testResetSendsKeysWaitsForRespawnAndFixesCamera() {
        let f = GameFixture()
        XCTAssertTrue(f.game.resetToHive())
        let taps = f.act.events.filter { $0.hasPrefix("tap ") }.map { String($0.dropFirst(4)) }
        XCTAssertEqual(Array(taps.prefix(3)), ["esc", "r", "enter"])
        XCTAssertEqual(f.world.resets, 1)
        XCTAssertTrue(f.world.atHive)
        XCTAssertEqual(f.act.taps("o"), 3)                       // zoomed out
        XCTAssertEqual(f.world.filterResets, 1)
        XCTAssertGreaterThanOrEqual(f.clock.now(), 2.0)          // respawn + reset wait
    }

    func testResetRetriesWhenHivePromptMissingThenGivesUp() {
        let f = GameFixture()
        f.world.hivePromptOverride = false
        XCTAssertFalse(f.game.resetToHive())
        XCTAssertEqual(f.world.resets, f.game.settings.resetAttempts)
    }

    func testConvertPressesEAndWaitsForEmpty() {
        let f = GameFixture()
        f.world.atHive = true; f.world.backpack = 80
        XCTAssertTrue(f.game.convert())
        XCTAssertTrue(f.act.events.contains("tap e"))
        XCTAssertEqual(f.world.backpack, 0)
    }

    func testGatherStopsAtBackpackTargetAndReleasesTool() {
        let f = GameFixture(fillPerS: 20)
        XCTAssertTrue(f.game.resetToHive() && f.game.convert())
        var field = FieldConfig(name: "sunflower"); field.backpackPercent = 90; field.minutes = 30
        XCTAssertTrue(f.game.travelTo(field))
        XCTAssertTrue(f.world.inField)
        let res = f.game.gather(field)
        XCTAssertEqual(res.reason, "backpack")
        XCTAssertGreaterThanOrEqual(res.backpack, 88)
        XCTAssertFalse(f.act.mouse); XCTAssertTrue(f.act.down.isEmpty)
        XCTAssertLessThan(res.seconds, 30 * 60)
    }

    func testGatherStopsOnTimeLimit() {
        let f = GameFixture(fillPerS: 0.1)
        _ = f.game.resetToHive(); _ = f.game.convert()
        var field = FieldConfig(name: "sunflower"); field.backpackPercent = 95; field.minutes = 0.5
        _ = f.game.travelTo(field)
        let res = f.game.gather(field)
        XCTAssertEqual(res.reason, "time")
        XCTAssertTrue((30..<60).contains(res.seconds), "\(res.seconds)")
    }

    func testDeathDuringGatherThenLoopResetsWithExtraWait() {
        let f = GameFixture(fillPerS: 1.0, dieAt: 40)
        var field = FieldConfig(name: "sunflower"); field.backpackPercent = 95; field.minutes = 30
        let loop = FarmLoop(f.game, fields: [field], maxCycles: 2)
        XCTAssertEqual(loop.run(), "cycles_done")
        XCTAssertEqual(loop.stats.deaths, 1)
        XCTAssertEqual(loop.stats.history[0].reason, "death")
        XCTAssertEqual(loop.stats.cycles, 2)
        XCTAssertGreaterThanOrEqual(loop.stats.resets, 2)
        XCTAssertFalse(f.act.mouse); XCTAssertTrue(f.act.down.isEmpty)
    }

    func testLoopRotatesFieldsAndStopEndsIt() {
        let stop = Signal()
        let f = GameFixture(fillPerS: 50, stop: stop)
        var f1 = FieldConfig(name: "sunflower"); f1.backpackPercent = 90; f1.returnMethod = "reset"
        var f2 = FieldConfig(name: "dandelion"); f2.backpackPercent = 90; f2.returnMethod = "reset"
        var f3 = FieldConfig(name: "clover"); f3.enabled = false
        let loop = FarmLoop(f.game, fields: [f1, f2, f3], maxCycles: 3)
        XCTAssertEqual(loop.fields.map(\.name), ["sunflower", "dandelion"])
        XCTAssertEqual(loop.run(), "cycles_done")
        XCTAssertEqual(f.traveled, ["sunflower", "dandelion", "sunflower"])
        XCTAssertEqual(loop.stats.converts, 3)
        stop.set()
        XCTAssertEqual(FarmLoop(f.game, fields: [f1]).run(), "stopped")
    }

    func testWalkIsTheDefaultReturnAndConvertsAtTheHive() {
        let f = GameFixture(fillPerS: 50)
        let field = FieldConfig(name: "sunflower")
        XCTAssertEqual(field.returnMethod, "walk")
        var tuned = field; tuned.backpackPercent = 90
        let loop = FarmLoop(f.game, fields: [tuned], maxCycles: 1)
        XCTAssertEqual(loop.run(), "cycles_done")
        XCTAssertEqual(f.traveled, ["sunflower", "hive"])        // out to the field, then walked back
        XCTAssertEqual(loop.stats.converts, 1)                   // the bag starts empty, so only the walk back converts
    }

    func testResetReturnNeverWalksBack() {
        let f = GameFixture(fillPerS: 50)
        var field = FieldConfig(name: "sunflower"); field.backpackPercent = 90; field.returnMethod = "reset"
        XCTAssertEqual(FarmLoop(f.game, fields: [field], maxCycles: 1).run(), "cycles_done")
        XCTAssertEqual(f.traveled, ["sunflower"])
    }

    func testLoopGivesUpAfterRepeatedResetFailures() {
        let f = GameFixture()
        f.world.hivePromptOverride = false
        let loop = FarmLoop(f.game, fields: [FieldConfig(name: "sunflower")], maxFailedResets: 2)
        XCTAssertEqual(loop.run(), "reset_failed")
        XCTAssertEqual(loop.stats.failedResets, 2)
    }

    func testFieldConfigTakesNatroDefaults() {
        let f = FieldConfig(name: "Blue Flower")
        XCTAssertEqual(f.name, "blue flower")
        XCTAssertEqual(f.pattern, "corner_x_snake"); XCTAssertEqual(f.width, 7)
        XCTAssertEqual(f.camera, "right"); XCTAssertEqual(f.turns, 2)
        XCTAssertEqual(FieldConfig(name: "mountain top").invertFB, true)
    }

    /// Records what the loop asks of the extras and finishes them like a real runner would.
    final class SpyRunner: ExtraRunner {
        var timers = MobTimers()
        var performed: [(kind: String, due: [String])] = []
        var now: () -> TimeInterval = { 0 }
        func due(_ step: ExtraStep, now: TimeInterval) -> [String] {
            step.kind == "planters" ? step.planterSlotsReady(now: now).map { "slot \($0 + 1)" } : timers.due(step.bugs, now: now)
        }
        func perform(_ step: ExtraStep, due: [String], game: Game) {
            performed.append((step.kind, due))
            for d in due { timers.markDone(d, at: now()) }
        }
    }

    func testExtrasRunInOrderBetweenFieldsAndSkipWhatIsNotBack() {
        let f = GameFixture(fillPerS: 50)
        var f1 = FieldConfig(name: "sunflower"); f1.backpackPercent = 90; f1.returnMethod = "reset"
        var f2 = FieldConfig(name: "dandelion"); f2.backpackPercent = 90; f2.returnMethod = "reset"
        var bug = ExtraStep(kind: "bug_run"); bug.bugs = ["ladybug"]
        var off = ExtraStep(kind: "bug_run"); off.enabled = false
        var p = Profile(fields: [f1, f2], extras: [bug, off])
        p.move("e:" + bug.id.uuidString, before: "f:dandelion")      // sunflower, bug run, dandelion
        let spy = SpyRunner()
        var unix = 1_000.0
        spy.now = { unix }
        let loop = FarmLoop(f.game, profile: p, extras: spy, maxCycles: 4, unixNow: { unix })
        // The ladybug timer starts ready, runs once, then is skipped until 330 s have passed.
        XCTAssertEqual(loop.run(), "cycles_done")
        XCTAssertEqual(f.traveled, ["sunflower", "dandelion", "sunflower", "dandelion"])
        XCTAssertEqual(spy.performed.count, 1)
        XCTAssertEqual(spy.performed.first?.due, ["ladybug"])
        unix += 400
        spy.performed = []
        let again = FarmLoop(f.game, profile: p, extras: spy, maxCycles: 2, unixNow: { unix })
        XCTAssertEqual(again.run(), "cycles_done")
        XCTAssertEqual(spy.performed.count, 1)
    }

    func testPendingRunnerNeverMarksAnythingDone() {
        let r = PendingExtraRunner()
        var e = ExtraStep(kind: "bug_run"); e.bugs = ["ladybug"]
        XCTAssertEqual(r.due(e, now: 5), ["ladybug"])
        XCTAssertEqual(r.due(e, now: 5), ["ladybug"])
        var pl = ExtraStep(kind: "planters")
        pl.planterFields = ["rose", "", ""]; pl.planterPlanted = [100, 0, 0]; pl.harvestHours = 1
        XCTAssertEqual(r.due(pl, now: 100 + 3600), ["slot 1"])
        XCTAssertEqual(r.due(pl, now: 100 + 60), [])
    }

    func testCollectWalksTheRouteAndPressesE() {
        let f = GameFixture()
        XCTAssertTrue(f.game.collect("wealth clock"))
        XCTAssertEqual(f.act.taps("e"), 2)
        XCTAssertTrue(f.traveled.contains("wealth clock"))
        XCTAssertTrue(f.traveled.contains("collected wealth clock"))
    }

    func testCollectWithoutARouteDoesNotPressE() {
        let f = GameFixture()
        let g = Game(actuator: f.act, sensors: f.world, settings: f.game.settings, clock: f.clock,
                     status: { a, b in f.log.items.append((a, b)) }, windowSize: { (0, 0, 1600, 900) })
        XCTAssertFalse(g.collect("wealth clock"))
        XCTAssertEqual(f.act.taps("e"), 0)
    }

    func testHuntPlanSharesFields() {
        let plan = MobFields.plan(["ladybug", "rhino beetle", "werewolf", "king beetle"])
        XCTAssertEqual(plan.map(\.field), ["clover", "pumpkin"])
        XCTAssertEqual(plan[0].mobs, ["ladybug", "rhino beetle"])
    }

    func testRunnerMarksPickupsAndMobsDoneThenSkipsThemUntilBack() {
        let f = GameFixture(fillPerS: 20)
        var pick = ExtraStep(kind: "pickups"); pick.bugs = ["wealth clock"]
        var bug = ExtraStep(kind: "bug_run"); bug.bugs = ["ladybug", "coconut crab"]
        var saved = 0
        var unix = 5_000.0
        let runner = GameExtraRunner(huntSeconds: 20, unixNow: { unix }, onTimers: { _ in saved += 1 })
        XCTAssertEqual(runner.due(bug, now: unix), ["ladybug"])            // coconut crab is not hunted yet
        runner.perform(pick, due: ["wealth clock"], game: f.game)
        runner.perform(bug, due: ["ladybug"], game: f.game)
        XCTAssertEqual(saved, 2)
        XCTAssertEqual(runner.due(pick, now: unix + 100), [])
        XCTAssertEqual(runner.due(bug, now: unix + 100), [])
        unix += 3_700
        XCTAssertEqual(runner.due(pick, now: unix), ["wealth clock"])
        XCTAssertEqual(runner.due(bug, now: unix), ["ladybug"])
        XCTAssertTrue(f.traveled.contains("clover"))
    }
}
