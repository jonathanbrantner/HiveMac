import SwiftUI
import AppKit
import HiveMacCore
import HiveMacPlatform

/// Forwards every sensor read to the real sensors and reports the backpack reading, so the
/// window can show it live while the macro runs.
final class ReportingSensors: Sensors {
    let inner: Sensors
    var onBackpack: (Int) -> Void = { _ in }
    /// Practice mode: nothing is really reset, so the hive and respawn checks must not hold the run up.
    var practice = false
    init(_ inner: Sensors) { self.inner = inner }
    func robloxPresent() -> Bool { inner.robloxPresent() }
    func backpackPercent() -> Int { let p = inner.backpackPercent(); onBackpack(p); return p }
    func backpackUnreadableStreak() -> Int { inner.backpackUnreadableStreak() }
    func resetBackpackFilter() { inner.resetBackpackFilter() }
    func healthGrey() -> Bool { practice ? false : inner.healthGrey() }
    func hivePromptVisible() -> Bool? { practice ? nil : inner.hivePromptVisible() }
    func hiveViewVisible() -> Bool? { practice ? nil : inner.hiveViewVisible() }
    func honeyRunning() -> Bool? { practice ? nil : inner.honeyRunning() }
    func hiveMessage() -> String? { practice ? nil : inner.hiveMessage() }
    func hiveViewShare() -> Double? { practice ? nil : inner.hiveViewShare() }
    func mobBars() -> [Double]? { practice ? nil : inner.mobBars() }
    func promptText() -> String? { practice ? nil : inner.promptText() }
    func picture(left: Int, top: Int, width: Int, height: Int) -> RGBImage? { inner.picture(left: left, top: top, width: width, height: height) }
    func textIn(_ region: RelRegion) -> String? { practice ? nil : inner.textIn(region) }
    func point(fx: Double, fy: Double) -> (x: Int, y: Int)? { inner.point(fx: fx, fy: fy) }
    func moveSpeed() -> Double? { practice ? nil : inner.moveSpeed() }
    func cannonPromptVisible() -> Bool? { inner.cannonPromptVisible() }
    func deathTextVisible() -> Bool? { inner.deathTextVisible() }
    func find(_ template: String, in region: RelRegion?, tolerance: Int) -> (x: Int, y: Int)? { inner.find(template, in: region, tolerance: tolerance) }
}

enum RunState: String {
    case idle, resetting, converting, traveling, gathering, paused, warning, error

    var label: String { self == .error ? "Stopped" : rawValue.capitalized }
}

struct LiveReadings: Equatable {
    var windowFound = false
    var windowText = "Roblox not found"
    var backpack: Int?
    var backpackRGB: String?
    var healthGrey: Bool?
    var hivePrompt: Bool?
    /// The part of the screen the backpack reading looks at (a PNG), so you can see what it sees.
    var barPNG: Data?
    /// The numbers read from the bar, e.g. "23,763/140,827,431".
    var barText: String?
    /// The words read from the hive message area.
    var hiveText: String?
    /// How much of the screen is honeycomb gold (0 to 1): high when the camera faces the hive.
    var hiveShare: Double?
    var calibrated = false
}

