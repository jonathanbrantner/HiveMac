import Foundation

/// What the macro can see. The real one reads small screen regions; tests use a simulated world.
/// Optional answers (`Bool?`) mean "no check is set up", and the loop then assumes the best.
public protocol Sensors: AnyObject {
    func robloxPresent() -> Bool
    func backpackPercent() -> Int
    func backpackUnreadableStreak() -> Int
    func resetBackpackFilter()
    func healthGrey() -> Bool
    func hivePromptVisible() -> Bool?
    func hiveViewVisible() -> Bool?
    func cannonPromptVisible() -> Bool?
    func deathTextVisible() -> Bool?
    /// Centre of a named picture (a file in the templates or built-in images) inside a part of the
    /// window, in screen coordinates (ready to click). nil when it is not there or there is no such picture.
    func find(_ template: String, in region: RelRegion?, tolerance: Int) -> (x: Int, y: Int)?
    /// True while the hive prompt says "Stop Making Honey" (converting is already on). nil when unknown.
    func honeyRunning() -> Bool?
    /// What the hive message says: "make" (E starts converting), "stop" (converting now), "empty" (nothing
    /// left to convert, balloon included). nil when it cannot be read.
    func hiveMessage() -> String?
    /// Share of the screen that is honeycomb gold, 0 to 1: high when the camera faces the hive. nil when unreadable.
    func hiveViewShare() -> Double?
    /// Percent left of every mob health bar on screen. nil when the screen cannot be read.
    func mobBars() -> [Double]?
    /// Words of the prompt at the top of the screen ("Use the Strawberry Dispenser (3:59:58)"). nil when unreadable.
    func promptText() -> String?
    /// A picture of an absolute screen rectangle. nil when unreadable.
    func picture(left: Int, top: Int, width: Int, height: Int) -> RGBImage?
    /// Words in a part of the window (the quest log, a dialog box). nil when unreadable.
    func textIn(_ region: RelRegion) -> String?
    /// A spot in the window by its share of width and height, in screen coordinates (ready to click).
    func point(fx: Double, fy: Double) -> (x: Int, y: Int)?
}

public extension Sensors {
    func find(_ template: String, in region: RelRegion?, tolerance: Int) -> (x: Int, y: Int)? { nil }
    func honeyRunning() -> Bool? { nil }
    func hiveMessage() -> String? { nil }
    func hiveViewShare() -> Double? { nil }
    func mobBars() -> [Double]? { nil }
    func promptText() -> String? { nil }
    func picture(left: Int, top: Int, width: Int, height: Int) -> RGBImage? { nil }
    func textIn(_ region: RelRegion) -> String? { nil }
    func point(fx: Double, fy: Double) -> (x: Int, y: Int)? { nil }
}

public struct GameSettings: Equatable, Sendable {
    public var walkSpeed = 28.0
    public var hiveSlot = 1
    public var sprinklerType = "none"
    public var sprinklerSlotKey = "1"
    public var travel = "walk"              // default path variant: walk or cannon
    public var windowMode = "windowed"
    public var titleBarHeight = 28
    /// Natro measures its menu spots in window pixels. Scale and the top bar height can be tuned if a Mac window differs.
    public var uiScale = 1.0
    public var uiOffsetY = 36
    public var zoomOutTaps = 6
    public var resetWaitS = 2.0             // minimum time between reset and the next walk
    public var deathExtraWaitS = 18.0       // the death screen is longer than a plain reset
    /// Resets tried before giving up. Capped at 2: a third Esc, R, Enter never fixes a check that is wrong.
    public var resetAttempts = 2
    /// After a reset the hive prompt may show a moment late: look this long before calling it a miss.
    public var hivePromptRecheckS = 4.0
    public var respawnTimeoutS = 12.0
    public var convertTimeoutS = 300.0
    /// After the bag is empty, keep converting until the hive balloon is empty too (Natro's "convert balloon").
    public var convertBalloon = true
    /// The honeycomb share that counts as "the hive is in view".
    public var hiveShareMin = 0.05
    public var convertPressRetryS = 6.0
    public var cameraSearchTaps = 2         // yaw step while looking for the hive view
    public var cameraAfterFoundTaps = 4     // Natro: 180 degrees once the hive is in view
    public var useTool = true               // hold the mouse button while gathering
    public var backpackSampleS = 1.0
    public var lostScreenS = 60.0           // unreadable backpack this long means we are lost
    public var keyGapS = 0.3                // between Esc, R, Enter
    public var rotLeft = ","
    public var rotRight = "."
    public var zoomIn = "i"
    public var zoomOut = "o"
    public var mousePark: (x: Double, y: Double) = (0.25, 0.2)   // fraction of the window

