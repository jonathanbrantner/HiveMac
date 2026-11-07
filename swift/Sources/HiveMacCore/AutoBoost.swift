import Foundation

/// Auto field boost, from Natro Macro (GPL-3.0): on arriving at a field that is not boosted, roll Field Dice and/or
/// use Glitter from the hotbar until the field's boost icon shows in the buff bar.
public struct AutoBoost: Equatable, Sendable {
    public var enabled = false
    /// Hotbar slot (2 to 7) holding the Field Dice; 0 = not used.
    public var diceSlot = 0
    /// Hotbar slot (2 to 7) holding the Glitter; 0 = not used.
    public var glitterSlot = 0
    /// At most this many dice rolls each time a field is boosted.
    public var rollsPerVisit = 5
    /// Boost again no sooner than this many minutes after the last time at the same field.
    public var refreshMinutes = 10.0

    public init() {}

    public var json: [String: Any] {
        ["enabled": enabled, "dice_slot": diceSlot, "glitter_slot": glitterSlot,
         "rolls_per_visit": rollsPerVisit, "refresh_minutes": refreshMinutes]
    }

    public init(json: [String: Any]) {
        enabled = (json["enabled"] as? NSNumber)?.boolValue ?? false
        diceSlot = Self.slot((json["dice_slot"] as? NSNumber)?.intValue)
        glitterSlot = Self.slot((json["glitter_slot"] as? NSNumber)?.intValue)
        rollsPerVisit = max(1, min(20, (json["rolls_per_visit"] as? NSNumber)?.intValue ?? 5))
        refreshMinutes = max(1, (json["refresh_minutes"] as? NSNumber)?.doubleValue ?? 10)
    }

    private static func slot(_ n: Int?) -> Int { (n.map { (2...7).contains($0) ? $0 : 0 }) ?? 0 }
}

extension Game {
    /// True while any boost icon of `field` shows in the buff bar (a booster, dice, glitter or the wind).
    public func fieldBoosted(_ field: String) -> Bool {
        let base = "boost/" + field.replacingOccurrences(of: " ", with: "")
        return ["0", "1", "3"].contains { sensors.find(base + $0, in: buffStrip, tolerance: 35) != nil }
    }

    /// Rolls dice, then glitter, until the field is boosted. Returns true when it is. The slot is the hotbar
    /// number, which is also the key, so slot 2 is the "2" key. Needs the buff bar to be readable.
    @discardableResult
    public func boostField(_ field: String, _ cfg: AutoBoost) -> Bool {
        guard cfg.enabled, cfg.diceSlot > 0 || cfg.glitterSlot > 0 else { return false }
        if fieldBoosted(field) { return true }
        status("gathering", "boosting \(field)")
        if cfg.diceSlot > 0 {
            for _ in 0..<cfg.rollsPerVisit where !stopped {
                actuator.tap(String(cfg.diceSlot), holdS: 0.05)
                wait(1.6)
                if fieldBoosted(field) { status("gathering", "\(field) boosted by dice"); return true }
            }
        }
        if cfg.glitterSlot > 0, !stopped {
            actuator.tap(String(cfg.glitterSlot), holdS: 0.05)
            wait(2.0)
            if fieldBoosted(field) { status("gathering", "\(field) boosted by glitter"); return true }
        }
        status("warning", "could not boost \(field)")
        return false
    }
}
