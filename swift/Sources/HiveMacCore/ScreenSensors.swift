import Foundation

/// What the sensors read pixels from. The real one captures small screen regions.
public protocol ScreenReading: AnyObject {
    /// One pixel at absolute screen coordinates (points), nil if the screen cannot be read.
    func pixel(x: Int, y: Int) -> (r: Int, g: Int, b: Int)?
    /// A small region at absolute screen coordinates (points), nil if the screen cannot be read.
    func grab(_ region: WindowBounds) -> RGBImage?
}

/// The calibrated HUD spots, read from the `hud` section of the settings.
public struct HudConfig {
    public var backpackPixel: RelPoint?
    /// The whole backpack bar. When set it is read by length and wins over the single pixel.
    public var backpackBar: RelRegion?
    /// Where the hive message ("Make Honey", "Stop Making Honey", "To Make Honey, Collect Pollen...") is read.
    public var hiveMessageRegion: RelRegion?
    public var healthPixel: RelPoint?
    public var hivePromptRegion: RelRegion?
    public var hiveViewRegion: RelRegion?
    public var hiveStripRegion: RelRegion?
    public var deathRegion: RelRegion?
    public var hiveStripEnabled = false
    public var hiveStripMinPixels = 40
    public var filterSize = 6
    public var tolerance = 12
    public var hivePromptTemplate: RGBImage?
    /// The same prompt while honey is being made ("Stop Making Honey"): still at the hive, but E must not be pressed.
    public var hivePromptStopTemplate: RGBImage?
    /// The message shown at the hive when the bag is empty ("To Make Honey, Collect Pollen From Flower Fields").
    public var hivePromptEmptyTemplate: RGBImage?
    public var hiveViewTemplate: RGBImage?
    public var cannonPromptTemplate: RGBImage?
    public var deathTemplate: RGBImage?

    public init() {}

    static func point(_ any: Any?) -> RelPoint? {
        guard let d = any as? [String: Any], let fx = (d["fx"] as? NSNumber)?.doubleValue,
              let fy = (d["fy"] as? NSNumber)?.doubleValue else { return nil }
        return RelPoint(fx: fx, fy: fy)
    }

    public static func region(_ any: Any?) -> RelRegion? {
        guard let d = any as? [String: Any], let fx = (d["fx"] as? NSNumber)?.doubleValue,
              let fy = (d["fy"] as? NSNumber)?.doubleValue, let fw = (d["fw"] as? NSNumber)?.doubleValue,
              let fh = (d["fh"] as? NSNumber)?.doubleValue else { return nil }
        return RelRegion(fx: fx, fy: fy, fw: fw, fh: fh)
    }

    /// `loadTemplate` turns a file name in the templates folder into an image (nil if absent).
    public init(store: ConfigStore, loadTemplate: (String) -> RGBImage?) {
        backpackPixel = Self.point(store.get("hud.backpack_pixel"))
        backpackBar = Self.region(store.get("hud.backpack_bar"))
        hiveMessageRegion = Self.region(store.get("hud.hive_message_region"))
        healthPixel = Self.point(store.get("hud.health_pixel"))
        hivePromptRegion = Self.region(store.get("hud.hive_prompt_region"))
        hiveViewRegion = Self.region(store.get("hud.hive_view_region"))
        hiveStripRegion = Self.region(store.get("hud.hive_strip_region"))
        deathRegion = Self.region(store.get("hud.death_region"))
        hiveStripEnabled = store.bool("hud.hive_strip_enabled")
        hiveStripMinPixels = store.int("hud.hive_strip_min_pixels", 40)
        filterSize = store.int("hud.backpack_filter_size", 6)
        tolerance = store.int("hud.template_tolerance", 12)
        func tpl(_ key: String) -> RGBImage? {
            let name = store.string(key)
            return name.isEmpty ? nil : loadTemplate(name)
        }
        hivePromptTemplate = tpl("hud.hive_prompt_template")
        hivePromptStopTemplate = tpl("hud.hive_prompt_stop_template")
        hivePromptEmptyTemplate = tpl("hud.hive_prompt_empty_template")
        hiveViewTemplate = tpl("hud.hive_view_template")
        cannonPromptTemplate = tpl("hud.cannon_prompt_template")
        deathTemplate = tpl("hud.death_template")
    }
}

