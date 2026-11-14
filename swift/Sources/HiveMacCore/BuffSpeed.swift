import Foundation

/// Which walk speed buffs are on, read from the buff bar. Natro's `DetectMovespeed` (Walk.ahk), not the stats panel.
public struct BuffState: Equatable, Sendable {
    public var haste = 0               // Haste stack (0 none, 1 plain, 2...10 with a multiplier)
    public var coconutHaste = false    // the second haste icon
    public var hastePlus = false       // Haste+ (x2)
    public var oil = false             // x1.2
    public var smoothie = false        // Super Smoothie x1.25
    public var bear = false            // any Bear Morph
    public init() {}
    public var any: Bool { haste > 0 || coconutHaste || hastePlus || oil || smoothie || bear }
    public var text: String {
        var p: [String] = []
        if haste > 0 { p.append("haste x\(haste)") }
        if coconutHaste { p.append("coconut haste") }
        if hastePlus { p.append("haste+") }
        if oil { p.append("oil") }
        if smoothie { p.append("smoothie") }
        if bear { p.append("bear morph") }
        return p.isEmpty ? "no speed buffs" : p.joined(separator: ", ")
    }
}

/// Natro's speed formula. `movespeed` is the exact in-game walk speed without buffs; Hasty Guard and Gifted Hasty
/// bees are part of that number, so the base is worked back out of it the way Natro does.
public struct BuffSpeedModel: Sendable {
    public var baseSpeed: Double
    public var hastyGuard: Bool
    public var giftedHasty: Bool
    public var bearBonus: Double

    public init(movespeed: Double, bearBonus: Double = 4) {
        let ms = movespeed
        func rem(_ d: Double) -> Double { let q = (ms * 1000).truncatingRemainder(dividingBy: d); return q }
        let both = rem(1265) == 0 || ((ms + 0.005) * 1000).rounded().truncatingRemainder(dividingBy: 1265) == 0
        hastyGuard = both || rem(1100) < 0.00001
        giftedHasty = both || rem(1150) < 0.00001
        baseSpeed = (ms / (both ? 1.265 : (hastyGuard ? 1.1 : (giftedHasty ? 1.15 : 1)))).rounded()
        self.bearBonus = bearBonus
    }

    /// Studs per second. `hasteCap`: haste stacks up to the cap are ignored (Natro's option).
    public func speed(_ s: BuffState, hasteCap: Int = 0) -> Double {
        (baseSpeed + (s.coconutHaste ? 10 : 0) + (s.bear ? bearBonus : 0))
            * (hastyGuard ? 1.1 : 1) * (giftedHasty ? 1.15 : 1)
            * (1 + Double(max(0, s.haste - hasteCap)) * 0.1)
            * (s.hastePlus ? 2 : 1) * (s.oil ? 1.2 : 1) * (s.smoothie ? 1.25 : 1)
    }
}

/// Finds the buffs in a picture of the buff bar at 1 pixel per point (about 30 rows tall, the window wide), the way Natro does:
/// tiny one row colour bars, no text reading.
public enum BuffDetector {
    struct Needle { let w: Int, h: Int, rgb: [UInt8] }

    static func solid(_ w: Int, _ h: Int, _ r: UInt8, _ g: UInt8, _ b: UInt8) -> Needle {
        Needle(w: w, h: h, rgb: (0..<(w * h)).flatMap { _ in [r, g, b] })
    }
    static let haste = solid(10, 1, 240, 240, 240)
    static let melody = solid(3, 2, 36, 36, 36)
    static let hastePlus = solid(20, 1, 237, 219, 76)
    static let table: [String: Needle] = {
        var d: [String: Needle] = [:]
        for t in BuffTemplates.all { d[t.name] = Needle(w: t.w, h: t.h, rgb: t.rgb) }
        return d
    }()
    static let bears = ["bearbrown", "bearblack", "bearpanda", "bearpolar", "beargummy", "bearscience", "bearmother"]

