import Foundation

public let studsPerTile = 4.0

/// Key and mouse output. The real one posts CGEvents; tests use a fake.
public protocol Actuator: AnyObject {
    func keyDown(_ key: String)
    func keyUp(_ key: String)
    func tap(_ key: String, holdS: Double)
    func mouseDown()
    func mouseUp()
    func releaseAll()
    /// Optional: park the pointer. Defaults to doing nothing.
    func moveMouse(_ x: Int, _ y: Int)
    /// Optional: one left click at a screen point.
    func click(_ x: Int, _ y: Int)
    /// Optional: press at one point, drag to another, let go.
    func drag(fromX: Int, fromY: Int, toX: Int, toY: Int)
    /// Optional: wheel ticks at the pointer, positive scrolls up.
    func scroll(_ ticks: Int)
}

public extension Actuator {
    func moveMouse(_ x: Int, _ y: Int) {}
    func click(_ x: Int, _ y: Int) {}
    func drag(fromX: Int, fromY: Int, toX: Int, toY: Int) {}
    func scroll(_ ticks: Int) {}
}

public protocol Clock: AnyObject {
    func now() -> Double
    func sleep(_ seconds: Double)
}

public final class RealClock: Clock {
    public init() {}
    public func now() -> Double { ProcessInfo.processInfo.systemUptime }
    public func sleep(_ seconds: Double) { if seconds > 0 { Thread.sleep(forTimeInterval: seconds) } }
}

/// A thread safe on/off flag, used for stop and pause.
public final class Signal: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    public init(_ initial: Bool = false) { flag = initial }
    public var isSet: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    public func set() { lock.lock(); flag = true; lock.unlock() }
    public func clear() { lock.lock(); flag = false; lock.unlock() }
}

/// Walk speed in studs per second: base from settings times a live multiplier.
public struct SpeedModel {
    public var baseSpeed: Double
    public var multiplier: () -> Double
    /// The walk speed read from the game's stats panel ("Movespeed: 33") a moment ago. When set it wins over the settings.
    public var live: () -> Double? = { nil }
    /// True when `live` is worked out from the buff bar (settings speed times the buffs): the multiplier still applies on top of it.
    public var liveIsBuffModel = false

    public init(baseSpeed: Double = 28, multiplier: @escaping () -> Double = { 1.0 }) {
        self.baseSpeed = baseSpeed; self.multiplier = multiplier
    }

    public func current() -> Double {
        var m = multiplier()
        if m <= 0 { m = 1 }
        if let l = live(), l >= 5, l <= 200 { return liveIsBuffModel ? l * m : l }
        return max(1, baseSpeed) * m
    }

    public func secondsForTiles(_ tiles: Double) -> Double { max(0, tiles) * studsPerTile / current() }
}

/// Open loop walking, the Natro way: hold a key for `4 * tiles / speed` seconds, in small
/// slices so a stop or pause interrupts within `slice` seconds. Keys are always released.
public final class Walker {
    public var speed: SpeedModel
    private let act: Actuator
    private let clock: Clock
    private let stop: Signal
    private let pause: Signal?
    private let slice: Double

    public init(actuator: Actuator, speed: SpeedModel, clock: Clock = RealClock(), stop: Signal = Signal(),
                pause: Signal? = nil, slice: Double = 0.05) {
        self.act = actuator; self.speed = speed; self.clock = clock; self.stop = stop; self.pause = pause; self.slice = slice
    }

    public var stopped: Bool { stop.isSet }

    /// Checked about twice a second while keys are held. When it returns true the walk ends at once, so a walk to a
    /// pickup can stop the moment the game shows that pickup's prompt, whatever the walk speed was.
    public private(set) var probeHit = false
    private var probe: (() -> Bool)?
    private var lastProbeAt = 0.0
    public var probeEveryS = 0.5
    public func armProbe(_ p: (() -> Bool)?) { probe = p; probeHit = false; lastProbeAt = clock.now() }

    /// Hold keys for `seconds` of effective (unpaused) time. Returns how long they were held.
    @discardableResult
    public func hold(_ keys: [String], _ seconds: Double) -> Double {
        var held = 0.0
        if stop.isSet || probeHit { return held }
        keys.forEach(act.keyDown)
        defer { keys.forEach(act.keyUp) }
        var remaining = seconds
        while remaining > 0 && !stop.isSet {
            if let pause, pause.isSet {
                keys.forEach(act.keyUp)
                while pause.isSet && !stop.isSet { clock.sleep(slice) }
                if stop.isSet { return held }
                keys.forEach(act.keyDown)
            }
            let step = min(slice, remaining)
            let t0 = clock.now()
            clock.sleep(step)
            if let probe, clock.now() - lastProbeAt >= probeEveryS {
                lastProbeAt = clock.now()
                if probe() { probeHit = true; held += clock.now() - t0; break }
            }
            // The whole iteration counts, including the prompt check: the keys stay held while it runs.
            var dt = clock.now() - t0
            if dt <= 0 { dt = step }
            held += dt
            remaining -= dt
        }
        return held
    }

