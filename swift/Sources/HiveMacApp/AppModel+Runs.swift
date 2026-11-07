import SwiftUI
import AppKit
import HiveMacCore
import HiveMacPlatform

extension AppModel {
    // MARK: Profile and settings
    func saveProfile() {
        try? profile.save(to: dirs.profiles.appendingPathComponent(activeRunFile))
        refreshRuns()
    }

    // MARK: Run library (each run is one profile file)
    struct RunEntry: Identifiable, Equatable { let file: String; let name: String; var id: String { file } }

    func refreshRuns() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dirs.profiles.path)) ?? []
        runs = files.filter { $0.hasSuffix(".json") }.sorted().compactMap { f in
            (try? Profile.load(dirs.profiles.appendingPathComponent(f))).map { RunEntry(file: f, name: $0.name) }
        }
    }

    func switchRun(_ file: String) {
        guard !running, file != activeRunFile,
              let p = try? Profile.load(dirs.profiles.appendingPathComponent(file)) else { return }
        activeRunFile = file; profile = p
        set("app.active_run_file", file)
    }

    func newRunFile(_ name: String) -> String {
        let slug = String(name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "_" })
        var f = "\(slug).json", n = 2
        while FileManager.default.fileExists(atPath: dirs.profiles.appendingPathComponent(f).path) { f = "\(slug)_\(n).json"; n += 1 }
        return f
    }

    /// Creates a run from `base` (a copy of the current one, or nothing for a fresh one) and opens it.
    func addRun(named name: String, copying base: Profile?) {
        guard !running else { return }
        var p = base ?? Profile(fields: [FieldConfig(name: "sunflower")])
        p.name = name
        let f = newRunFile(name)
        try? p.save(to: dirs.profiles.appendingPathComponent(f))
        refreshRuns(); switchRun(f)
    }

    func renameRun(_ name: String) {
        let t = name.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        profile.name = t
    }

    var canDeleteRun: Bool { runs.count > 1 && !running }

    /// Deletes a run (the open one when `file` is nil). The next run in the list opens if it was the open one.
    func deleteRun(_ file: String? = nil) {
        guard canDeleteRun else { return }
        let gone = file ?? activeRunFile
        try? FileManager.default.removeItem(at: dirs.profiles.appendingPathComponent(gone))
        refreshRuns()
        if gone == activeRunFile, let next = runs.first?.file { activeRunFile = ""; switchRun(next) }
    }

    // MARK: Field defaults (Settings tab): used for new fields, and by "Apply to all fields"
    static let defaultKeys = ["fields.minutes", "fields.size", "fields.width", "fields.return"]

    /// Gives a new field the defaults the user has set in Settings (only the ones they set).
    func applyFieldDefaults(to f: inout FieldConfig) {
        if store.get("fields.minutes") != nil { f.minutes = store.double("fields.minutes", f.minutes) }
        if let size = store.get("fields.size") as? String, size != f.size {
            let ratio = Patterns.sizeFactor(size) / Patterns.sizeFactor(f.size)
            f.sprinklerDistance = max(1, Int((Double(f.sprinklerDistance) * ratio).rounded())); f.size = size
        }
        if store.get("fields.width") != nil { f.width = store.int("fields.width", f.width) }
        if let r = store.get("fields.return") as? String { f.returnMethod = r }
        f.backpackPercent = hive.backpackPercent
    }

    func applyFieldDefaultsToAll() {
        guard !running else { return }
        // What Settings shows counts as set, even if it was never touched.
        for (k, v) in [("fields.minutes", 10.0 as Any), ("fields.size", "m"), ("fields.width", 4), ("fields.return", "walk")] where store.get(k) == nil { store.set(k, v) }
        for i in profile.fields.indices { applyFieldDefaults(to: &profile.fields[i]) }
    }

    func saveSettings() {
        hive.write(to: store)
        try? store.save()
        settingsVersion += 1
    }

    func set(_ path: String, _ value: Any) { store.set(path, value); try? store.save(); settingsVersion += 1 }
}
