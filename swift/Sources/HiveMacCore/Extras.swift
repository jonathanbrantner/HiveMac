import Foundation

/// Which fields each mob walks in (the game's own spawn spots). A hunt goes to the first field of the
/// list that has a route, preferring a field another due mob is already going to.
public enum MobFields {
    public static let table: [String: [String]] = [
        "ladybug": ["clover", "strawberry", "mushroom"],
        "rhino beetle": ["clover", "blue flower", "bamboo"],
        "spider": ["spider"],
        "mantis": ["pine tree", "pineapple"],
        "scorpion": ["rose"],
        "werewolf": ["pumpkin"],
    ]
    /// In the bug run picker but not hunted yet.
    public static let notBuilt = ["black bear"]

    /// mob -> field for the mobs that are due, sharing fields where possible.
    public static func plan(_ mobs: [String]) -> [(field: String, mobs: [String])] {
        var groups: [(field: String, mobs: [String])] = []
        for mob in mobs {
            guard let options = table[mob] else { continue }
            if let i = groups.firstIndex(where: { options.contains($0.field) }) { groups[i].mobs.append(mob) }
            else { groups.append((options[0], [mob])) }
        }
        return groups
    }
}

public enum CollectResult: Equatable { case collected, onCooldown(TimeInterval), failed(String) }

public enum HuntResult: Equatable { case killed, none, timeout, interrupted }

extension Game {
    /// Walks to a dispenser, clock, pass or booster and uses it. Starts from a reset so the position is known.
    /// The prompt tells the truth: "Use the Strawberry Dispenser" is ready, and "(3:59:58)" after it means
    /// it was used. So E is only pressed when it is ready, and the countdown afterwards proves it worked.
    /// Words that must show in the prompt when you stand at the right spot. A countdown from some other
    /// prompt (another dispenser, a wrong turn) does not count as this pickup being collected.
    public static let pickupWords: [String: [String]] = [
        "wealth clock": ["wealth", "clock"], "honey dispenser": ["honey disp"], "treat dispenser": ["treat"],
        "blueberry dispenser": ["blueb"], "strawberry dispenser": ["strawb"], "honeystorm": ["storm"],
        "ant pass": ["ant pass", "ant p"], "robo pass": ["robo"], "coconut dispenser": ["cocon"], "glue dispenser": ["glue"],
    ]

    /// The game shows "Use the Ant Pass" in range, or "You Already Have 10 or More Ant Passes" when the limit is reached.
    /// Both mean the character is standing at the pickup.
    public static func isPickupPrompt(_ t: String) -> Bool { t.contains("use th") || t.contains("already have") }

    public func collect(_ pickup: String) -> CollectResult {
        if let v = testVariant { return collectOnce(pickup, variant: v) }
        // A walk can miss by a few tiles (a buff starting mid-walk, a jump that did not take): reset and try once more.
        var first = collectOnce(pickup, variant: settings.travel)
        if case .failed(let why) = first, !stopped, !why.contains("stopped"), !why.contains("could not reach the hive"),
           !why.hasPrefix("no prompt") {            // a failed search already looked around: do not repeat it
            status("warning", "\(pickup): \(why). Resetting and trying once more.")
            first = collectOnce(pickup, variant: settings.travel)
        }
        if case .failed(let why) = first, settings.travel != "walk", !stopped,
           pathLookup("to_pickup", pickup.replacingOccurrences(of: " ", with: "_"), "walk") != nil
            || pathLookup("to_pickup", pickup, "walk") != nil {
            status("warning", "\(pickup): \(why). Trying the walking route once.")
            return collectOnce(pickup, variant: "walk")
        }
        return first
    }

    /// How far a walk goes depends on the walk speed at that moment (Haste comes and goes), so a route can end a
    /// little short of or past its target. The macro creeps along the last long walking direction of the route,
    /// checking the prompt after each small step: forward first, then back past the start.
    /// Pickups whose machine stands to the side of where the walk ends (seen in the frames): creep that way.
    public static let creepOverride: [String: [String]] = [
        "blueberry dispenser": ["d"], "treat dispenser": ["d"], "strawberry dispenser": ["w", "d"],
    ]

    func creepKeys(_ path: PathFile) -> [String] {
        let steps = iterSteps(path).filter { $0.type == "walk" && $0.tiles >= 3 }
        return steps.last?.keys.filter { ["w", "a", "s", "d"].contains($0) } ?? ["w"]
    }

