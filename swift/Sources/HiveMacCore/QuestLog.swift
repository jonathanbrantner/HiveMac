import Foundation

/// One quest box as read from the quest log by OCR, e.g.
/// "Black Bear: Delve Into Dandelions / Collect 200,000,000 Pollen from the Dandelion Field. Complete! Talk to Black Bear."
public struct QuestLogEntry: Equatable, Sendable {
    public var giver: String        // "Black Bear"
    public var name: String         // "Delve Into Dandelions"
    public var pollen: Int?         // 200000000
    public var complete: Bool       // the box says "Complete!"
    public var body: String
    public var progress: [QuestProgress] = []   // every "9,035,765/330,000,000" or "6/10" in the box
}

public struct QuestProgress: Equatable, Sendable { public var done: Int; public var goal: Int }

public enum QuestLog {
    /// Parses OCR text of one quest box. Returns nil when there is no "Giver: Quest name" title.
    public static func parse(_ text: String) -> QuestLogEntry? {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard let titleIdx = lines.firstIndex(where: { $0.contains(":") && !$0.lowercased().hasPrefix("collect") }) else { return nil }
        let title = lines[titleIdx]
        let parts = title.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        let body = lines[(titleIdx + 1)...].joined(separator: " ")
        return QuestLogEntry(giver: parts[0], name: parts[1], pollen: pollenAmount(in: body),
                             complete: body.lowercased().contains("complete!"), body: body, progress: progress(in: body))
    }

    /// Every "done/goal" pair, OCR separators ignored.
    static func progress(in s: String) -> [QuestProgress] {
        let re = try! NSRegularExpression(pattern: #"(\d[\d,.]*)\s*/\s*(\d[\d,.]*)"#)
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            guard let a = Int(ns.substring(with: m.range(at: 1)).filter(\.isNumber)),
                  let b = Int(ns.substring(with: m.range(at: 2)).filter(\.isNumber)), b > 0 else { return nil }
            return QuestProgress(done: a, goal: b)
        }
    }

    /// The Black Bear style speech box ("Click to continue") and who is talking.
    public static func isDialog(_ text: String) -> Bool { text.lowercased().contains("click to continue") }

    /// The turn-in is over: "I can give you a quest once an hour, so check with me again later!"
    public static func isCooldownDialog(_ text: String) -> Bool {
        let t = text.lowercased()
        return t.contains("once an hour") || t.contains("check with me again")
    }

    /// "Collect 200,000,000 Pollen" -> 200000000. OCR may read commas as dots or spaces.
    static func pollenAmount(in s: String) -> Int? {
        guard let r = s.range(of: #"\d[\d,.\s]*\d(?=\s*pollen)"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let digits = s[r].filter(\.isNumber)
        return Int(digits)
    }

    /// Giver key used in `QuestBook` for the title's giver name.
    public static func giverKey(_ giver: String) -> String? {
        switch giver.lowercased().filter(\.isLetter) {
        case "blackbear": return "black"
        case "polarbear": return "polar"
        case "buckobee": return "bucko"
        case "rileybee": return "riley"
        default: return nil
        }
    }
}