    public init() {}

    public static func == (a: GameSettings, b: GameSettings) -> Bool {
        a.walkSpeed == b.walkSpeed && a.hiveSlot == b.hiveSlot && a.travel == b.travel
            && a.zoomOutTaps == b.zoomOutTaps && a.resetWaitS == b.resetWaitS
            && a.mousePark.x == b.mousePark.x && a.mousePark.y == b.mousePark.y
    }
}

public struct FieldConfig: Equatable, Sendable {
    /// Tells two rows of the same field apart. Not saved, and not part of equality.
    public var id = UUID()
    public var name: String
    public var pattern = "corner_x_snake"
    public var size = "m"
    public var width = 4
    public var invertFB = false
    public var invertLR = false
    public var camera = "none"              // none, left, right
    public var turns = 1
    public var minutes = 10.0
    public var backpackPercent = 95
    public var sprinklerLocation = "center"
    public var sprinklerDistance = 1
    public var shiftLock = false
    public var travel = "default"           // default, walk, cannon
    /// walk: Natro's default (walk to the hive and convert there). reset: Esc R Enter instead.
    public var returnMethod = "walk"
    public var enabled = true

    /// True when the field turns the camera after arriving (and back before leaving).
    public var rotatesCamera: Bool { (camera == "left" || camera == "right") && turns > 0 }

    /// Natro's defaults for the field, with the fields given in `overrides` replacing them.
    public init(name: String) {
        let lower = name.lowercased()
        self.name = lower
        if let d = FieldDefaults.table[lower] {
            pattern = d.pattern; size = d.size; width = d.width; camera = d.camera; turns = d.turns
            sprinklerLocation = d.sprinkler; sprinklerDistance = d.distance
            invertFB = d.invertFB; invertLR = d.invertLR
        }
    }

    public static func == (a: FieldConfig, b: FieldConfig) -> Bool {
        var x = a; x.id = b.id
        return x.name == b.name && x.pattern == b.pattern && x.size == b.size && x.width == b.width
            && x.invertFB == b.invertFB && x.invertLR == b.invertLR && x.camera == b.camera && x.turns == b.turns
            && x.minutes == b.minutes && x.backpackPercent == b.backpackPercent
            && x.sprinklerLocation == b.sprinklerLocation && x.sprinklerDistance == b.sprinklerDistance
            && x.shiftLock == b.shiftLock && x.travel == b.travel && x.returnMethod == b.returnMethod && x.enabled == b.enabled
    }
}

public struct GatherResult: Equatable, Sendable {
    public var reason: String       // backpack, time, death, lost, stopped
    public var seconds: Double = 0
    public var backpack: Int = 0
    public init(reason: String, seconds: Double = 0, backpack: Int = 0) {
        self.reason = reason; self.seconds = seconds; self.backpack = backpack
    }
}

public typealias PathLookup = (_ kind: String, _ field: String, _ variant: String) -> PathFile?

/// The Natro style game actions, written against `Sensors` and `Actuator` so the whole loop
/// runs in tests with fakes. Every action is interruptible through the walker's stop and
/// pause signals and leaves no key held when it returns.
public final class Game {
    public let actuator: Actuator
    public let sensors: Sensors
    public var settings: GameSettings
    public let clock: Clock
    public let stop: Signal
    public let pause: Signal
    public let walker: Walker
    public var speed: SpeedModel { walker.speed }
    public var status: (_ state: String, _ detail: String) -> Void
    public var windowSize: () -> (left: Int, top: Int, width: Int, height: Int)?
    public var pathLookup: PathLookup

    public private(set) var shiftLocked = false
    public var died = false
    /// Seconds since 1970; replaced in tests.
    public var unixNow: () -> TimeInterval = { Date().timeIntervalSince1970 }

    public init(actuator: Actuator, sensors: Sensors, settings: GameSettings, clock: Clock,
                stop: Signal = Signal(), pause: Signal = Signal(),
                speedMultiplier: @escaping () -> Double = { 1.0 },
                status: @escaping (String, String) -> Void = { _, _ in },
                windowSize: @escaping () -> (left: Int, top: Int, width: Int, height: Int)? = { nil },
                pathLookup: @escaping PathLookup = { _, _, _ in nil }) {
        self.actuator = actuator; self.sensors = sensors; self.settings = settings; self.clock = clock
        self.stop = stop; self.pause = pause; self.status = status
        self.windowSize = windowSize; self.pathLookup = pathLookup
        self.walker = Walker(actuator: actuator, speed: SpeedModel(baseSpeed: settings.walkSpeed, multiplier: speedMultiplier),
                             clock: clock, stop: stop, pause: pause)
    }