/// Binds the calibrated layout to the screen and the pure decoders in `Hud`. The macro loop
/// only talks to the `Sensors` protocol, so tests use a fake world and never touch the screen.
public final class ScreenSensors: Sensors {
    private let screen: ScreenReading
    private let window: () -> WindowBounds?
    public var cfg: HudConfig
    private var filter: BackpackFilter
    public private(set) var lastBackpackRGB: (r: Int, g: Int, b: Int)?

    /// Reads the text in an image (the Pollen bar's numbers). Provided by the platform layer.
    public var textReader: ((RGBImage) -> String?)?
    public private(set) var lastBarText: String?
    public private(set) var lastHiveText: String?
    private let loadImage: (String) -> RGBImage?
    private var imageCache: [String: RGBImage] = [:]

    public init(screen: ScreenReading, window: @escaping () -> WindowBounds?, config: HudConfig,
                loadImage: @escaping (String) -> RGBImage? = { _ in nil }) {
        self.screen = screen; self.window = window; self.cfg = config; self.loadImage = loadImage
        filter = BackpackFilter(size: config.filterSize)
    }

    private func bounds() -> WindowBounds? {
        guard let w = window(), w.width > 100, w.height > 100 else { return nil }
        return w
    }

    private func point(_ p: RelPoint?) -> (x: Int, y: Int)? {
        guard let w = bounds(), let p else { return nil }
        return p.absolute(in: w)
    }

    private func region(_ r: RelRegion?) -> RGBImage? {
        guard let w = bounds(), let r else { return nil }
        return screen.grab(r.absolute(in: w))
    }

    /// nil when no template is configured, otherwise whether the template is in the region.
    private func templateIn(_ r: RelRegion?, _ template: RGBImage?) -> Bool? {
        guard let template else { return nil }
        guard let img = region(r) else { return false }
        return ImageSearch.find(img, template: template, tolerance: cfg.tolerance, step: 2) != nil
    }

    public func robloxPresent() -> Bool { bounds() != nil }

    public func backpackRaw() -> Int? {
        if let bar = region(cfg.backpackBar) {
            // The numbers printed in the bar are exact; the fill colour is only the fallback.
            if let read = textReader {
                let text = read(bar)
                lastBarText = text
                if let text, let p = Hud.pollenPercent(fromText: text) { return p }
            }
            return Hud.barPercent(bar)
        }
        guard let p = point(cfg.backpackPixel) else { return nil }
        let rgb = screen.pixel(x: p.x, y: p.y)
        lastBackpackRGB = rgb
        guard let c = rgb else { return nil }
        return Hud.backpackPercent(r: c.r, g: c.g, b: c.b)
    }

    /// What the backpack reading looks at right now, for showing it on screen.
    public func backpackBarImage() -> RGBImage? { region(cfg.backpackBar) }

    public func backpackPercent() -> Int { filter.push(backpackRaw()) }
    public func backpackUnreadableStreak() -> Int { filter.unreadableStreak }
    public func resetBackpackFilter() { filter.reset() }

    public func healthGrey() -> Bool {
        guard let p = point(cfg.healthPixel), let c = screen.pixel(x: p.x, y: p.y) else { return false }
        return Hud.isGrey(r: c.r, g: c.g, b: c.b)
    }

    /// The words of the hive message, lower case, nil when text cannot be read at all.
    private func hiveText() -> String? {
        let area = cfg.hiveMessageRegion ?? bounds().map { Layout.natroDefaults($0, offsetY: 36).hiveMessageRegion }
        guard let read = textReader, let img = region(area) else { return nil }
        let text = (read(img) ?? "").lowercased()
        lastHiveText = text
        return text
    }