    private func creepSearch(_ pickup: String, needles: [String], forward: [String]) -> String? {
        func prompt() -> String? {
            let t = sensors.promptText() ?? ""
            return needles.contains(where: { t.contains($0) }) && (t.contains("use") || t.contains("(")) ? t : nil
        }
        let opposite = ["w": "s", "s": "w", "a": "d", "d": "a"]
        let back = forward.compactMap { opposite[$0] }
        let stepS = 0.18, steps = 10
        status("traveling", "\(pickup): no prompt at the end of the walk, creeping \(forward.joined()) then \(back.joined())")
        for i in 0..<steps where !stopped {
            walker.hold(forward, stepS); wait(0.35)
            if let t = prompt() { status("traveling", "\(pickup): found after creeping \(forward.joined()) \(i + 1) steps"); return t }
        }
        walker.hold(back, stepS * Double(steps)); wait(0.3)
        for i in 0..<(steps * 2) where !stopped {
            walker.hold(back, stepS); wait(0.35)
            if let t = prompt() { status("traveling", "\(pickup): found after creeping \(back.joined()) \(i + 1) steps"); return t }
        }
        return nil
    }

    /// Goes out 6 tiles from where the route ended in each of the 8 directions and back, with the prompt probe running,
    /// so a pickup within about 6 tiles of the endpoint is found whichever way it lies.
    private func starSearch(_ pickup: String, needles: [String]) -> String? {
        status("traveling", "\(pickup): no prompt at the end of the walk, searching around in all directions")
        walker.armProbe({ [self] in
            let t = sensors.promptText() ?? ""
            return Game.isPickupPrompt(t) && needles.contains(where: { t.contains($0) })
        })
        defer { walker.armProbe(nil) }
        let dirs: [[String]] = [["w"], ["w", "d"], ["d"], ["s", "d"], ["s"], ["s", "a"], ["a"], ["w", "a"]]
        let opposite = ["w": "s", "s": "w", "a": "d", "d": "a"]
        for keys in dirs where !stopped {
            walker.walk(keys, tiles: 6)
            if walker.probeHit { break }
            wait(0.4)
            if (sensors.promptText() ?? "").contains("use th") { break }
            walker.armProbe(nil)                               // going back must not stop at the prompt
            walker.walk(keys.compactMap { opposite[$0] }, tiles: 6)
            walker.armProbe({ [self] in
                let t = sensors.promptText() ?? ""
                return Game.isPickupPrompt(t) && needles.contains(where: { t.contains($0) })
            })
        }
        walker.armProbe(nil)
        let t = sensors.promptText() ?? ""
        if needles.contains(where: { t.contains($0) }) && (t.contains("use") || t.contains("(")) {
            status("traveling", "\(pickup): found by the star search")
            return t
        }
        return nil
    }

    /// Last resort: walk an outward square spiral from where the route ended (arms of 1, 1, 2, 2, 3, 3 ... tiles) with the
    /// prompt probe running, jumping at the start of each arm. Stops the moment the pickup's prompt shows.
    private func spiralSearch(_ pickup: String, needles: [String]) -> String? {
        func prompt() -> String? {
            let t = sensors.promptText() ?? ""
            return needles.contains(where: { t.contains($0) }) && (t.contains("use") || t.contains("(")) ? t : nil
        }
        status("traveling", "\(pickup): spiral search around the end of the route")
        walker.armProbe({ [self] in
            let t = sensors.promptText() ?? ""
            return Game.isPickupPrompt(t) && needles.contains(where: { t.contains($0) })
        })
        defer { walker.armProbe(nil) }
        let dirs = [["d"], ["w"], ["a"], ["s"]]
        var arm = 0
        for ring in 1...7 {
            for _ in 0..<2 {
                if stopped || walker.probeHit { break }
                let keys = dirs[arm % 4]; arm += 1
                actuator.tap("space", holdS: Walker.jumpHoldS)
                walker.walk(keys, tiles: Double(ring) * 1.5)
                wait(0.3)
                if walker.probeHit { break }
                if let t = prompt() { walker.armProbe(nil); status("traveling", "\(pickup): found by the spiral search"); return t }
            }
            if walker.probeHit { break }
        }
        if walker.probeHit || prompt() != nil {
            status("traveling", "\(pickup): found by the spiral search")
            return prompt() ?? "use the \(pickup)"
        }
        return nil
    }