@MainActor
final class AppModel: ObservableObject {
    // MARK: Published state
    @Published var state: RunState = .idle
    @Published var detail = ""
    @Published var running = false { didSet { syncHotKey() } }
    /// Set by the route test: run this pickup route this many times from the hive, instead of the profile.
    var pendingRouteTest: (name: String, times: Int, variant: String, prefix: Int?)?
    /// Bumped by the Collapse button; every step row folds itself shut when it changes.
    @Published var collapseTick = 0
    @Published var paused = false
    @Published var runtimeSeconds = 0
    @Published var stats = LoopStats()
    @Published var backpack: Int?
    /// What the backpack bar text read as the last time, for the status page and for finding misreads.
    var barTextSeen: String?
    @Published var currentField = ""
    @Published var log: [String] = []
    @Published var permissions = Permissions.current()
    @Published var live = LiveReadings()
    @Published var profile = Profile()
    @Published var runs: [RunEntry] = []
    @Published var mobTimers = MobTimers()
    @Published var recording = false
    @Published var calibMessage: String?
    let keyRecorder = KeyRecorder()
    @Published var remoteOn = false
    @Published var remoteURL = ""
    @Published var remoteMessage: String?
    var remote: RemoteServer?
    let beatLock = NSLock()
    var watchdog = Watchdog(now: Date().timeIntervalSince1970)
    func beat() { beatLock.lock(); watchdog.beat(at: Date().timeIntervalSince1970); beatLock.unlock() }
    func stalled() -> Bool { beatLock.lock(); defer { beatLock.unlock() }; return watchdog.isStalled(now: Date().timeIntervalSince1970, running: running, paused: paused) }
    @Published var activeRunFile = "default_profile.json"
    @Published var hive = HiveProfile()
    @Published var stopKeyName = "f9"
    @Published var stopKeyMessage: String?
    var capturingStopKey = false
    @Published var settingsVersion = 0

    // MARK: Engine
    let dirs: AppDirs
    let store: ConfigStore
    let stopSignal = Signal()
    let pauseSignal = Signal()
    var game: Game?
    let input = KeyInput()
    let capture = ScreenCapture()
    let hotKey = StopHotKey()
    var runtimeTimer: Timer?
    var pollTimer: DispatchSourceTimer?
    let pollQueue = DispatchQueue(label: "hivemac.poll", qos: .utility)
    let builtInPaths: URL
    var logFile: FileHandle?
    var lastAutoSnapshot = Date.distantPast
    var logWrites = 0