    public var stopped: Bool { stop.isSet }

    func wait(_ s: Double) { walker.wait(s) }
    /// Roblox on a slow Mac can miss a 30 ms press that falls between two frames, so a tap is held for 120 ms.
    func tap(_ key: String) { actuator.tap(key, holdS: Walker.tapHoldS) }

    public func keymap() -> [String: String] {
        ["rot_left": settings.rotLeft, "rot_right": settings.rotRight,
         "zoom_in": settings.zoomIn, "zoom_out": settings.zoomOut]
    }

    func run(_ steps: [Step], _ km: [String: String]? = nil) {
        _ = try? walker.run(steps, keymap: km ?? keymap())
    }

    func iterSteps(_ pf: PathFile) -> [Step] {
        Paths.scaleHolds(Paths.expand(pf.steps, hiveSlot: settings.hiveSlot),
                         recordedSpeed: pf.walkSpeed, actualSpeed: speed.current())
    }

    public func parkMouse() {
        guard let ws = windowSize() else { return }
        actuator.moveMouse(ws.left + Int(Double(ws.width) * settings.mousePark.x),
                           ws.top + Int(Double(ws.height) * settings.mousePark.y))
    }

    public func setShiftLock(_ on: Bool) {
        if on != shiftLocked { tap("shift"); shiftLocked = on; wait(0.2) }
    }

    public func releaseEverything() { actuator.releaseAll() }

    // MARK: Reset

    /// Esc, R, Enter; wait for the respawn; confirm the hive; fix the camera.
    public func resetToHive(afterDeath: Bool = false) -> Bool {
        let s = settings
        releaseEverything()
        setShiftLock(false)
        stepHook?("reset", 0, 0, "begin")
        for attempt in 1...min(2, max(1, s.resetAttempts)) {
            if stopped { return false }
            status("resetting", "attempt \(attempt)")
            parkMouse()
            pressReset()
            stepHook?("reset", 1, 0, "a\(attempt)-after-keys")
            waitForRespawn()
            let extra = (afterDeath || died) ? s.deathExtraWaitS : 0
            died = false
            wait(s.resetWaitS + extra)
            if stopped { return false }
            sensors.resetBackpackFilter()
            stepHook?("reset", 2, 0, "a\(attempt)-after-respawn-wait")
            var atHive = sensors.hivePromptVisible()
            let looked = clock.now()
            while atHive == false && clock.now() - looked < s.hivePromptRecheckS && !stopped {
                wait(0.5)
                atHive = sensors.hivePromptVisible()
            }
            if atHive == false {
                status("resetting", attempt < min(2, max(1, s.resetAttempts)) ? "hive prompt not seen, trying one more reset" : "hive prompt not seen")
                continue
            }
            if atHive == nil { status("resetting", "no hive prompt template, assuming at hive") }
            let aligned = fixCamera()
            stepHook?("reset", 3, 0, "a\(attempt)-after-camera")
            if !aligned && attempt < min(2, max(1, s.resetAttempts)) { status("resetting", "the camera could not be aligned, trying the reset again"); continue }
            return true
        }
        status("error", "could not see the hive prompt after the reset. Check that you are not stuck somewhere, and check the Hive prompt pictures in Calibrate.")
        return false
    }

    /// True when the Roblox menu (Resume, Reset Character, Leave Game) is on screen; nil when the screen cannot be read.
    private func robloxMenuOpen() -> Bool? {
        guard let text = sensors.textIn(RelRegion(fx: 0, fy: 0, fw: 1, fh: 1))?.lowercased() else { lastMenuText = "(unreadable)"; return nil }
        lastMenuText = String(text.prefix(90)).replacingOccurrences(of: "\n", with: " | ")
        return text.contains("reset character") || text.contains("resume") || text.contains("leave game")
    }

