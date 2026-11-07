import Foundation

public enum QuestResult: Equatable { case turnedIn, notReady(TimeInterval), skipped(String), failed(String), interrupted }

public enum QuestGivers {
    public static let all = ["black bear", "polar bear", "brown bear", "bucko bee", "riley bee"]
    /// Route file name under to_quest.
    public static func route(_ giver: String) -> String { giver.split(separator: " ")[0].description }
    /// The game gives a new quest about once an hour; its own dialog corrects this when it says otherwise.
    public static let cooldown: TimeInterval = 3600
}

extension Game {
    /// Where the quest log lives: the left side of the window, under the icons.
    static let logRegion = RelRegion(fx: 0, fy: 0.17, fw: 0.2, fh: 0.75)
    /// The speech box at the bottom middle.
    static let dialogRegion = RelRegion(fx: 0.34, fy: 0.62, fw: 0.34, fh: 0.34)

    /// The giver's box in the quest log. The log scrolls, so when the box is not on screen it scrolls down a
    /// little at a time until the text stops changing, then goes back to the top. A box cut off at the bottom
    /// is read again after one more scroll, so no objective is missed.
    func readQuestBox(_ giver: String) -> String? {
        guard var text = sensors.textIn(Game.logRegion) else { return nil }
        if !QuestLog.looksOpen(text) {
            guard openQuestLog(), let t = sensors.textIn(Game.logRegion) else { return nil }
            text = t
        }
        if let box = QuestLog.box(for: giver, in: text), !QuestLog.isCutOff(box, in: text) { return box }
        guard let spot = sensors.point(fx: 0.1, fy: 0.55) else { return QuestLog.box(for: giver, in: text) }
        actuator.moveMouse(spot.x, spot.y)
        var scrolled = 0
        var found: String? = QuestLog.box(for: giver, in: text)
        for _ in 0..<12 where !stopped {
            actuator.scroll(-4); scrolled += 1
            wait(0.4)
            guard let next = sensors.textIn(Game.logRegion) else { break }
            if QuestLog.squash(next) == QuestLog.squash(text) { break }       // the end of the list
            text = next
            if let box = QuestLog.box(for: giver, in: text) {
                found = box
                if !QuestLog.isCutOff(box, in: text) { break }
            }
        }
        actuator.scroll(scrolled * 4 + 8)                                      // back to the top
        wait(0.3)
        parkMouse()
        return found
    }

    /// Presses E at the quest giver and clicks through the speech until it ends. Returns the last words said.
    func talk() -> (said: String, cooldown: Bool) {
        var said = ""
        actuator.tap("e", holdS: 0.1)
        wait(1.0)
        var missing = 0
        for _ in 0..<14 where !stopped {
            guard let t = sensors.textIn(Game.dialogRegion) else { break }
            if QuestLog.isDialog(t) {
                missing = 0; said = t
                if QuestLog.isCooldownDialog(t) { clickDialog(); wait(0.6); return (said, true) }
                clickDialog(); wait(0.8)
            } else {
                missing += 1
                if missing >= 2 { break }
                wait(0.6)
            }
        }
        return (said, QuestLog.isCooldownDialog(said))
    }

    private func clickDialog() {
        if let p = sensors.point(fx: 0.5, fy: 0.82) { actuator.click(p.x, p.y) }
    }
}