    /// The wealth clock stands on a platform up a ladder, and the open-loop walk can end a little to the side of the
    /// ladder (seen live: the character stays on the grass below). Push into the cliff, and when nothing happens
    /// sidestep in small steps, right first and then left, until the clock prompt shows.
    private func ladderSearch(_ pickup: String, needles: [String]) -> String? {
        func prompt() -> String? {
            let t = sensors.promptText() ?? ""
            return needles.contains(where: { t.contains($0) }) && (t.contains("use") || t.contains("(")) ? t : nil
        }
        status("traveling", "\(pickup): not on the ladder, searching sideways")
        let rightSteps = 11, leftSteps = 6
        for _ in 0..<rightSteps where !stopped {
            actuator.keyDown("w"); wait(1.2); actuator.keyUp("w")
            if let t = prompt() { status("traveling", "\(pickup): found it after the sideways search"); return t }
            walker.walk(["d"], tiles: 0.7)
        }
        walker.walk(["a"], tiles: 0.7 * Double(rightSteps))
        for _ in 0..<leftSteps where !stopped {
            actuator.keyDown("w"); wait(1.2); actuator.keyUp("w")
            if let t = prompt() { status("traveling", "\(pickup): found it after the sideways search"); return t }
            walker.walk(["a"], tiles: 0.7)
        }
        return nil
    }

    private func collectOnce(_ pickup: String, variant: String) -> CollectResult {
        if !resetToHive() { return .failed("could not reach the hive") }
        let slotName = pickup == "honey dispenser" ? "\(pickup) s\(min(6, max(1, settings.hiveSlot)))" : pickup
        let key = pickup.replacingOccurrences(of: " ", with: "_")
        var pf = pathLookup("to_pickup", slotName, variant)
        if pf == nil && variant != "walk" { pf = pathLookup("to_pickup", slotName, "walk") }
        if pf == nil { pf = pathLookup("to_pickup", key, "walk") }
        guard let path = pf else { return .failed("no route for \(pickup)") }
        status("traveling", pickup)
        var probe: (() -> Bool)?
        if let needles = Game.pickupWords[pickup] {
            // The game shows "Use the <pickup>" whenever the character is in range, so stop walking as soon as it does.
            probe = { [self] in
                let t = sensors.promptText() ?? ""
                return Game.isPickupPrompt(t) && needles.contains(where: { t.contains($0) })
            }
        }
        guard walkPath(path, probe: probe) else { return .failed("stopped") }
        if probeEnded { status("traveling", "\(pickup): the prompt showed during the walk, stopped there") }
        if pickup == "glue dispenser", testPrefix == nil {
            // The Gummy Bear lair opens when a gumdrop is dragged out of the inventory onto the screen, then it is 6 tiles in.
            if !settings.gumdropsKey.isEmpty {
                // Gumdrops sit on the hotbar: use one right here, then walk in.
                focusHook?(); wait(0.3)
                actuator.tap(settings.gumdropsKey, holdS: 0.15)
                wait(1.0)
                walker.walk(["w"], tiles: 6)
                wait(0.8)
            } else {
            guard openItemMenu() else { return .failed("glue dispenser: the inventory did not open") }
            guard findInInventory("gumdrops", maxScrolls: 60) != nil, let spot = sensors.find("gumdrops", in: RelRegion(fx: 0, fy: 0.12, fw: 0.25, fh: 0.88), tolerance: 5),
                  let w = windowSize() else {
                _ = openItemMenu()
                return .failed("glue dispenser: no gumdrops in the inventory")
            }
            let centre = (w.left + w.width / 2, w.top + w.height / 2)
            actuator.drag(fromX: spot.x, fromY: spot.y, toX: centre.0, toY: centre.1)
            wait(0.6)
            if let p = windowPoint(30, 120) { actuator.click(p.x, p.y) }          // close the inventory
            wait(0.8)
            walker.walk(["w"], tiles: 6)
            wait(0.8)
            }
        }

        // What does the prompt say here?
        func look(seconds: Double) -> String? {
            let t0 = clock.now()
            repeat {
                guard let t = sensors.promptText() else { return nil }
                if t.contains("use") || t.contains("(") || t.contains("already have") { return t }
                wait(0.4)
            } while clock.now() - t0 < seconds && !stopped
            return ""
        }
        var first = look(seconds: 3)
        if testPrefix != nil { return .failed("prefix test: stopped at the end of the walk, no search") }
        if let t = first, t.isEmpty, let needles = Game.pickupWords[pickup] {
            // One short search only (a failed pickup used to wander for minutes: sideways, star, creep, then the retry).
            if pickup == "wealth clock" { if let found = ladderSearch(pickup, needles: needles) { first = found } }
            else if let found = starSearch(pickup, needles: needles) { first = found }
            else if Game.creepOverride[pickup] != nil,
                    let found = creepSearch(pickup, needles: needles, forward: Game.creepOverride[pickup]!) { first = found }
        }
        let needles = Game.pickupWords[pickup]
        func atRightSpot(_ t: String) -> Bool { needles == nil || needles!.contains { t.contains($0) } }
        if let t = first, needles != nil {
            if t.isEmpty { return .failed("no prompt at the \(pickup) spot (it did not arrive at the right place)") }
            if !atRightSpot(t) { return .failed("not at the \(pickup): the prompt says \"\(t.prefix(80))\"") }
        }
        if first == nil {                                           // cannot read the screen: press E like before
            for _ in 0..<2 { actuator.tap("e", holdS: 0.1); wait(0.6) }
            wait(1.0)
            status("traveling", "collected \(pickup)")
            return .collected
        }
        if let t = first, t.contains("already have") {            // at the pickup, but the daily limit is reached: nothing to press
            status("traveling", "\(pickup): arrived, you already have the maximum")
            return .onCooldown(3600)
        }
        if let left = Hud.cooldownSeconds(fromText: first ?? "") {
            status("traveling", "\(pickup) is not ready yet")
            return .onCooldown(left)
        }
        for attempt in 0..<2 {
            focusHook?(); wait(0.3)                                // the key only counts while Roblox is the active app
            actuator.tap("e", holdS: 0.15)
            wait(0.8)
            // The countdown is the proof. Look for it for a few seconds.
            var last: String?
            let t0 = clock.now()
            while !stopped && clock.now() - t0 < 3.5 {
                last = sensors.promptText()
                if let t = last, atRightSpot(t), let left = Hud.cooldownSeconds(fromText: t) {
                    status("traveling", "collected \(pickup)")
                    return .onCooldown(left)                        // counting down now: it worked
                }
                wait(0.4)
            }
            if stopped { return .failed("stopped") }
            if let t = last, !t.contains("use") {                   // the "Use the ..." prompt went away, but no countdown was read
                status("warning", "\(pickup): the prompt went away after E but no countdown was read (prompt said: \(t.prefix(80)))")
                return .collected
            }
            if attempt == 0 { status("warning", "\(pickup): no countdown after E, trying once more") }
        }
        return .failed("no countdown showed after pressing E at \(pickup)")
    }

