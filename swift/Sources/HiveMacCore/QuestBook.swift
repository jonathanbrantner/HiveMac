import Foundation

/// What a quest asks for, from Natro Macro's quest tables (GPL-3.0, `config/quests.json`).
public struct QuestObjective: Equatable, Sendable {
    public var slot: Int            // position in the quest log, 1 = first
    public var kind: String         // Collect, Kill, Get, Feed
    public var target: String       // a field, a pollen colour, a mob group, "Ant", ...
}

/// What HiveMac does for one objective.
public enum QuestAction: Equatable, Sendable {
    case gather(field: String)
    case gatherColor(String)        // white, red, blue, any: any field that gives that pollen
    case kill([String])             // mobs, as the bug run names them
    case unsupported(String)        // ant challenge, feeding, boosts
}

public struct QuestBook: Sendable {
    public typealias Quests = [String: [QuestObjective]]
    /// giver ("polar", "black", "bucko", "riley") -> quest name -> objectives
    public var givers: [String: Quests]

    public init(givers: [String: Quests]) { self.givers = givers }

    public static func load(_ url: URL) -> QuestBook {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String: [[Any]]]] else { return QuestBook(givers: [:]) }
        let names = ["PolarBear": "polar", "BlackBear": "black", "BuckoBee": "bucko", "RileyBee": "riley"]
        var out: [String: Quests] = [:]
        for (key, quests) in obj {
            guard let giver = names[key] else { continue }
            out[giver] = quests.mapValues { rows in
                rows.compactMap { r in
                    guard r.count == 3, let s = r[0] as? Int, let k = r[1] as? String, let t = r[2] as? String else { return nil }
                    return QuestObjective(slot: s, kind: k, target: t)
                }.sorted { $0.slot < $1.slot }
            }
        }
        return QuestBook(givers: out)
    }

    /// The quest of `giver` whose name shows in the OCR text of the quest log. The longest matching name wins
    /// ("Bamboo" must not beat "Bamboo Bash"), and case and spaces do not matter.
    public func quest(in text: String, giver: String) -> (name: String, objectives: [QuestObjective])? {
        func squash(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        let hay = squash(text)
        let hits = (givers[giver] ?? [:]).filter { hay.contains(squash($0.key)) }
        guard let best = hits.max(by: { $0.key.count < $1.key.count }) else { return nil }
        return (best.key, best.value)
    }

    static let mobNames: [String: String] = ["Ladybugs": "ladybug", "RhinoBeetles": "rhino beetle", "Mantis": "mantis",
                                             "Scorpions": "scorpion", "Spider": "spider", "Werewolf": "werewolf"]

    public static func action(for o: QuestObjective) -> QuestAction {
        switch o.kind {
        case "Kill":
            if o.target == "All" { return .kill(Array(mobNames.values).sorted()) }
            if let m = mobNames[o.target] { return .kill([m]) }
            return .unsupported("kill \(o.target)")
        case "Collect":
            switch o.target {
            case "White", "Red", "Blue", "Any": return .gatherColor(o.target.lowercased())
            default: return .gather(field: o.target.lowercased())
            }
        default: return .unsupported("\(o.kind.lowercased()) \(o.target)")
        }
    }

    /// A field that gives pollen of `color`, preferring one the user already farms.
    public static func field(forColor color: String, preferring mine: [String]) -> String? {
        let all = FieldDefaults.order
        let fits: (String) -> Bool = { color == "any" || FieldColors.table[$0] == color }
        return mine.first(where: fits) ?? all.first(where: fits)
    }
}
