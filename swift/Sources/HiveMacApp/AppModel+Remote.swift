import SwiftUI
import AppKit
import HiveMacCore
import HiveMacPlatform

extension AppModel {
    // MARK: Phone remote
    func setRemote(_ on: Bool) {
        remote?.stop(); remote = nil; remoteURL = ""; remoteMessage = nil
        guard on else { remoteOn = false; set("remote.enabled", false); return }
        var token = store.string("remote.token", "")
        if token.isEmpty { token = String((0..<10).map { _ in "abcdefghjkmnpqrstuvwxyz23456789".randomElement()! }); store.set("remote.token", token); try? store.save() }
        let server = RemoteServer(token: token)
        server.status = { [weak self] in
            guard let self else { return [:] }
            return ["state": self.state.label, "detail": self.detail, "field": self.currentField, "backpack": self.backpack as Any? ?? NSNull(), "barText": self.barTextSeen ?? "",
                    "cycles": self.stats.cycles, "converts": self.stats.converts, "deaths": self.stats.deaths, "paused": self.paused, "running": self.running]
        }
        server.logLines = { [weak self] n in Array((self?.log ?? []).suffix(n)) }
        server.action = { [weak self] a in
            switch a { case "start": self?.start(); case "pause": self?.pause(); case "resume": self?.resume(); default: self?.stop("remote API") }
        }
        server.buffProbe = { [weak self] top, save in
            guard let self else { return [:] }
            let reader = BuffSpeedReader(screen: self.capture, window: { [store = self.store] in Self.bounds(store) },
                                         model: BuffSpeedModel(movespeed: self.store.double("game.walk_speed", 28), bearBonus: self.store.double("game.bear_morph_bonus", 4)))
            reader.stripTop = top
            if top == -1 { return ["selftest": BuffDetector.selfTest()] }
            guard let strip = reader.strip() else { return ["error": "could not read the screen or the window"] }
            let state = BuffDetector.detect(strip)
            if save { _ = ScreenCapture.savePNG(strip, to: self.dirs.data.appendingPathComponent("buff-strip.png")) }
            let t0 = Date(); for _ in 0..<20 { _ = BuffDetector.detect(strip) }
            return ["buffs": state.text, "speed": reader.model.speed(state), "base": reader.model.baseSpeed, "stripWidth": strip.width, "stripHeight": strip.height,
                    "hasteAt": BuffDetector.debugHaste(strip) as Any, "detectMs": Date().timeIntervalSince(t0) * 50, "grabMs": reader.lastReadSeconds * 1000]
        }
        server.runSteps = { [weak self] json in self?.debugRunSteps(json) ?? "no app" }
        server.testRoute = { [weak self] name, n, variant, prefix in self?.startRouteTest(name, n, variant, prefix) }
        guard server.start() else { remoteOn = false; remoteMessage = "Port 8765 is busy. Close the other HiveMac and try again."; return }
        remote = server; remoteOn = true; set("remote.enabled", true)
        let ip = RemoteServer.localAddresses().first ?? "localhost"
        remoteURL = "http://\(ip):8765/?t=\(token)"
    }

    // MARK: Stop key
    func setStopKey(_ name: String) {
        switch KeyCodes.validateStopKey(name) {
        case .failure(let e): stopKeyMessage = e.message
        case .success(let code):
            // Probe that macOS accepts the key, then arm it only if a run is going.
            if hotKey.register(keyCode: UInt32(code)) {
                stopKeyName = name.lowercased(); stopKeyMessage = nil
                store.set("app.emergency_stop_key", stopKeyName); try? store.save()
                syncHotKey()
            } else { stopKeyMessage = "macOS would not register that key. Try another."; syncHotKey() }
        }
    }

    /// The stop key is a system-wide hot key, so macOS swallows it everywhere while it is armed.
    /// Arm it only during a run (and never while the user is picking a new key); otherwise the
    /// key could not be typed in any text field.
    func syncHotKey() {
        if running && !capturingStopKey, case .success(let code) = KeyCodes.validateStopKey(stopKeyName) {
            if hotKey.keyCode != UInt32(code) { hotKey.register(keyCode: UInt32(code)) }
        } else { hotKey.unregister() }
    }

    /// Debug: run a JSON list of route steps (walk, hold, rotate, wait, tap, zoom) with the real walker, then save a
    /// picture of the Roblox window to ~/Library/Application Support/HiveMac/debug-step.png. Not while a run is going.
    func debugRunSteps(_ json: String) -> String {
        guard !running else { return "a run is going" }
        guard let data = json.data(using: .utf8), let steps = try? JSONDecoder().decode([Step].self, from: data) else { return "bad json" }
        let speed = store.double("game.walk_speed", 28)
        let walker = Walker(actuator: input, speed: SpeedModel(baseSpeed: speed), stop: stopSignal)
        stopSignal.clear()
        WindowFinder.focusRoblox()
        Thread.sleep(forTimeInterval: 0.5)
        _ = try? walker.run(steps, keymap: ["rot_left": ",", "rot_right": ".", "zoom_in": "i", "zoom_out": "o"])
        input.releaseAll()
        Thread.sleep(forTimeInterval: 0.4)
        if let shot = snapshotRoblox() { _ = ScreenCapture.savePNG(shot, to: dirs.data.appendingPathComponent("debug-step.png")) }
        return "ok"
    }
}
