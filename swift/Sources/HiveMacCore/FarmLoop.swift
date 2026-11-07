import Foundation

public struct LoopStats: Equatable, Sendable {
    public var cycles = 0
    public var converts = 0
    public var deaths = 0
    public var resets = 0
    public var failedResets = 0
    public var lastResult = ""
    public var history: [GatherResult] = []
    public init() {}
}

/// The farming loop: reset to the hive, convert, travel, gather, walk back (or reset), repeat,
/// rotating through the enabled fields. A death or a lost screen falls back to the reset.
public final class FarmLoop {
    public let game: Game
    public let fields: [FieldConfig]
    /// Fields and extras in run order. Extras need a runner; without one they are skipped.
    public enum Item { case field(FieldConfig), extra(ExtraStep) }
    let items: [Item]
    let extras: ExtraRunner?
    let unixNow: () -> TimeInterval
    let boosterMode: Bool
    let boosters: [Booster]
    let profileFields: [FieldConfig]
    /// The boosted field being gathered, while its boost lasts.
    private var boost: (field: FieldConfig, since: TimeInterval)?
    private var lastBooster: Booster?
    public private(set) var stats = LoopStats()
    public var onStats: (LoopStats) -> Void = { _ in }
    private let maxCycles: Int?
    private let maxFailed: Int
    private var index = 0

    public init(_ game: Game, fields: [FieldConfig], maxCycles: Int? = nil, maxFailedResets: Int = 2) {
        self.game = game
        self.fields = fields.filter(\.enabled)
        self.items = self.fields.map { Item.field($0) }
        self.extras = nil
        self.unixNow = { Date().timeIntervalSince1970 }
        self.boosterMode = false
        self.boosters = []
        self.profileFields = fields
        self.maxCycles = maxCycles
        self.maxFailed = maxFailedResets
    }

    /// A whole run: fields and extras in the order of the profile.
    public init(_ game: Game, profile: Profile, extras: ExtraRunner, maxCycles: Int? = nil, maxFailedResets: Int = 2,
                unixNow: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 }) {
        self.game = game
        self.fields = profile.fields.filter(\.enabled)
        self.items = profile.orderKeys.compactMap { key in
            if key.hasPrefix("f:"), let f = profile.fields.first(where: { "f:" + $0.name == key }), f.enabled { return .field(f) }
            if key.hasPrefix("e:"), let e = profile.extras.first(where: { "e:" + $0.id.uuidString == key }), e.enabled { return .extra(e) }
            return nil
        }
        self.extras = extras
        self.unixNow = unixNow
        self.boosterMode = profile.boosterMode
        self.boosters = profile.boosters.compactMap(Booster.init(rawValue:))
        self.profileFields = profile.fields
        self.maxCycles = maxCycles
        self.maxFailed = maxFailedResets
    }

    /// Booster mode: keep gathering the boosted field while its boost lasts; when it is over, use the next
    /// ready booster and go to the field it boosted. Returns nil to use the normal field list.
    private func boostedItem() -> FieldConfig? {
        guard boosterMode, let runner = extras else { return nil }
        let g = game
        if let b = boost {
            // The icon tells when the boost ends. If it could never be read, assume the usual 15 minutes.
            if g.boostActive(field: b.field.name) || (usedFallback && unixNow() - b.since < 15 * 60) { return b.field }
            g.status("converting", "the boost on \(b.field.name) is over")
            boost = nil
        }
        guard let next = Booster.next(after: lastBooster, enabled: boosters, ready: runner.boosterReady) else { return nil }
        switch g.collect(next.pickup) {
        case .failed(let why):
            g.status("warning", "\(next.title) booster: \(why)")
            runner.boosterUsed(next)                         // do not try it again for a full cooldown
            return nil
        case .collected, .onCooldown:
            runner.boosterUsed(next)
        }
        lastBooster = next
        var name: String?
        for _ in 0..<10 where name == nil {
            name = g.boostedField(by: next)
            if name == nil { g.walker.wait(1) }
        }
        usedFallback = name == nil
        let fieldName = name ?? profileFields.first(where: { next.fields.contains($0.name) && $0.enabled })?.name ?? next.fallbackField
        var field = profileFields.first(where: { $0.name == fieldName }) ?? FieldConfig(name: fieldName)
        if !profileFields.contains(where: { $0.name == fieldName }) { field.minutes = 15; field.backpackPercent = 90 }
        field.enabled = true
        g.status("traveling", "boosted field: \(fieldName)" + (name == nil ? " (could not read the buff bar)" : ""))
        boost = (field, unixNow())
        return field
    }
    private var usedFallback = false

    private func nextItem() -> Item {
        let item = items[index % items.count]
        index += 1
        return item
    }

    /// Visits an extra only when something in it is due.
    private func visit(_ step: ExtraStep) {
        guard let runner = extras else { return }
        let due = runner.due(step, now: unixNow())
        if !due.isEmpty { runner.perform(step, due: due, game: game) }
    }

    /// Returns why the loop ended: stopped, no_fields, reset_failed, cycles_done.
    public func run() -> String {
        let g = game
        if fields.isEmpty { g.status("error", "no enabled fields"); return "no_fields" }
        var afterDeath = false
        // Standing at the hive with pollen: convert it first. A reset would only throw time away.
        if g.sensors.hivePromptVisible() == true {
            g.status("converting", "at the hive, converting before the first field")
            if g.convert() { stats.converts += 1 }
        }
        while !g.stopped {
            if let m = maxCycles, stats.cycles >= m { return "cycles_done" }
            let f: FieldConfig
            let upcoming: Item = boostedItem().map { Item.field($0) } ?? nextItem()
            switch upcoming {
            case .extra(let step): visit(step); continue
            case .field(let field): f = field
            }
            stats.resets += 1
            if !g.resetToHive(afterDeath: afterDeath) {
                if g.stopped { break }
                stats.failedResets += 1
                onStats(stats)
                if stats.failedResets >= maxFailed {
                    g.status("error", "giving up after repeated reset failures")
                    g.releaseEverything()
                    return "reset_failed"
                }
                continue
            }
            stats.failedResets = 0
            afterDeath = false
            if g.convert() { stats.converts += 1 }
            if g.stopped { break }
            if !g.travelTo(f) { continue }
            let result = g.gather(f)
            stats.cycles += 1
            extras?.fieldGathered(f.name, seconds: result.seconds)
            stats.lastResult = result.reason
            stats.history.append(result)
            if result.reason == "death" { stats.deaths += 1; afterDeath = true }
            onStats(stats)
            if (result.reason == "backpack" || result.reason == "time") && f.returnMethod == "walk" {
                if g.walkBack(f), g.convert() { stats.converts += 1 }
                // the loop still resets before the next field: that keeps the camera and position known
            }
        }
        g.releaseEverything()
        return "stopped"
    }
}