    /// Esc, R, Enter, but only while the menu really is open. A blind Enter when the menu did not open focuses the chat
    /// box, and from then on every Esc only closes the chat, so one missed Esc used to break every reset after it.
    private var lastMenuText = ""
    private func pressReset() {
        let s = settings
        if robloxMenuOpen() == nil {                       // cannot read the screen: the plain sequence
            tap("esc"); wait(s.keyGapS); tap("r"); wait(s.keyGapS); tap("enter")
            return
        }
        var opened = robloxMenuOpen() == true
        status("resetting", "menu check before Esc: \(opened ? "OPEN" : "closed"), screen reads: \(lastMenuText)")
        var tries = 0
        while !opened && tries < 4 && !stopped {
            tries += 1
            actuator.tap("esc", holdS: 0.2)
            wait(0.9)
            opened = robloxMenuOpen() == true
            status("resetting", "Esc try \(tries): menu \(opened ? "open" : "not open"), screen reads: \(lastMenuText)")
        }
        guard opened else { status("warning", "the Roblox menu did not open after Esc (\(tries) tries), not pressing R or Enter"); return }
        if tries > 1 { status("resetting", "the menu opened on Esc try \(tries)") }
        actuator.tap("r", holdS: 0.2)
        wait(0.9)
        actuator.tap("enter", holdS: 0.2)
    }

    /// Natro: the health bar goes grey (dead) then comes back. Falls back to a fixed wait.
    private func waitForRespawn() {
        let t0 = clock.now()
        var seenGrey = false
        while !stopped && clock.now() - t0 < settings.respawnTimeoutS {
            if sensors.healthGrey() { seenGrey = true } else if seenGrey { return }
            wait(0.1)
        }
        if !seenGrey { wait(1.0) }
    }

    /// Face away from the hive, whichever way the character spawned, then zoom out.
    /// Turn one full circle in eighths (one tap is an eighth), measure the honeycomb at each step, and
    /// finish by turning to half a circle past the heading where it was biggest.
    @discardableResult
    public func fixCamera() -> Bool {
        let s = settings
        var faced = true
        if sensors.hiveViewShare() != nil {
            faced = false
            for attempt in 1...3 where !faced {
                var best = -1.0
                var shares = [Double](repeating: 0, count: 8)
                for step in 0..<8 {
                    if stopped { return false }
                    let share = sensors.hiveViewShare() ?? 0
                    shares[step] = share
                    if share > best { best = share }
                    walker.rotate("right", taps: 1, leftKey: s.rotLeft, rightKey: s.rotRight)
                    wait(0.3)
                }
                guard best >= s.hiveShareMin else {
                    status("warning", "camera try \(attempt): the hive was not seen while turning (biggest share \(Int(best * 100)) percent)")
                    continue
                }
                // The hive is the heading with the most honeycomb in view, and facing away is half a circle from it.
                // When that peak is not clear (two headings close), take the heading with the least honeycomb instead.
                let peak = shares.firstIndex(of: best) ?? 0
                let second = shares.enumerated().filter { $0.offset != peak }.map(\.element).max() ?? 0
                // Standing at the hive, one heading shows the honeycomb wall and the others do not. A flat scan means the
                // character is somewhere else (the reset did not happen).
                guard best >= 0.30 || best >= second * 1.8 else {
                    status("warning", "camera try \(attempt): no clear hive in view (shares " + shares.map { String(format: "%.0f", $0 * 100) }.joined(separator: " ") + " percent), not at the hive")
                    return false
                }
                var bestStep = (peak + 4) % 8
                if best < second * 1.8 {
                    var bestScore = Double.greatestFiniteMagnitude
                    for i in 0..<8 {
                        let score = shares[i] + 0.5 * (shares[(i + 7) % 8] + shares[(i + 1) % 8])
                        if score < bestScore { bestScore = score; bestStep = i }
                    }
                }
                walker.rotate("right", taps: bestStep, leftKey: s.rotLeft, rightKey: s.rotRight)
                wait(0.4)
                // Check it from the screen: the honeycomb in view now should be about the smallest it was in the scan.
                let after = sensors.hiveViewShare() ?? 1
                let low = shares.min() ?? 0
                faced = after <= low + 0.10
                status("resetting", "camera try \(attempt): shares " + shares.map { String(format: "%.0f", $0 * 100) }.joined(separator: " ")
                       + " percent, turned \(bestStep), now \(Int(after * 100)) percent, " + (faced ? "facing away" : "NOT facing away, trying again"))
            }
            if !faced { status("warning", "the camera could not be turned away from the hive after 3 tries") }
        } else if let first = sensors.hiveViewVisible() {
            var found = first
            // Older check: turn until the hive picture shows, then half a circle.
            var taps = 0
            while found == false && taps < 16 && !stopped {
                walker.rotate("right", taps: s.cameraSearchTaps, leftKey: s.rotLeft, rightKey: s.rotRight)
                taps += s.cameraSearchTaps
                wait(0.25)
                found = sensors.hiveViewVisible() ?? true
            }
            if found { walker.rotate("right", taps: s.cameraAfterFoundTaps, leftKey: s.rotLeft, rightKey: s.rotRight) }
            else { faced = false; status("warning", "hive view not found while rotating") }
        }
        walker.taps(s.zoomOut, count: s.zoomOutTaps)
        return faced
    }

