import Foundation

/// A boss fight, from Natro Macro (GPL-3.0): where to stand, how to fight and how to tell it is dead.
/// Natro's own timings (milliseconds at base walk speed) are kept; they are scaled to the current speed.
public struct BossSpec: Equatable, Sendable {
    public var name: String                 // timer name, also the status text
    /// A route file in `to_boss`, or a field route in `to_field` followed by `approach`.
    public var route: String? = nil
    public var field: String? = nil
    public var approachMs: [(keys: [String], ms: Double)] = []
    public var approachTurn: (String, Int)? = nil
    /// One round of moving around the boss, while the tool keeps hitting.
    public var fightMs: [(keys: [String], ms: Double)] = []
    /// A picture that only shows when the boss is dead (Natro's, searched in the lower right).
    public var deadPicture: String? = nil
    public var deadTolerance = 25
    /// After it died: sweeps to pick up the loot.
    public var lootMs: [(keys: [String], ms: Double)] = []
    public var maxSeconds = 900.0
    public var searchSeconds = 8.0
    /// Seconds without a health bar, after seeing one, that count as dead.
    public var quietSeconds = 8.0
    /// When it is not there, or the fight timed out, try again in this long.
    public var missRetryS = 7200.0
    public var timeoutRetryS = 1800.0

    public static func == (a: BossSpec, b: BossSpec) -> Bool { a.name == b.name }
}

public enum Bosses {
    static func left(_ ms: Double) -> (keys: [String], ms: Double) { (["a"], ms) }
    static func right(_ ms: Double) -> (keys: [String], ms: Double) { (["d"], ms) }
    static func fwd(_ ms: Double) -> (keys: [String], ms: Double) { (["w"], ms) }
    static func back(_ ms: Double) -> (keys: [String], ms: Double) { (["s"], ms) }

    public static let all: [BossSpec] = [
        // Natro: Coconut field, a little right and back, then side to side so the crab's claws miss.
        BossSpec(name: "coconut crab", field: "coconut",
                 approachMs: [right(1400), back(1000)],
                 fightMs: [fwd(1000), left(2000), left(2000), back(1000), right(2000), right(2000)],
                 deadPicture: "crab", deadTolerance: 70,
                 lootMs: [right(1500), left(3000), right(3000), left(3000)],
                 maxSeconds: 900),
        // Natro: Blue Flower field, then into the beetle's lair; it fights back so the macro keeps moving.
        BossSpec(name: "king beetle", field: "blue flower",
                 approachMs: [(["d", "w"], 5000), fwd(4000)], approachTurn: ("right", 2),
                 fightMs: [back(2000), right(2000), back(2000), right(2000), left(2000), left(2000)],
                 deadPicture: "king",
                 lootMs: [right(1500), left(3000), right(3000)],
                 maxSeconds: 900),
        // Natro: the long walk through the tunnel; the bear stays in its chamber.
        BossSpec(name: "tunnel bear", route: "tunnel_bear",
                 fightMs: [back(200)],
                 deadPicture: "tunnelbeardead",
                 lootMs: [fwd(12000), back(18000)],
                 maxSeconds: 900, quietSeconds: 10),
        // Natro: Stump field, stand at the snail's tree and sweep small squares.
        BossSpec(name: "stump snail", field: "stump",
                 approachMs: [fwd(1000)],
                 fightMs: [right(500), fwd(500), left(500), back(1000), left(500), fwd(500), right(1000), back(500)],
                 maxSeconds: 900),
    ]

    public static func spec(_ name: String) -> BossSpec? { all.first { $0.name == name } }
    public static var names: [String] { all.map(\.name) }
}

extension Game {
    private func seconds(forMs ms: Double) -> Double { ms / 1000.0 * 28.0 / max(1, speed.current()) }

    private func moves(_ list: [(keys: [String], ms: Double)]) {
        for m in list {
            if stopped { return }
            walker.hold(m.keys, seconds(forMs: m.ms))
        }
    }

    /// Goes to the boss, looks for its health bar, fights until the bar has been gone for a few seconds
    /// (or the dead picture shows), then picks up the loot. Without a readable screen it gives up.
    public func boss(_ spec: BossSpec) -> HuntResult {
        if !resetToHive(afterDeath: died) { return .interrupted }
        status("traveling", spec.name)
        if let r = spec.route {
            guard let path = pathLookup("to_boss", r, "walk") else { status("warning", "no route to \(spec.name)"); return .interrupted }
            guard walkPath(path) else { return .interrupted }
        } else if let f = spec.field {
            guard let path = pathLookup("to_field", f, settings.travel) ?? pathLookup("to_field", f, "walk") else {
                status("warning", "no route to \(f)"); return .interrupted
            }
            guard walkPath(path) else { return .interrupted }
        }
        moves(spec.approachMs)
        if let t = spec.approachTurn { walker.rotate(t.0, taps: t.1, leftKey: settings.rotLeft, rightKey: settings.rotRight) }
        if stopped { return .interrupted }

        guard sensors.mobBars() != nil else { status("warning", "\(spec.name): cannot read the health bar, skipping"); return .none }
        status("gathering", "looking for \(spec.name)")
        var found = false
        let look = clock.now()
        while !found && !stopped && clock.now() - look < spec.searchSeconds {
            found = !(sensors.mobBars() ?? []).isEmpty
            if !found { wait(0.4) }
        }
        if !found { status("warning", "no \(spec.name) there"); return .none }

        status("gathering", "fighting \(spec.name)")
        parkMouse()
        if settings.useTool { actuator.mouseDown() }
        defer { if settings.useTool { actuator.mouseUp() } }
        let t0 = clock.now()
        var quietSince: Double? = nil
        var dead = false
        while !stopped {
            if sensors.healthGrey() { died = true; return .interrupted }
            moves(spec.fightMs.isEmpty ? [(["w"], 100)] : spec.fightMs)
            if stopped { break }
            let bars = sensors.mobBars() ?? []
            if bars.isEmpty { if quietSince == nil { quietSince = clock.now() } } else { quietSince = nil }
            if let q = quietSince, clock.now() - q >= spec.quietSeconds { dead = true }
            if let p = spec.deadPicture,
               sensors.find(p, in: RelRegion(fx: 0.5, fy: 0.5, fw: 0.5, fh: 0.5), tolerance: spec.deadTolerance) != nil { dead = true }
            if dead { break }
            if clock.now() - t0 >= spec.maxSeconds {
                status("warning", "\(spec.name) would not go down, trying again later")
                return .timeout
            }
        }
        if stopped { return .interrupted }
        status("gathering", "\(spec.name) is down, collecting the loot")
        actuator.mouseUp()
        moves(spec.lootMs)
        return .killed
    }
}