    /// Reads the live walk speed; called every `speedSampleEveryS` while walking. Returns nil when it cannot be read.
    public var speedSampler: (() -> Double?)?
    public var speedSampleEveryS = 1.0
    /// A reading that is computed from the buff bar (Natro's formula) is trusted as it is. Off: a reading has to look
    /// plausible next to the speed in the settings (for a speed read as text, where a digit can be wrong).
    public var speedSamplerTrusted = false
    public private(set) var liveSpeed: Double?
    private var lastSpeedAt = -1e9
    public func sampleSpeed(force: Bool = false) {
        guard let sampler = speedSampler else { return }
        if !force, clock.now() - lastSpeedAt < speedSampleEveryS { return }
        lastSpeedAt = clock.now()
        guard let v = sampler() else { return }
        if speedSamplerTrusted { liveSpeed = v; return }
        // A misread digit ("9" for "29", "4" for "34") would stretch or shrink a whole walk, so a reading must be
        // plausible next to the speed in the settings and not jump far from the last good one without repeating.
        let base = speed.baseSpeed
        guard v >= base * 0.75, v <= base * 1.6 else { rejectedSpeed = 0; return }
        if let last = liveSpeed, abs(v - last) > last * 0.25 {
            rejectedSpeed += 1
            if rejectedSpeed < 2 { return }                  // a big change has to show up twice in a row
        }
        rejectedSpeed = 0
        liveSpeed = v
    }
    private var rejectedSpeed = 0

    /// Natro's nm_Walk, with the distance integrated over time: the speed is read again every second, so a morph or
    /// Haste starting or ending in the middle of a walk changes the hold time instead of throwing the route off.
    @discardableResult
    public func walk(_ keys: [String], tiles: Double) -> Double {
        sampleSpeed(force: true)
        guard speedSampler != nil, liveSpeed != nil else { return hold(keys, speed.secondsForTiles(tiles)) }
        var held = 0.0
        if stop.isSet || probeHit { return held }
        keys.forEach(act.keyDown)
        defer { keys.forEach(act.keyUp) }
        var remaining = max(0, tiles)                       // tiles left to walk
        var last = clock.now()
        var vPrev = speed.current()
        remaining -= 0.125 / studsPerTile                    // Natro's head start is 0.125 of a stud (freq // 8), not an eighth of a second
        while remaining > 0 && !stop.isSet {
            if let pause, pause.isSet {
                keys.forEach(act.keyUp)
                while pause.isSet && !stop.isSet { clock.sleep(slice) }
                if stop.isSet { return held }
                keys.forEach(act.keyDown)
                last = clock.now()
            }
            clock.sleep(slice)
            // Elapsed time since the last pass, including the time the speed reading and the prompt check took:
            // the keys were held that whole time. (Counting only the sleep made every walk run too long.)
            let now = clock.now()
            var dt = now - last
            if dt <= 0 { dt = slice }
            last = now
            held += dt
            sampleSpeed()
            let vNow = speed.current()
            remaining -= (vPrev + vNow) / 2 * dt / studsPerTile      // trapezoid of the old and the new speed, like Natro
            vPrev = vNow
            if let probe, clock.now() - lastProbeAt >= probeEveryS {
                lastProbeAt = clock.now()
                if probe() { probeHit = true; break }
            }
        }
        return held
    }

    public func wait(_ seconds: Double) {
        let end = clock.now() + seconds
        while !stop.isSet {
            let left = end - clock.now()
            if left <= 0 { return }
            clock.sleep(min(slice, left))
        }
    }

    /// How long a tap holds the key. Short enough not to auto-repeat, long enough for a slow frame rate to see it.
    public static let tapHoldS = 0.12
    /// Esc, R and Enter of the reset: held longer, because a missed reset leaves the character far from the hive.
    public static let resetKeyHoldS = 0.5
    /// A hold that includes Space (a jump) lasts at least this long.
    public static let jumpHoldS = 0.08
    /// Natro sends {space 2} as two quick presses to open the glider: short holds with a small gap, nothing in between.
    public static let glideHoldS = 0.05
    public static let glideGapS = 0.04

    public func taps(_ key: String, count: Int, gap: Double = 0.12) {
        for _ in 0..<count {
            if stop.isSet { return }
            act.tap(key, holdS: Self.tapHoldS)
            clock.sleep(gap)
        }
    }

    /// Camera yaw: one tap of , or . is 45 degrees in Roblox.
    public func rotate(_ direction: String, taps n: Int, leftKey: String = ",", rightKey: String = ".") {
        taps(direction == "left" ? leftKey : rightKey, count: n)
    }

    public enum WalkError: Error { case unknownStep(String) }

    /// Execute path or pattern steps. Returns false if interrupted by stop.
    @discardableResult
    public func run(_ steps: [Step], keymap: [String: String] = [:]) throws -> Bool {
        func mapped(_ k: String) -> String { keymap[k] ?? k }
        for s in steps {
            if stop.isSet { return false }
            switch s.type {
            case "walk": walk(s.keys.map(mapped), tiles: s.tiles)
            // A jump (Space) held for 0.05 to 0.1 s can fall between two frames on a slow Mac and never happen: hold it longer.
            case "hold": hold(s.keys.map(mapped), s.keys.contains("space") ? max(s.seconds, Walker.jumpHoldS) : s.seconds)
            case "keydown": s.keys.map(mapped).forEach { act.keyDown($0) }
            case "keyup": s.keys.map(mapped).reversed().forEach { act.keyUp($0) }
            case "rotate": rotate(s.direction, taps: s.count, leftKey: keymap["rot_left"] ?? ",", rightKey: keymap["rot_right"] ?? ".")
            case "tap": taps(mapped(s.key), count: s.count)
            case "jump": act.tap("space", holdS: Walker.jumpHoldS)
            case "jump2":
                act.tap("space", holdS: Walker.glideHoldS); clock.sleep(Walker.glideGapS)
                act.tap("space", holdS: Walker.glideHoldS)
            case "wait": wait(s.seconds)
            case "zoom": taps(s.direction == "out" ? (keymap["zoom_out"] ?? "o") : (keymap["zoom_in"] ?? "i"), count: s.count)
            case "mouse": s.direction == "down" ? act.mouseDown() : act.mouseUp()
            default: throw WalkError.unknownStep(s.type)
            }
        }
        return !stop.isSet
    }
}