    // MARK: Convert

    /// Press E at the hive and wait until the backpack reads empty (Natro's nm_convert).
    public func convert() -> Bool {
        let s = settings
        if stopped { return false }
        status("converting", "")
        let t0 = clock.now()
        var lastPress = -1e9
        var emptyReads = 0
        var lastPct: Int?
        while !stopped && clock.now() - t0 < s.convertTimeoutS {
            let pct = sensors.backpackPercent()
            if lastPct == nil || (clock.now() - lastPress > s.convertPressRetryS && pct >= lastPct! && pct > 0) {
                // E toggles honey making: when the prompt already says "Stop Making Honey", pressing it would stop it.
                if sensors.honeyRunning() != true { tap("e") }
                lastPress = clock.now()
                lastPct = pct
            }
            if pct <= 0 {
                emptyReads += 1
                if emptyReads >= 3 {
                    if s.convertBalloon { convertBalloon() }
                    status("converting", "done")
                    return true
                }
            } else {
                emptyReads = 0
                lastPct = lastPct.map { min($0, pct) } ?? pct
            }
            wait(s.backpackSampleS)
        }
        return false
    }

    /// With the bag empty the hive can still hold balloon pollen: while the message says Make Honey, press E,
    /// and wait through Stop Making Honey until it shows the empty-bag message. Capped at 10 minutes.
    public func convertBalloon() {
        let t0 = clock.now()
        var unreadable = 0
        while !stopped && clock.now() - t0 < 600 {
            switch sensors.hiveMessage() {
            case "empty"?:
                if clock.now() - t0 > 1 { status("converting", "balloon done") }
                return
            case "make"?:
                unreadable = 0
                status("converting", "balloon")
                tap("e")
                wait(1.5)
            case "stop"?:
                unreadable = 0
                wait(1)
            default:
                unreadable += 1
                if unreadable >= 5 { return }
                wait(1)
            }
        }
    }

    // MARK: Travel

    public func travelTo(_ f: FieldConfig) -> Bool {
        let s = settings
        let variant = f.travel == "default" ? s.travel : f.travel
        var pf = pathLookup("to_field", f.name, variant)
        if pf == nil && variant != "walk" {
            status("traveling", "no \(variant) path for \(f.name), walking")
            pf = pathLookup("to_field", f.name, "walk")
        }
        guard let path = pf else { status("error", "no path to \(f.name)"); return false }
        status("traveling", f.name)
        if !walkPath(path) { return false }
        run(Sprinkler.startLocationSteps(field: f.name, location: f.sprinklerLocation,
                                         distance: f.sprinklerDistance, speed: speed.current()), [:])
        run(Sprinkler.placementSteps(type: s.sprinklerType, location: f.sprinklerLocation,
                                     slotKey: s.sprinklerSlotKey, speed: speed.current()), [:])
        if f.rotatesCamera {
            walker.rotate(f.camera, taps: f.turns, leftKey: s.rotLeft, rightKey: s.rotRight)
        }
        return !stopped
    }

    /// Walks a route from the hive: shift lock off, mouse parked, every step, the cannon where the route asks.
    /// Called at the start of a route (index 0) and after each step, so the screen can be saved frame by frame.
    /// Arguments: route name, step number, number of steps, a short description of the step just done.
    public var stepHook: ((String, Int, Int, String) -> Void)?

    /// True when the last walkPath ended early because its probe fired (the prompt it looked for was on screen).
    public private(set) var probeEnded = false

