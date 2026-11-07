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

extension Game {
    /// Walks to a dispenser, clock, pass or booster and presses E. Starts from a reset so the
    /// position is known. Returns false when it could not get there.
    public func collect(_ pickup: String) -> Bool {
        if !resetToHive() { return false }
        let variant = settings.travel
        let slotName = pickup == "honey dispenser" ? "\(pickup) s\(min(6, max(1, settings.hiveSlot)))" : pickup
        let key = pickup.replacingOccurrences(of: " ", with: "_")
        var pf = pathLookup("to_pickup", slotName, variant)
        if pf == nil && variant != "walk" { pf = pathLookup("to_pickup", slotName, "walk") }
        if pf == nil { pf = pathLookup("to_pickup", key, "walk") }
        guard let path = pf else { status("warning", "no route for \(pickup)"); return false }
        status("traveling", pickup)
        guard walkPath(path) else { return false }
        for _ in 0..<2 {
            actuator.tap("e", holdS: 0.1)
            wait(0.6)
        }
        wait(1.0)
        status("traveling", "collected \(pickup)")
        return !stopped
    }

    /// Goes to the field and gathers for `seconds` with the tool in hand, so the bees and the tool
    /// deal with whatever is there. Returns true when it ran to the end (no death, no stop).
    public func hunt(field: String, seconds: Double) -> Bool {
        if !resetToHive(afterDeath: died) { return false }
        var f = FieldConfig(name: field)
        f.sprinklerLocation = "center"; f.camera = "none"; f.turns = 1
        f.minutes = seconds / 60; f.backpackPercent = 100
        status("traveling", field)
        guard travelTo(f) else { return false }
        let r = gather(f)
        return r.reason == "time" || r.reason == "backpack"
    }
}

/// The runner HiveMac uses: it collects pickups and hunts mobs. Planters are not built (placing one
/// needs the inventory), so a planter step only reports that it is due.
public final class GameExtraRunner: ExtraRunner {
    public var timers: MobTimers
    public var onTimers: (MobTimers) -> Void
    public var huntSeconds: Double
    private let unixNow: () -> TimeInterval

    public init(timers: MobTimers = MobTimers(), huntSeconds: Double = 90,
                unixNow: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
                onTimers: @escaping (MobTimers) -> Void = { _ in }) {
        self.timers = timers; self.huntSeconds = huntSeconds; self.unixNow = unixNow; self.onTimers = onTimers
    }

    public func due(_ step: ExtraStep, now: TimeInterval) -> [String] {
        switch step.kind {
        case "planters": return step.planterSlotsReady(now: now).map { "slot \($0 + 1)" }
        case "bug_run": return timers.due(step.bugs.filter { !MobFields.notBuilt.contains($0) }, now: now)
        default: return timers.due(step.bugs, now: now)
        }
    }

    private func done(_ names: [String]) {
        for n in names { timers.markDone(n, at: unixNow()) }
        onTimers(timers)
    }

    public func perform(_ step: ExtraStep, due: [String], game: Game) {
        switch step.kind {
        case "pickups":
            for p in due {
                if game.stopped { return }
                if game.collect(p) { done([p]) }
            }
        case "bug_run":
            for group in MobFields.plan(due) {
                if game.stopped { return }
                game.status("traveling", "bug run: \(group.mobs.joined(separator: ", ")) at \(group.field)")
                if game.hunt(field: group.field, seconds: huntSeconds) { done(group.mobs) }
            }
        default:
            game.status("warning", "\(due.joined(separator: ", ")) due, but planters are not built yet")
        }
    }
}