extension Game {
    /// Does one quest of `giver`: takes it if the log has none, does what it asks, and turns it in.
    /// Every action waits for the text that proves it: no quest box means nothing to work on, no "Complete!"
    /// means no turn-in. Objectives HiveMac cannot do (ants, feeding, tokens) leave the quest alone.
    public func quest(_ giver: String, mine: [String]) -> QuestResult {
        let key = QuestGivers.route(giver)
        let variant = settings.travel
        guard let route = pathLookup("to_quest", key, variant) ?? pathLookup("to_quest", key, "walk") else {
            return .failed("no route to \(giver)")
        }
        if sensors.textIn(Game.logRegion) == nil { return .failed("cannot read the quest log") }

        func visitGiver() -> (said: String, cooldown: Bool)? {
            guard resetToHive() else { return nil }
            status("traveling", giver)
            guard walkPath(route) else { return nil }
            return talk()
        }

        var box = readQuestBox(giver)
        if box == nil {
            guard let first = visitGiver() else { return stopped ? .interrupted : .failed("could not reach \(giver)") }
            if first.cooldown { return .notReady(QuestGivers.cooldown) }
            box = readQuestBox(giver)
            if box == nil { return .failed("no \(giver) quest in the log after talking to \(giver)") }
        }

        for round in 0..<6 where !stopped {
            guard let b = box else { return .failed("lost the \(giver) quest in the log") }
            let all = QuestLog.tasks(in: b)
            let todo = all.filter { !$0.complete }
            if todo.isEmpty { break }
            if let bad = todo.first(where: { if case .unsupported = $0.action { return true } else { return false } }) {
                return .skipped("\(giver): can't do \"\(bad.text)\" yet")
            }
            guard let task = todo.first, let idx = all.firstIndex(of: task) else { break }
            status("gathering", "\(giver): \(task.text)")
            switch task.action {
            case .gather(let field): if let r = work(field: field, giver: giver, index: idx) { return r }
            case .gatherColor(let c):
                guard let field = QuestBook.field(forColor: c, preferring: mine) else { return .skipped("no \(c) field") }
                if let r = work(field: field, giver: giver, index: idx) { return r }
            case .kill(let mobs):
                for g in MobFields.plan(mobs) where !stopped { if hunt(field: g.field) == .interrupted { return .interrupted } }
            case .unsupported: break
            }
            box = readQuestBox(giver)
            if round == 5 { return .skipped("\(giver): still not done after 6 tries") }
        }
        if stopped { return .interrupted }

        guard let done = visitGiver() else { return stopped ? .interrupted : .failed("could not reach \(giver) to turn in") }
        if done.cooldown { return .turnedIn }
        // The speech may have ended without the cooldown line: the log says whether the quest is still there.
        if let after = readQuestBox(giver), QuestLog.tasks(in: after).allSatisfy(\.complete) { return .failed("\(giver) did not take the quest") }
        return .turnedIn
    }

    /// Gathers `field` in short rounds and reads the log between them. nil = this objective is done, go on.
    private func work(field: String, giver: String, index: Int) -> QuestResult? {
        guard resetToHive(afterDeath: died) else { return .interrupted }
        var f = FieldConfig(name: field)
        f.minutes = 1.5
        guard travelTo(f) else { return .interrupted }
        let t0 = clock.now()
        while !stopped && clock.now() - t0 < 25 * 60 {
            let r = gather(f)
            if r.reason == "death" || r.reason == "lost" { return .interrupted }
            if let box = readQuestBox(giver) {
                let t = QuestLog.tasks(in: box)
                if t.indices.contains(index) ? t[index].complete : true { return nil }
            }
            if r.reason == "backpack", !walkBack(f) || !travelTo(f) { return .interrupted }
        }
        return stopped ? .interrupted : nil
    }
}

extension Game {
    /// Opens the quest log (the "?" button, second icon at the top left) when it is closed. The spot is a
    /// share of the window size, so it follows a resized window; the check is the text itself, so a click is
    /// never repeated once the log shows. Gives up after two different tries.
    func openQuestLog() -> Bool {
        var spots: [(Double, Double)] = [(0.049, 0.141)]
        if let ws = windowSize(), ws.width > 0, ws.height > 0, let p = windowPoint(85, 120) {
            spots.append((Double(p.x - ws.left) / Double(ws.width), Double(p.y - ws.top) / Double(ws.height)))
        }
        for (fx, fy) in spots where !stopped {
            guard let p = sensors.point(fx: fx, fy: fy) else { continue }
            actuator.click(p.x, p.y)
            wait(1.0)
            parkMouse()
            if let t = sensors.textIn(Game.logRegion), QuestLog.looksOpen(t) { return true }
        }
        status("warning", "could not open the quest log")
        return false
    }
}
