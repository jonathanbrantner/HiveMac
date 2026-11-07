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
    public static let notBuilt = ["coconut crab", "king beetle", "black bear"]

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
    public func collect(_ pickup: String) -> CollectResult {
        if !resetToHive() { return .failed("could not reach the hive") }
        let variant = settings.travel
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
            wait(1.2)
            if let t = sensors.promptText() {
                if let left = Hud.cooldownSeconds(fromText: t) {
                    status("traveling", "collected \(pickup)")
                    return .onCooldown(left)                        // counting down now: it worked
                }
                if !t.contains("use") {                             // the "Use the ..." prompt is gone: it was taken
                    status("traveling", "collected \(pickup)")
                    return .collected
                }
            }
            if stopped { return .failed("stopped") }
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
        case "mondo":
            let utcMinute = Int(now / 60) % 60
            return utcMinute < 14 ? timers.due(["mondo chick"], now: now) : []
        case "bug_run": return timers.due(step.bugs.filter { !MobFields.notBuilt.contains($0) }, now: now)
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
                switch game.collect(p) {
                case .collected: done([p])
                case .onCooldown(let left):                          // the game's own countdown wins
                    timers.setRemaining(p, seconds: left, now: unixNow()); onTimers(timers)
                case .failed(let why): game.status("warning", "\(p): \(why)")
                }
            }
        case "bug_run":
            for group in MobFields.plan(due) {
                if game.stopped { return }
                game.status("traveling", "bug run: \(group.mobs.joined(separator: ", ")) at \(group.field)")
                let result = game.hunt(field: group.field)
                if result == .killed || result == .none { done(group.mobs) }
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