    /// First match of `needle` with every colour channel within `variation`, columns left to right, rows bottom to top
    /// (Natro's search direction 6). Region is inclusive of x1...x2 / y1...y2 for the needle's top left corner; nil = whole.
    static func find(_ img: RGBImage, _ n: Needle, variation: Int, x1: Int = 0, y1: Int = 0, x2: Int? = nil, y2: Int? = nil,
                     columnsFirst: Bool = true) -> (x: Int, y: Int)? {
        let maxX = min(img.width - n.w, x2.map { $0 - n.w + 1 } ?? Int.max), maxY = min(img.height - n.h, y2.map { $0 - n.h + 1 } ?? Int.max)
        let minX = max(0, x1), minY = max(0, y1)
        guard maxX >= minX, maxY >= minY else { return nil }
        func matches(_ x: Int, _ y: Int) -> Bool {
            for j in 0..<n.h {
                var ip = ((y + j) * img.width + x) * 3, np = j * n.w * 3
                for _ in 0..<n.w {
                    if abs(Int(img.pixels[ip]) - Int(n.rgb[np])) > variation || abs(Int(img.pixels[ip + 1]) - Int(n.rgb[np + 1])) > variation
                        || abs(Int(img.pixels[ip + 2]) - Int(n.rgb[np + 2])) > variation { return false }
                    ip += 3; np += 3
                }
            }
            return true
        }
        if columnsFirst {
            for x in minX...maxX { for y in stride(from: maxY, through: minY, by: -1) where matches(x, y) { return (x, y) } }
        } else {
            for y in minY...maxY { for x in minX...maxX where matches(x, y) { return (x, y) } }
        }
        return nil
    }

    public static func detect(_ img: RGBImage) -> BuffState {
        var s = BuffState()
        var x = 0, hastes = 0, x1 = 0, y1 = 0
        for _ in 0..<3 {                                     // melody, haste, coconut haste
            guard let h = find(img, haste, variation: 2, x1: x, y1: 14, y2: 29) else { break }
            x = h.x; let y = h.y
            if find(img, melody, variation: 12, x1: x + 2, y1: 0, x2: x + max(16, 2 * y - 24), y2: y) == nil {   // not melody, so haste
                hastes += 1
                if hastes == 1 { x1 = x; y1 = y }
            }
            x += 2 * y - 14                                  // skip this icon on the next search
        }
        s.coconutHaste = hastes == 2
        if hastes > 0 {
            s.haste = 1
            for i in 1...9 {                                 // digits 9 down to 1 (a "1" means 10)
                guard let d = table["digit\(10 - i)"] else { continue }
                if find(img, d, variation: 16, x1: x1 + 2 * y1 - 44, y1: max(0, y1 - 18), x2: x1 + 2 * y1 - 14, y2: y1 - 1) != nil {
                    s.haste = i == 9 ? 10 : 10 - i; break
                }
            }
        }
        s.hastePlus = find(img, hastePlus, variation: 4, y1: 22, y2: 29, columnsFirst: false) != nil
        if let o = table["oil"] { s.oil = find(img, o, variation: 4, y1: 22, y2: 29, columnsFirst: false) != nil }
        if let m = table["smoothie"] { s.smoothie = find(img, m, variation: 4, y1: 22, y2: 29, columnsFirst: false) != nil }
        for b in bears { if let n = table[b], find(img, n, variation: 8, y1: 22, y2: 29, columnsFirst: false) != nil { s.bear = true; break } }
        return s
    }

    /// Averages a picture taken at `factor` pixels per point down to one pixel per point.
    public static func downscale(_ img: RGBImage, factor: Int) -> RGBImage {
        guard factor > 1 else { return img }
        let w = img.width / factor, h = img.height / factor
        guard w > 0, h > 0 else { return img }
        var out = [UInt8](repeating: 0, count: w * h * 3)
        let div = factor * factor
        for y in 0..<h { for x in 0..<w {
            var r = 0, g = 0, b = 0
            for j in 0..<factor { for i in 0..<factor {
                let p = ((y * factor + j) * img.width + x * factor + i) * 3
                r += Int(img.pixels[p]); g += Int(img.pixels[p + 1]); b += Int(img.pixels[p + 2])
            } }
            let o = (y * w + x) * 3
            out[o] = UInt8(r / div); out[o + 1] = UInt8(g / div); out[o + 2] = UInt8(b / div)
        } }
        return RGBImage(width: w, height: h, pixels: out)
    }
}

/// Reads the buff bar of the game window and turns it into a walk speed. About a 30 row crop and a few one row
/// searches per reading, no text recognition and no file written.
public final class BuffSpeedReader {
    private let screen: ScreenReading
    private let window: () -> WindowBounds?
    public var model: BuffSpeedModel
    /// Rows of the window below its top where the buff icons start (Natro: 48 on Windows; 60 on this Mac's window layout).
    public var stripTop = 60
    public var stripHeight = 32
    public private(set) var last = BuffState()
    public private(set) var lastSpeed: Double?
    public private(set) var lastReadSeconds = 0.0
    private var failures = 0

    public init(screen: ScreenReading, window: @escaping () -> WindowBounds?, model: BuffSpeedModel) {
        self.screen = screen; self.window = window; self.model = model
    }