    init() {
        dirs = AppDirs.standard()
        try? dirs.ensure()
        builtInPaths = AppModel.findBuiltInPaths()
        let defaults = AppModel.findDefaultConfig()
        store = (try? ConfigStore(defaultsURL: defaults, url: dirs.settings)) ?? ConfigStore(defaults: [:], url: dirs.settings)
        activeRunFile = store.string("app.active_run_file", "default_profile.json")
        if !FileManager.default.fileExists(atPath: dirs.profiles.appendingPathComponent(activeRunFile).path) { activeRunFile = "default_profile.json" }
        profile = (try? Profile.load(dirs.profiles.appendingPathComponent(activeRunFile))) ?? Profile()
        hive = HiveProfile(store: store)
        refreshRuns()
        mobTimers = MobTimers.load(dirs.data.appendingPathComponent("mob_timers.json"))
        if store.bool("remote.enabled", false) && ProcessInfo.processInfo.environment["HIVEMAC_DEMO"] == nil { DispatchQueue.main.async { self.setRemote(true) } }
        logFile = AppModel.openLog(dirs.logs.appendingPathComponent("hivemac.log"))
        stopKeyName = store.string("app.emergency_stop_key", "f9")
        hotKey.onPress = { [weak self] in self?.stop("stop key pressed") }
        if case .failure = KeyCodes.validateStopKey(stopKeyName) { setStopKey("f9") }
        append("HiveMac started. Data folder: \(dirs.data.path)")
        if !isDemo && !permissions.allGranted { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Permissions.request() } }
        if ProcessInfo.processInfo.environment["HIVEMAC_DEMO"] != nil { applyDemo() } else { startPolling() }
    }


    /// The Roblox window content right now, using the window mode and title bar from the settings.
    static func bounds(_ store: ConfigStore) -> WindowBounds? {
        WindowFinder.contentBounds(mode: store.string("game.window_mode", "windowed"),
                                   titleBar: store.int("game.title_bar_height", 28))
    }
    var robloxBounds: WindowBounds? { Self.bounds(store) }

    // MARK: Resources
    static func resource(_ relative: String, dev: String) -> URL {
        if let r = Bundle.main.resourceURL?.appendingPathComponent(relative), FileManager.default.fileExists(atPath: r.path) { return r }
        // Running from the build folder (swift run): the repo is a few folders up from this file.
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return repo.appendingPathComponent(dev)
    }

    static func findBuiltInPaths() -> URL { resource("paths", dev: "config/paths/natro") }
    static var builtInImages: URL { resource("images", dev: "config/images/natro") }
    static var builtInHud: URL { resource("hud", dev: "config/images/hud") }

    /// A HUD picture: the user's own calibration picture if there is one, else the one shipped in the app.
    static func hudPicture(_ name: String, templates: URL) -> RGBImage? {
        ScreenCapture.loadPNG(templates.appendingPathComponent(name)) ?? ScreenCapture.loadPNG(builtInHud.appendingPathComponent(name))
    }

    static func findDefaultConfig() -> URL { resource("default_config.json", dev: "config/default_config.json") }

    static func openLog(_ url: URL) -> FileHandle? {
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        let h = try? FileHandle(forWritingTo: url)
        _ = try? h?.seekToEnd()
        return h
    }

    // MARK: Log
    func append(_ line: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let text = "\(stamp)  \(line)"
        log.append(text)
        if log.count > 400 { log.removeFirst(log.count - 400) }
        let mode = store.string("app.log_mode", "capped")
        guard mode != "off" else { return }
        logFile?.write(Data((text + "\n").utf8))
        logWrites += 1
        if mode == "capped", logWrites % 50 == 0 { trimLog(maxBytes: 2_000_000) }
    }

    /// Keeps the log file under `maxBytes`: when it grows past that, only the newest half is kept.
    func trimLog(maxBytes: UInt64) {
        let url = dirs.logs.appendingPathComponent("hivemac.log")
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? nil, size > maxBytes,
              let data = try? Data(contentsOf: url) else { return }
        var tail = data.suffix(Int(maxBytes / 2))
        if let nl = tail.firstIndex(of: 10) { tail = tail.suffix(from: tail.index(after: nl)) }     // start on a whole line
        try? logFile?.close()
        try? Data(tail).write(to: url, options: .atomic)
        logFile = AppModel.openLog(url)
    }

    /// Deletes the oldest snapshot folders beyond `keep`.
    func pruneSnapshots(keep: Int) {
        let dir = dirs.data.appendingPathComponent("snapshots")
        guard keep > 0, let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        let folders = names.filter { !$0.hasPrefix(".") }.sorted()                                   // names are timestamps
        for old in folders.dropLast(keep) { try? FileManager.default.removeItem(at: dir.appendingPathComponent(old)) }
    }

    // MARK: Start, pause, stop
    func start() {
        guard !running else { return }
        permissions = Permissions.current()
        if !permissions.allGranted {
            setStatus(.error, permissions.problems.first ?? "Permissions are missing")
            permissions.problems.forEach(append)
            return
        }
        guard robloxBounds != nil else {
            setStatus(.error, "Roblox was not found. Open it, then press Start.")
            return
        }
        // A run can be only activities (pickups, memory match, bug run, planters): a field is not required.
        guard pendingRouteTest != nil || !profile.fields.filter(\.enabled).isEmpty || (profile.mode == "none" && profile.extras.contains(where: \.enabled)) else {
            setStatus(.error, "Nothing is switched on. Turn on a field or an activity in Fields.")
            return
        }
        var settings = store.gameSettings()
        if store.bool("app.practice_mode", false) { settings.respawnTimeoutS = 0.3; settings.resetWaitS = 0.5; settings.convertTimeoutS = 5 }
        stopSignal.clear(); pauseSignal.clear()

        let hud = HudConfig(store: store) { [templates = dirs.templates] in Self.hudPicture($0, templates: templates) }
        let images = Self.builtInImages, templates = dirs.templates
        let screenSensors = ScreenSensors(screen: capture, window: { [store] in Self.bounds(store) }, config: hud) { name in
            ScreenCapture.loadPNG(templates.appendingPathComponent("\(name).png")) ?? ScreenCapture.loadPNG(images.appendingPathComponent("\(name).png"))
        }
        screenSensors.textReader = BarText.read; screenSensors.linesReader = BarText.readLines
        let sensors = ReportingSensors(screenSensors)
        sensors.practice = store.bool("app.practice_mode", false)
        sensors.onBackpack = { [weak self] p in let t = screenSensors.lastBarText; self?.beat(); DispatchQueue.main.async { self?.backpack = p; self?.barTextSeen = t } }

        let builtIn = builtInPaths, dirs = self.dirs
        let practice = store.bool("app.practice_mode", false)
        let actuator: Actuator = practice ? LoggingActuator { [weak self] line in DispatchQueue.main.async { self?.append(line) } } : input
        if practice { append("Practice mode: the macro reads the screen but presses nothing.") }
        let g = Game(actuator: actuator, sensors: sensors, settings: settings, clock: RealClock(),
                     stop: stopSignal, pause: pauseSignal,
                     status: { [weak self] s, d in self?.beat(); DispatchQueue.main.async { self?.setStatus(RunState(rawValue: s) ?? .warning, d) } },
                     windowSize: { [store] in Self.bounds(store).map { ($0.left, $0.top, $0.width, $0.height) } },
                     pathLookup: { kind, field, variant in
                         dirs.findPath(kind: kind, field: field, variant: variant, builtIn: builtIn).flatMap { try? PathFile.load($0) }
                     })
        game = g
        g.attachBuffReader(BuffSpeedReader(screen: capture, window: { [store] in Self.bounds(store) },
                                           model: BuffSpeedModel(movespeed: settings.walkSpeed, bearBonus: settings.bearBonus)))
        g.focusHook = { DispatchQueue.main.sync { WindowFinder.focusRoblox() } }
        g.frontCheck = { DispatchQueue.main.sync { WindowFinder.robloxIsFront() } }
        if store.bool("app.trace", false) { g.stepHook = RouteTrace.hook(root: dirs.data.appendingPathComponent("traces")) { [weak self] in self?.snapshotRoblox() } }
        let runner = GameExtraRunner(timers: mobTimers) { [weak self] t in
            DispatchQueue.main.async { self?.mobTimers = t; t.save(to: dirs.data.appendingPathComponent("mob_timers.json")) }
        }
        runner.mine = profile.fields.map(\.name)
        runner.onPlanter = { [weak self] id, slot, time in
            DispatchQueue.main.async {
                guard let self, let i = self.profile.extras.firstIndex(where: { $0.id == id }) else { return }
                self.profile.extras[i].planterPlanted[slot] = time
            }
        }
        let loop = FarmLoop(g, profile: profile, extras: runner)
        loop.onStats = { [weak self] s in DispatchQueue.main.async { self?.stats = s } }
        loop.onBlessingLearned = { [weak self] m in DispatchQueue.main.async { self?.profile.blessingMinutes = m; self?.append("Balloon blessing lasts about \(Int(m)) minutes, coming back 10 minutes before.") } }

        watchdog = Watchdog(timeout: store.double("timing.watchdog_timeout_sec", 90), now: Date().timeIntervalSince1970)
        running = true; paused = false; runtimeSeconds = 0; stats = LoopStats()
        setStatus(.resetting, "Starting")
        runtimeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.running else { return }
                if !self.paused { self.runtimeSeconds += 1 }
                if self.stalled() { self.append("Watchdog: nothing happened for a while, stopping."); self.setStatus(.error, "Stopped: the macro stopped responding"); self.stop() }
            }
        }
        WindowFinder.focusRoblox()
        let routeTest = pendingRouteTest
        pendingRouteTest = nil
        Thread.detachNewThread { [weak self] in
            let why: String
            if let t = routeTest, t.name.hasPrefix("field:") {
                // Reset, then the field's own route (walk or cannon), then a picture so the arrival can be checked by eye.
                let field = String(t.name.dropFirst(6))
                var f = FieldConfig(name: field)
                f.travel = t.variant
                g.testPrefix = t.prefix
                let ok = g.resetToHive() && g.travelTo(f)
                let shot = self?.snapshotRoblox()
                if let shot, let dir = self?.dirs.data { _ = ScreenCapture.savePNG(shot, to: dir.appendingPathComponent("debug-step.png")) }
                g.status(ok ? "traveling" : "warning", "FIELD TEST \(field) \(t.variant): \(ok ? "route finished, picture saved" : "route failed")")
                g.status("traveling", "ROUTE TEST SUMMARY \(field) \(t.variant): done")
                why = "stopped"
            } else if let t = routeTest, t.name == "reset" {
                // Reset, camera and nothing else: leaves the character at the hive, facing away, ready for a recording.
                let ok = g.resetToHive()
                g.status(ok ? "traveling" : "warning", "RESET ONLY: \(ok ? "ready at the hive" : "failed")")
                why = "stopped"
            } else if let t = routeTest {
                // One route at a time: reset, camera, the walk, the prompt check. A pass is the right prompt at the end.
                var passes = 0
                g.testVariant = t.variant
                g.testPrefix = t.prefix
                for i in 1...t.times where !g.stopped {
                    g.status("traveling", "ROUTE TEST \(i) of \(t.times): \(t.name) (\(t.variant))")
                    let r = g.collect(t.name)
                    var ok = false, detail = ""
                    switch r {
                    case .collected: ok = true; detail = "collected"
                    case .onCooldown(let left): ok = true; detail = "arrived, prompt shows a countdown of \(Int(left)) s"
                    case .failed(let why): detail = why
                    }
                    if ok { passes += 1 }
                    g.status(ok ? "traveling" : "warning", "ROUTE TEST RESULT \(i) of \(t.times) \(t.name) \(t.variant): \(ok ? "PASS" : "FAIL") (\(detail))")
                }
                g.status("traveling", "ROUTE TEST SUMMARY \(t.name) \(t.variant): \(passes) of \(t.times) passed")
                why = "stopped"
            } else {
                why = loop.run()
            }
            g.releaseEverything()
            DispatchQueue.main.async { self?.finished(why: why) }
        }
    }

    func finished(why: String) {
        running = false; paused = false
        runtimeTimer?.invalidate(); runtimeTimer = nil
        game = nil
        let text: String
        switch why {
        case "stopped": text = "Stopped"
        case "no_fields": text = "No field is switched on"
        case "reset_failed": text = "Could not reach the hive after several resets"
        default: text = why
        }
        setStatus(why == "reset_failed" ? .error : .idle, text)
    }

    /// Runs one pickup route `times` times in a row, from the hive, and logs PASS or FAIL for each.
    func startRouteTest(_ name: String, _ times: Int, _ variant: String = "walk", _ prefix: Int? = nil) {
        guard !running, name == "reset" || name.hasPrefix("field:") || Game.pickupWords[name] != nil else { append("Route test: unknown pickup \"\(name)\" or a run is going."); return }
        pendingRouteTest = (name, times, variant, prefix)
        start()
    }

    func pause() {
        guard running, !paused else { return }
        pauseSignal.set(); paused = true
        setStatus(.paused, "Paused")
    }

    func resume() {
        guard running, paused else { return }
        pauseSignal.clear(); paused = false
        setStatus(.resetting, "Resuming")
    }

    func stop(_ source: String = "") {
        stopSignal.set(); pauseSignal.clear()
        input.releaseAll()
        if running { append(source.isEmpty ? "Stop requested" : "Stop requested (\(source))") }
    }

    func setStatus(_ s: RunState, _ d: String) {
        if running && paused && s != .paused { return }       // a late status must not hide the pause
        state = s; detail = d
        if s == .gathering || s == .traveling { currentField = d.split(separator: " ").first.map(String.init) ?? currentField }
        if !d.isEmpty { append("\(s.label): \(d)") }
        // A warning or an error is exactly when a picture of the screen helps: keep one, at most once a minute.
        let snaps = store.string("app.snapshots", store.bool("app.auto_snapshots", true) ? "keep20" : "off")
        if (s == .warning || s == .error), running, snaps != "off",
           Date().timeIntervalSince(lastAutoSnapshot) > 60 {
            lastAutoSnapshot = Date()
            saveSnapshot(quiet: true)
            if snaps == "keep20" { pruneSnapshots(keep: 20) }
        }
    }

}
