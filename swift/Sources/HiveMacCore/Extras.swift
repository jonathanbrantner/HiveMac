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
    static let pickupWords: [String: [String]] = [
        "wealth clock": ["wealth", "clock"], "honey dispenser": ["honey disp", "honey"], "treat dispenser": ["treat"],
        "blueberry dispenser": ["blueb"], "strawberry dispenser": ["strawb"], "honeystorm": ["storm"],
        "ant pass": ["ant p", "ant"], "robo pass": ["robo"], "coconut dispenser": ["cocon"],
    ]

    public func collect(_ pickup: String) -> CollectResult {
        let first = collectOnce(pickup, variant: settings.travel)
        if case .failed(let why) = first, settings.travel != "walk", !stopped,
           pathLookup("to_pickup", pickup.replacingOccurrences(of: " ", with: "_"), "walk") != nil
            || pathLookup("to_pickup", pickup, "walk") != nil {
            status("warning", "\(pickup): \(why). Trying the walking route once.")
            return collectOnce(pickup, variant: "walk")
        }
        return first
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
        guard walkPath(path) else { return .failed("stopped") }

        // What does the prompt say here?
        func look(seconds: Double) -> String? {
            let t0 = clock.now()
            repeat {
                guard let t = sensors.promptText() else { return nil }
                if t.contains("use") || t.contains("(") { return t }
                wait(0.4)
            } while clock.now() - t0 < seconds && !stopped
            return ""
        }
        let first = look(seconds: 3)
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
        if let left = Hud.cooldownSeconds(fromText: first ?? "") {
            status("traveling", "\(pickup) is not ready yet")
            return .onCooldown(left)
        }
        for attempt in 0..<2 {
            actuator.tap("e", holdS: 0.1)
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
                switch game.quest(giver, mine: mine) {
                case .turnedIn: done([name])
                case .notReady(let s): timers.setRemaining(name, seconds: s, now: unixNow()); onTimers(timers)
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