    /// The buff bar as a 1 pixel per point picture, or nil when the screen cannot be read.
    public func strip() -> RGBImage? {
        guard let w = window() else { return nil }
        let region = WindowBounds(left: w.left, top: w.top + stripTop, width: w.width, height: stripHeight)
        guard let img = screen.grab(region), img.width >= region.width else { return nil }
        return BuffDetector.downscale(img, factor: max(1, Int((Double(img.width) / Double(max(1, region.width))).rounded())))
    }

    /// The walk speed now, or nil when the bar could not be read (the caller then keeps the speed it had).
    public func read() -> Double? {
        let t0 = Date()
        defer { lastReadSeconds = Date().timeIntervalSince(t0) }
        guard let img = strip() else { failures += 1; return nil }
        failures = 0
        last = BuffDetector.detect(img)
        lastSpeed = model.speed(last)
        return lastSpeed
    }
}

extension BuffDetector {
    public static func debugHaste(_ img: RGBImage) -> String {
        guard let h = find(img, haste, variation: 2, x1: 0, y1: 14, y2: 29) else { return "none" }
        let px = (0..<10).map { img.pixel(h.x + $0, h.y) }
        return "x=\(h.x) y=\(h.y) row=\(px)"
    }
    /// Draws Natro's own bitmaps into blank strips (also at 2 pixels per point, then averaged down) and checks that they are
    /// found, and that a blank strip finds nothing. Returns lines that failed; empty means all fine.
    public static func selfTest() -> [String] {
        var bad: [String] = []
        func blank() -> RGBImage { RGBImage(width: 400, height: 32, fill: (90, 120, 90)) }
        func draw(_ img: inout RGBImage, _ n: Needle, x: Int, y: Int) {
            for j in 0..<n.h { for i in 0..<n.w { let p = (j * n.w + i) * 3; img.set(x + i, y + j, (n.rgb[p], n.rgb[p + 1], n.rgb[p + 2])) } }
        }
        if BuffDetector.detect(blank()).any { bad.append("blank strip found a buff") }
        for b in bears {
            guard let n = table[b] else { bad.append("missing template \(b)"); continue }
            var img = blank(); draw(&img, n, x: 100, y: 25)
            if !BuffDetector.detect(img).bear { bad.append("\(b) not found") }
        }
        for (name, set) in [("oil", { (s: BuffState) in s.oil }), ("smoothie", { $0.smoothie })] {
            var img = blank(); draw(&img, table[name]!, x: 60, y: 26)
            if !set(BuffDetector.detect(img)) { bad.append("\(name) not found") }
        }
        var hp = blank(); draw(&hp, hastePlus, x: 50, y: 26)
        if !BuffDetector.detect(hp).hastePlus { bad.append("haste+ not found") }
        // Haste: a grey bar at row 26 (icon 38 wide), then with a second one 38 further right = coconut haste.
        var h1 = blank(); draw(&h1, haste, x: 20, y: 26)
        let d1 = BuffDetector.detect(h1)
        if d1.haste != 1 || d1.coconutHaste { bad.append("haste: \(d1.text)") }
        var h2 = h1; draw(&h2, haste, x: 20 + 2 * 26 - 14, y: 26)
        let d2 = BuffDetector.detect(h2)
        if !d2.coconutHaste { bad.append("coconut haste: \(d2.text)") }
        // Melody (dark mark next to a haste bar) is not haste.
        var m = blank(); draw(&m, haste, x: 20, y: 26); draw(&m, melody, x: 24, y: 24)
        if BuffDetector.detect(m).haste != 0 { bad.append("melody counted as haste") }
        // At 2 pixels per point, averaged down.
        var big = RGBImage(width: 800, height: 64, fill: (90, 120, 90))
        if let n = table["bearpanda"] { for j in 0..<n.h { for i in 0..<n.w { let p = (j * n.w + i) * 3
            for dy in 0..<2 { for dx in 0..<2 { big.set(200 + i * 2 + dx, 50 + j * 2 + dy, (n.rgb[p], n.rgb[p + 1], n.rgb[p + 2])) } } } } }
        if !BuffDetector.detect(downscale(big, factor: 2)).bear { bad.append("bear at 2x not found") }
        // The speed formula.
        let m1 = BuffSpeedModel(movespeed: 29)
        var st = BuffState(); st.haste = 1
        if abs(m1.speed(st) - 29 * 1.1) > 0.001 { bad.append("haste speed \(m1.speed(st))") }
        st.bear = true; st.hastePlus = true
        if abs(m1.speed(st) - 33 * 1.1 * 2) > 0.001 { bad.append("bear+haste+ speed \(m1.speed(st))") }
        let g = BuffSpeedModel(movespeed: 31.9)
        if g.baseSpeed != 29 || !g.hastyGuard { bad.append("hasty guard base \(g.baseSpeed)") }
        return bad
    }
}