    /// Goes to the mob's field and fights until its health bar is gone. Gives up quickly when no mob is
    /// there, and after `maxSeconds` when it will not die. Without a readable screen it falls back to a
    /// fixed 90 seconds.
    public func hunt(field: String, maxSeconds: Double = 240) -> HuntResult {
        if !resetToHive(afterDeath: died) { return .interrupted }
        var f = FieldConfig(name: field)
        f.sprinklerLocation = "center"; f.camera = "none"; f.turns = 1
        f.backpackPercent = 100
        status("traveling", field)
        guard travelTo(f) else { return .interrupted }
        if sensors.mobBars() == nil {
            f.minutes = 1.5
            let r = gather(f)
            return r.reason == "time" || r.reason == "backpack" ? .killed : .interrupted
        }
        f.minutes = 0.25
        let t0 = clock.now()
        var seen = false, quiet = 0
        while !stopped {
            let r = gather(f)
            if r.reason == "death" || r.reason == "lost" { return .interrupted }
            if stopped { break }
            let bars = sensors.mobBars() ?? []
            if bars.isEmpty { quiet += 1 } else { seen = true; quiet = 0 }
            let elapsed = clock.now() - t0
            if seen && quiet >= 2 { status("gathering", "mob down in \(field)"); return .killed }
            if !seen && elapsed >= 20 { status("gathering", "no mob in \(field)"); return .none }
            if elapsed >= maxSeconds { status("warning", "the mob in \(field) would not go down, trying again later"); return .timeout }
        }
        return .interrupted
    }

