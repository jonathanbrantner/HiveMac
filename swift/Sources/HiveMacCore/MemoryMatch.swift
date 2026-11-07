import Foundation

/// The brain of the memory match game: which tile to flip next, given what has been revealed so far.
/// Flip two tiles per try. If two known tiles match, flip those (a sure pair). Otherwise flip a new tile; if
/// it matches one already seen, flip that one second, else flip another new tile and remember both.
public final class MemoryMatchSolver {
    public let tiles: Int
    public var tolerance = 10
    private var known: [Int: RGBImage] = [:]        // seen, not yet matched
    public private(set) var matched: Set<Int> = []
    private var first: Int?
    private var planned: Int?

    public init(tiles: Int) { self.tiles = tiles }

    public var finished: Bool { matched.count >= tiles }

    private func same(_ a: RGBImage, _ b: RGBImage) -> Bool {
        ImageSearch.find(a, template: b, tolerance: tolerance, step: 2) != nil
    }

    private var unknown: [Int] { (0..<tiles).filter { known[$0] == nil && !matched.contains($0) } }

    /// The tile to click next. nil when nothing is left to try.
    public func next() -> Int? {
        if let p = planned { return p }
        if let f = first {                                            // second flip of a try
            if let img = known[f], let hit = known.first(where: { $0.key != f && same($0.value, img) })?.key { return hit }
            return unknown.first(where: { $0 != f })
        }
        let seen = known.keys.sorted()                                // first flip of a try
        for i in seen { for j in seen where j > i { if same(known[i]!, known[j]!) { planned = j; return i } } }
        return unknown.first
    }

    /// The picture that showed up after flipping `tile`.
    public func record(tile: Int, image: RGBImage) {
        known[tile] = image
        if let f = first {                                            // second flip: did the pair match?
            if f != tile, let a = known[f], same(a, image) {
                matched.insert(f); matched.insert(tile)
                known[f] = nil; known[tile] = nil
            }
            first = nil; planned = nil
        } else {
            first = tile
        }
    }

    /// Plays until finished or `maxFlips`. `reveal` flips a tile on screen and returns its picture (nil = failed).
    /// Returns the number of flips used.
    @discardableResult
    public func play(maxFlips: Int, stop: () -> Bool = { false }, reveal: (Int) -> RGBImage?) -> Int {
        var flips = 0
        while !finished && flips < maxFlips && !stop() {
            guard let tile = next(), let image = reveal(tile) else { break }
            flips += 1
            record(tile: tile, image: image)
        }
        return flips
    }
}

public enum MemoryMatchKind: String, CaseIterable, Sendable {
    case normal, mega, extreme

    public var title: String { rawValue.capitalized }
    /// 16 tiles (4 by 4) or 20 (5 by 4).
    public var tiles: Int { self == .extreme ? 20 : 16 }
    public var pickup: String { "\(rawValue) memory match" }
    public var routeName: String { "memory match \(rawValue)" }
}

public enum MemoryMatchResult: Equatable { case played, onCooldown(TimeInterval), failed(String) }

extension Game {
    /// Natro's tile spots: five columns and four rows around the middle of the window, 80 px apart; the wide
    /// (20 tile) board is 40 px further left.
    func memoryTilePoint(_ index: Int, wide: Bool) -> (x: Int, y: Int)? {
        guard let ws = windowSize() else { return nil }
        let col = index / 4 + 1, row = index % 4 + 1, k = settings.uiScale
        let x = Double(ws.left + ws.width / 2) + (-200 + 80 * Double(col) - (wide ? 40 : 0)) * k
        let y = Double(ws.top + ws.height / 2) + (-200 + 80 * Double(row)) * k
        return (Int(x), Int(y))
    }

    private func relative(left: Int, top: Int, width: Int, height: Int) -> RelRegion? {
        guard let ws = windowSize(), ws.width > 0, ws.height > 0 else { return nil }
        return RelRegion(fx: Double(left - ws.left) / Double(ws.width), fy: Double(top - ws.top) / Double(ws.height),
                         fw: Double(width) / Double(ws.width), fh: Double(height) / Double(ws.height))
    }

    /// Flips one tile and returns its picture once it has turned over.
    private func revealTile(_ index: Int, wide: Bool) -> RGBImage? {
        guard let p = memoryTilePoint(index, wide: wide), let ws = windowSize() else { return nil }
        let k = settings.uiScale
        actuator.click(p.x, p.y)
        wait(0.9)
        actuator.moveMouse(ws.left + ws.width / 2, ws.top + ws.height / 2 - Int(190 * k))
        let area = relative(left: p.x - Int(35 * k), top: p.y - Int(20 * k), width: Int(45 * k), height: Int(30 * k))
        let t0 = clock.now()
        var shown = false
        while !stopped && clock.now() - t0 < 3 {
            if sensors.find("memorymatch/MMBorder", in: area, tolerance: 1) != nil,
               sensors.find("memorymatch/MMEmptyTile", in: area, tolerance: 1) == nil { shown = true; break }
            wait(0.1)
        }
        guard shown else { return nil }
        wait(0.3)
        return sensors.picture(left: p.x - Int(25 * k), top: p.y - Int(25 * k), width: Int(50 * k), height: Int(50 * k))
    }

    /// Walks to a memory match machine, starts the game and plays it. Only acts on what it can see: the
    /// title must be on screen, and a tile only counts once it has turned over.
    public func playMemoryMatch(_ kind: MemoryMatchKind) -> MemoryMatchResult {
        if !resetToHive() { return .failed("could not reach the hive") }
        let variant = settings.travel
        guard let route = pathLookup("to_pickup", kind.routeName, variant) ?? pathLookup("to_pickup", kind.routeName, "walk") else {
            return .failed("no route to the \(kind.title) memory match")
        }
        status("traveling", "\(kind.title) memory match")
        guard walkPath(route) else { return .failed("stopped") }

        if let text = sensors.promptText(), let left = Hud.cooldownSeconds(fromText: text) { return .onCooldown(left) }
        actuator.tap("e", holdS: 0.1)
        wait(1.5)

        guard let ws = windowSize() else { return .failed("no window") }
        let k = settings.uiScale
        let titleArea = relative(left: ws.left + ws.width / 2 - Int(250 * k), top: ws.top + ws.height / 2 - Int(210 * k),
                                 width: Int(500 * k), height: Int(50 * k))
        var wide = kind.tiles == 20
        let t0 = clock.now()
        var open = false
        while !stopped && clock.now() - t0 < 4 {
            if sensors.find("memorymatch/MMTitleWide", in: titleArea, tolerance: 8) != nil { wide = true; open = true; break }
            if sensors.find("memorymatch/MMTitle", in: titleArea, tolerance: 8) != nil { open = true; break }
            wait(0.3)
        }
        guard open else { return .failed("the memory match window did not open") }

        status("gathering", "playing the \(kind.title) memory match")
        let solver = MemoryMatchSolver(tiles: wide ? 20 : 16)
        let flips = solver.play(maxFlips: 60, stop: { self.stopped || self.clock.now() - t0 > 180 }) { tile in
            revealTile(tile, wide: wide)
        }
        actuator.moveMouse(ws.left + 350, ws.top + settings.uiOffsetY + 100)
        wait(1.2)
        status("converting", "memory match done after \(flips) flips, \(solver.matched.count / 2) pairs")
        // Wait for the window to close by itself.
        let end = clock.now()
        while !stopped && clock.now() - end < 12 && sensors.find("memorymatch/MMTitle", in: titleArea, tolerance: 8) != nil { wait(0.5) }
        return .played
    }
}
