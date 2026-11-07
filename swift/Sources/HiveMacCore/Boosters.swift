import Foundation

/// Field boosters. Using one boosts one of its fields for a while; the boost shows as an icon in the buff bar.
public enum Booster: String, CaseIterable, Sendable {
    case blue, red, mountain, coconut

    /// The pickup name used by the timers and the routes.
    public var pickup: String { self == .coconut ? "coconut dispenser" : "\(rawValue) booster" }

    public var title: String {
        switch self { case .blue: "Blue HQ"; case .red: "Red HQ"; case .mountain: "Mountain Top"; case .coconut: "Coconut" }
    }

    /// The fields this booster can boost (Natro's lists).
    public var fields: [String] {
        switch self {
        case .blue: ["pine tree", "bamboo", "blue flower", "stump"]
        case .red: ["rose", "strawberry", "mushroom", "pepper"]
        case .mountain: ["cactus", "pumpkin", "pineapple", "spider", "clover", "dandelion", "sunflower"]
        case .coconut: ["coconut"]
        }
    }

    /// Where to go when the boosted field cannot be read from the buff bar.
    public var fallbackField: String { fields[0] }

    /// Natro's order of rotation (Red, Blue, Mountain); the coconut dispenser comes first whenever it is ready.
    static let rotation: [Booster] = [.red, .blue, .mountain]

    /// The next ready booster, going round after the one used last. nil when none is ready.
    public static func next(after last: Booster?, enabled: [Booster], ready: (Booster) -> Bool) -> Booster? {
        if enabled.contains(.coconut), ready(.coconut) { return .coconut }
        let order = rotation.filter(enabled.contains)
        guard !order.isEmpty else { return nil }
        let start = last.flatMap { order.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        for i in 0..<order.count {
            let b = order[(start + i) % order.count]
            if ready(b) { return b }
        }
        return nil
    }

    /// Icon in the buff bar for a field, for the boost made by a booster (Natro variant 1).
    public static func iconName(for field: String) -> String { "boost/\(field.replacingOccurrences(of: " ", with: ""))1" }
}

extension Game {
    /// Where the buff bar icons are: a wide strip under the Roblox top bar.
    var buffStrip: RelRegion { RelRegion(fx: 0, fy: Double(settings.uiOffsetY) / 900, fw: 1, fh: 120 / 900) }

    /// The field of `booster` whose boost icon is in the buff bar now. nil when none is.
    public func boostedField(by booster: Booster) -> String? {
        for field in booster.fields where sensors.find(Booster.iconName(for: field), in: buffStrip, tolerance: 35) != nil {
            return field
        }
        return nil
    }

    /// True while the boost icon of `field` is still in the buff bar.
    public func boostActive(field: String) -> Bool {
        sensors.find(Booster.iconName(for: field), in: buffStrip, tolerance: 35) != nil
    }
}