    /// Mondo Chick on Mountain Top, in the first 14 minutes of the hour (UTC). "Buff" stands near it for two
    /// minutes with the tool out; "Kill" fights until its health bar has been gone for 15 seconds.
    public func mondo(kill: Bool) -> HuntResult {
        if !resetToHive() { return .interrupted }
        guard let route = pathLookup("to_planter", "mountain top", settings.travel) ?? pathLookup("to_planter", "mountain top", "walk") else {
            status("warning", "no route to Mountain Top"); return .interrupted
        }
        status("traveling", "mondo chick")
        guard walkPath(route) else { return .interrupted }
        walker.walk(["d"], tiles: 14)
        walker.rotate("left", taps: 1, leftKey: settings.rotLeft, rightKey: settings.rotRight)
        // Look for it for a few seconds.
        var found = sensors.mobBars() == nil
        let look = clock.now()
        while !found && !stopped && clock.now() - look < 6 {
            wait(0.5)
            found = !(sensors.mobBars() ?? []).isEmpty
        }
        if !found { status("warning", "no Mondo Chick at Mountain Top"); return .none }
        status("gathering", kill ? "fighting Mondo Chick" : "standing by Mondo Chick for the buff")
        parkMouse()
        if settings.useTool { actuator.mouseDown() }
        defer { if settings.useTool { actuator.mouseUp() } }
        let t0 = clock.now()
        var quiet = 0.0
        while !stopped {
            wait(1)
            if sensors.healthGrey() { died = true; return .interrupted }
            let elapsed = clock.now() - t0
            if !kill { if elapsed >= 120 { return .killed } }
            else {
                quiet = (sensors.mobBars() ?? []).isEmpty ? quiet + 1 : 0
                if quiet >= 15 { status("gathering", "Mondo Chick is down"); return .killed }
                if elapsed >= 900 || Int(unixNow() / 60) % 60 >= 15 { return .timeout }
            }
        }
        return .interrupted
    }
}

/// The runner HiveMac uses: it collects pickups, hunts mobs and tends planters (plant, harvest, replant).
public final class GameExtraRunner: ExtraRunner {
    public var timers: MobTimers
    public var onTimers: (MobTimers) -> Void
    public var huntSeconds: Double
    /// The fields of the run, so a colour objective can use one that is already farmed.
    public var mine: [String] = []
    /// Called with (step id, slot, unix time planted; 0 = emptied) so the app can save the planter timers.
    public var onPlanter: (UUID, Int, TimeInterval) -> Void = { _, _, _ in }
    private let unixNow: () -> TimeInterval

    public init(timers: MobTimers = MobTimers(), huntSeconds: Double = 90,
                unixNow: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
                onTimers: @escaping (MobTimers) -> Void = { _ in }) {
        self.timers = timers; self.huntSeconds = huntSeconds; self.unixNow = unixNow; self.onTimers = onTimers
    }

    public func due(_ step: ExtraStep, now: TimeInterval) -> [String] {
        switch step.kind {
        case "planters":
            return step.planterSlotsReady(now: now).map { "harvest \($0 + 1)" } + step.planterSlotsToPlant().map { "plant \($0 + 1)" }
        case "quests":
            return timers.due(step.bugs.map { $0 + " quest" }, now: now)
        case "mondo":
            let utcMinute = Int(now / 60) % 60
            return utcMinute < 14 ? timers.due(["mondo chick"], now: now) : []
        case "bug_run":
            let utcMinute = Int(now / 60) % 60
            return timers.due(step.bugs.filter { !MobFields.notBuilt.contains($0) && ($0 != "mondo chick" || utcMinute < 14) }, now: now)
        default: return timers.due(step.bugs, now: now)
        }
    }

    /// Gathering in a mob's own field for a while kills it on the way, so it does not need a hunt.
    public func fieldGathered(_ field: String, seconds: Double) {
        guard seconds >= 60 else { return }
        let here = MobFields.table.filter { $0.value.contains(field) }.map(\.key)
        if !here.isEmpty { done(here) }
    }

    public func boosterReady(_ booster: Booster) -> Bool { timers.isReady(booster.pickup, now: unixNow()) }

    public func boosterUsed(_ booster: Booster) { done([booster.pickup]) }

    private func done(_ names: [String]) {
        for n in names { timers.markDone(n, at: unixNow()) }
        onTimers(timers)
    }