    /// At the hive when a hive message is on screen. All three messages contain "honey": Make Honey,
    /// Stop Making Honey, and "To Make Honey, Collect Pollen From Flower Fields" when the bag is empty.
    /// The words are read from the screen; saved pictures count too. nil when neither is possible.
    public func hivePromptVisible() -> Bool? {
        let pictures = [cfg.hivePromptTemplate, cfg.hivePromptStopTemplate, cfg.hivePromptEmptyTemplate]
            .map { templateIn(cfg.hivePromptRegion, $0) }
        let text = hiveText()
        if text == nil && pictures.allSatisfy({ $0 == nil }) { return nil }
        return (text?.contains("honey") ?? false) || pictures.contains(true)
    }

    public func hiveViewVisible() -> Bool? {
        if let r = templateIn(cfg.hiveViewRegion, cfg.hiveViewTemplate) { return r }
        guard cfg.hiveStripEnabled, let strip = region(cfg.hiveStripRegion) else { return nil }
        // Existance macro: white respawn pad or blue balloon colours in the bottom strip.
        let white = ImageSearch.countHLS(strip, low: (0, 40, 0), high: (40, 100, 30))
        let blue = ImageSearch.countHLS(strip, low: (105, 55, 82), high: (120, 86, 100))
        return white + blue >= cfg.hiveStripMinPixels
    }

    public func hiveViewShare() -> Double? {
        guard let w = bounds(), let img = screen.grab(w) else { return nil }
        return Hud.honeycombShare(img)
    }

    public func picture(left: Int, top: Int, width: Int, height: Int) -> RGBImage? {
        screen.grab(WindowBounds(left: left, top: top, width: width, height: height))
    }

    public func promptText() -> String? {
        guard let read = textReader, let w = bounds() else { return nil }
        // A tall band across the top middle: the prompt sits there, whatever its height.
        let band = RelRegion(fx: max(0, (Double(w.width) / 2 - 320) / Double(w.width)), fy: 0, fw: min(1, 640 / Double(w.width)), fh: min(1, 230 / Double(w.height)))
        guard let img = region(band) else { return nil }
        return read(img)?.lowercased()
    }

    public func mobBars() -> [Double]? {
        guard let w = bounds(), let img = screen.grab(w) else { return nil }
        return Hud.mobHealthBars(img)
    }

    /// True while the message says "Stop Making Honey" (E would turn converting off); false when it says
    /// "Make Honey" or the empty-bag message; nil when unknown.
    public func honeyRunning() -> Bool? {
        if let text = hiveText(), !text.isEmpty {
            if text.contains("stop") { return true }
            if text.contains("honey") { return false }
        }
        return templateIn(cfg.hivePromptRegion, cfg.hivePromptStopTemplate)
    }

    public func find(_ template: String, in region: RelRegion?, tolerance: Int) -> (x: Int, y: Int)? {
        guard let w = bounds() else { return nil }
        let image: RGBImage
        if let cached = imageCache[template] { image = cached }
        else if let loaded = loadImage(template) { imageCache[template] = loaded; image = loaded }
        else { return nil }
        let area = region?.absolute(in: w) ?? w
        guard let shot = screen.grab(area),
              let hit = ImageSearch.find(shot, template: image, tolerance: tolerance, step: 1) else { return nil }
        return (area.left + hit.x + image.width / 2, area.top + hit.y + image.height / 2)
    }

    /// True when the prompt says "Fire the Red Cannon". The words are read like the hive message; the saved
    /// picture counts as a second chance. nil when neither is possible.
    public func cannonPromptVisible() -> Bool? {
        let picture = templateIn(cfg.hivePromptRegion, cfg.cannonPromptTemplate)
        guard let text = hiveText() else { return picture }
        return text.contains("cannon") || picture == true
    }
    public func deathTextVisible() -> Bool? { templateIn(cfg.deathRegion, cfg.deathTemplate) }
}