    public func walkPath(_ path: PathFile, probe: (() -> Bool)? = nil) -> Bool {
        setShiftLock(false)
        parkMouse()
        let steps = iterSteps(path)
        stepHook?(path.name, 0, steps.count, "start")
        walker.armProbe(probe)
        probeEnded = false
        defer { walker.armProbe(nil) }
        for (i, step) in steps.enumerated() {
            if stopped { return false }
            if walker.probeHit { probeEnded = true; stepHook?(path.name, i + 1, steps.count, "prompt-seen-end"); return true }
            if step.type == "gotocannon" {
                if !goToCannon() { return false }
                continue
            }
            run([step])
            let what = step.type == "walk" ? "walk-" + step.keys.joined() + "-" + String(format: "%.1f", step.tiles) : step.type
            stepHook?(path.name, i + 1, steps.count, what)
        }
        if walker.probeHit { probeEnded = true }
        stepHook?(path.name, steps.count + 1, steps.count, probeEnded ? "prompt-seen-end" : "end")
        return !stopped
    }

    /// Natro nm_gotoCannon, simplified: jump right onto the pad, then creep right until the
    /// cannon prompt shows (when a check exists).
    public func goToCannon() -> Bool {
        for _ in 0..<3 {
            if stopped { return false }
            actuator.keyDown("space"); actuator.keyDown("d")
            wait(0.1)
            actuator.keyUp("space")
            walker.walk(["d"], tiles: 2)
            walker.walk(["w", "d"], tiles: 1.5)
            actuator.keyUp("d")
            var seen = sensors.cannonPromptVisible()
            if seen == nil { return true }
            let t0 = clock.now()
            actuator.keyDown("d")
            while seen != true && clock.now() - t0 < 2.0 && !stopped {
                wait(0.1)
                seen = sensors.cannonPromptVisible()
            }
            actuator.keyUp("d")
            if seen == true { return true }
            status("traveling", "cannon not found, resetting")
            if !resetToHive() { return false }
            run(iterSteps(PathFile(name: "ramp", steps: [Step(type: "gotoramp")])))
        }
        return false
    }

    // MARK: Gather

    public func gather(_ f: FieldConfig) -> GatherResult {
        let s = settings
        var km = keymap()
        km.merge(Paths.bindPatternKeys(invertFB: f.invertFB, invertLR: f.invertLR)) { _, new in new }
        let steps = (try? Patterns.build(f.pattern, size: f.size, width: f.width)) ?? []
        status("gathering", "\(f.name) \(f.pattern) \(f.size) w\(f.width) until \(f.backpackPercent)% or \(f.minutes) min")
        let t0 = clock.now()
        var lastSample = -1e9
        var greyStreak = 0
        var reason = "stopped"
        var pct = sensors.backpackPercent()
        setShiftLock(f.shiftLock)
        parkMouse()
        if s.useTool { actuator.mouseDown() }
        defer {
            if s.useTool { actuator.mouseUp() }
            setShiftLock(false)
        }
        if steps.isEmpty { return GatherResult(reason: "stopped", seconds: 0, backpack: pct) }
        outer: while !stopped {
            for step in steps {
                if stopped { break outer }
                let now = clock.now()
                if now - lastSample >= s.backpackSampleS {
                    lastSample = now
                    pct = sensors.backpackPercent()
                    greyStreak = sensors.healthGrey() ? greyStreak + 1 : 0
                    let deadText = sensors.deathTextVisible() == true
                    if greyStreak >= 2 || deadText { died = true; reason = "death"; break outer }
                    if pct >= f.backpackPercent { reason = "backpack"; break outer }
                    if Double(sensors.backpackUnreadableStreak()) * s.backpackSampleS >= s.lostScreenS {
                        reason = "lost"; break outer
                    }
                }
                if now - t0 >= f.minutes * 60 { reason = "time"; break outer }
                run([step], km)
            }
        }
        if stopped { reason = "stopped" }
        return GatherResult(reason: reason, seconds: clock.now() - t0, backpack: pct)
    }

    // MARK: Walk back

    /// Walk from the field to the hive pad (Natro's wf-* routes), then slide left until the hive prompt shows.
    public func walkBack(_ f: FieldConfig) -> Bool {
        let s = settings
        guard let pf = pathLookup("to_hive", f.name, "walk") else { return false }
        status("traveling", "hive")
        if f.rotatesCamera {
            walker.rotate(f.camera == "left" ? "right" : "left", taps: f.turns, leftKey: s.rotLeft, rightKey: s.rotRight)
        }
        setShiftLock(false)
        for step in iterSteps(pf) {
            if stopped { return false }
            run([step])
        }
        let t0 = clock.now()
        var seen = sensors.hivePromptVisible()
        if seen == nil { return true }
        actuator.keyDown("a")
        while seen != true && clock.now() - t0 < 15 && !stopped {
            wait(0.1)
            seen = sensors.hivePromptVisible()
        }
        actuator.keyUp("a")
        return seen == true
    }
}