    public func perform(_ step: ExtraStep, due: [String], game: Game) {
        switch step.kind {
        case "pickups":
            for p in due {
                if game.stopped { return }
                if let kind = MemoryMatchKind.allCases.first(where: { $0.pickup == p }) {
                    switch game.playMemoryMatch(kind) {
                    case .played: done([p])
                    case .onCooldown(let left): timers.setRemaining(p, seconds: left, now: unixNow()); onTimers(timers)
                    case .failed(let why): game.status("warning", "\(kind.title) memory match: \(why)")
                    }
                    continue
                }
                switch game.collect(p) {
                case .collected: done([p])
                case .onCooldown(let left):                          // the game's own countdown wins
                    timers.setRemaining(p, seconds: left, now: unixNow()); onTimers(timers)
                case .failed(let why): game.status("warning", "\(p): \(why)")
                }
            }
        case "bug_run":
            if due.contains("mondo chick") {
                let result = game.mondo(kill: step.mondoAction == "kill")
                if result == .killed || result == .none { done(["mondo chick"]) }
            }
            for name in due where Bosses.spec(name) != nil {
                if game.stopped { return }
                guard let spec = Bosses.spec(name) else { continue }
                switch game.boss(spec) {
                case .killed: done([name])
                case .none: timers.setRemaining(name, seconds: spec.missRetryS, now: unixNow()); onTimers(timers)
                case .timeout: timers.setRemaining(name, seconds: spec.timeoutRetryS, now: unixNow()); onTimers(timers)
                case .interrupted: return
                }
            }
            for group in MobFields.plan(due) {
                if game.stopped { return }
                game.status("traveling", "bug run: \(group.mobs.joined(separator: ", ")) at \(group.field)")
                let result = game.hunt(field: group.field)
                if result == .killed || result == .none { done(group.mobs) }
            }
        case "memory":
            for name in due {
                if game.stopped { return }
                guard let kind = MemoryMatchKind.allCases.first(where: { $0.pickup == name }) else { continue }
                switch game.playMemoryMatch(kind) {
                case .played: done([name])
                case .onCooldown(let left): timers.setRemaining(name, seconds: left, now: unixNow()); onTimers(timers)
                case .failed(let why): game.status("warning", "\(kind.title) memory match: \(why)")
                }
            }
        case "quests":
            for name in due {
                if game.stopped { return }
                let giver = name.replacingOccurrences(of: " quest", with: "")
                switch game.quest(giver, mine: mine, mobWait: { [unowned self] in self.timers.remaining($0, now: self.unixNow()) }) {
                case .turnedIn: done([name])
                case .notReady(let s):
                    timers.setRemaining(name, seconds: s, now: unixNow()); onTimers(timers)
                case .waiting(let s):
                    game.status("traveling", "\(giver): the mobs are back in \(MobTimers.describeDuration(s)), farming meanwhile")
                    timers.setRemaining(name, seconds: s, now: unixNow()); onTimers(timers)
                case .skipped(let why), .failed(let why):
                    game.status("warning", why)
                    timers.setRemaining(name, seconds: 1800, now: unixNow()); onTimers(timers)
                case .interrupted:
                    if game.stopped { return }
                    timers.setRemaining(name, seconds: 300, now: unixNow()); onTimers(timers)   // died or lost the screen: do not retry at once
                }
            }
        case "mondo":
            let result = game.mondo(kill: step.mondoAction == "kill")
            if result == .killed || result == .none { done(["mondo chick"]) }
        default:
            for name in due {
                if game.stopped { return }
                let parts = name.split(separator: " ")
                guard parts.count == 2, let n = Int(parts[1]), (1...3).contains(n) else { continue }
                planter(step, slot: n - 1, harvest: parts[0] == "harvest", game: game)
            }
        }
    }

    private func planter(_ step: ExtraStep, slot: Int, harvest: Bool, game: Game) {
        let field = step.planterFields[slot], type = step.planterTypes[slot]
        func report(_ r: PlanterResult, _ what: String) -> Bool {
            switch r {
            case .done: return true
            case .missing(let p): game.status("warning", "\(p) planter is not in your inventory")
            case .failed(let why): game.status("warning", "\(what) at \(field) failed: \(why)")
            }
            return false
        }
        if harvest {
            guard report(game.harvestPlanter(field: field), "harvest") else { return }
            onPlanter(step.id, slot, 0)
            guard step.planterReplant, !game.stopped else { return }
            if report(game.placePlanter(type, field: field, atField: true), "replant") { onPlanter(step.id, slot, unixNow()) }
        } else if report(game.placePlanter(type, field: field, atField: false), "plant") {
            onPlanter(step.id, slot, unixNow())
        }
    }
}
