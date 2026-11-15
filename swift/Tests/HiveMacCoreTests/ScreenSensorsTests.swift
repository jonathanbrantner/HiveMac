import XCTest
@testable import HiveMacCore

final class FakeScreen: ScreenReading {
    var colours: [String: (r: Int, g: Int, b: Int)] = [:]
    var image: RGBImage?
    var unreadable = false
    var grabs: [WindowBounds] = []
    func pixel(x: Int, y: Int) -> (r: Int, g: Int, b: Int)? { unreadable ? nil : colours["\(x),\(y)"] }
    func grab(_ region: WindowBounds) -> RGBImage? { grabs.append(region); return unreadable ? nil : image }
}

final class ScreenSensorsTests: XCTestCase {
    let win = WindowBounds(left: 100, top: 50, width: 1600, height: 900)

    private func make(_ screen: FakeScreen, _ mutate: (inout HudConfig) -> Void = { _ in }) -> ScreenSensors {
        var cfg = HudConfig()
        cfg.backpackPixel = RelPoint(fx: 0.5, fy: 0.1)
        cfg.healthPixel = RelPoint(fx: 0.9, fy: 0.05)
        cfg.hivePromptRegion = RelRegion(fx: 0.4, fy: 0.0, fw: 0.2, fh: 0.1)
        mutate(&cfg)
        return ScreenSensors(screen: screen, window: { self.win }, config: cfg)
    }

    func testBackpackReadsThroughTheLadderAndFilter() {
        let screen = FakeScreen()
        let s = make(screen)
        let p = RelPoint(fx: 0.5, fy: 0.1).absolute(in: win)
        screen.colours["\(p.x),\(p.y)"] = (0xF7, 0x00, 0x17)          // 100 percent
        XCTAssertEqual(s.backpackRaw(), 100)
        XCTAssertEqual(s.backpackPercent(), 100)
        screen.colours["\(p.x),\(p.y)"] = (0x75, 0x75, 0x75)          // not a bar colour: counts as 0 and as unreadable
        XCTAssertEqual(s.backpackPercent(), 50)                        // mean of 100 and 0
        XCTAssertEqual(s.backpackUnreadableStreak(), 1)
        s.resetBackpackFilter()
        XCTAssertEqual(s.backpackUnreadableStreak(), 0)
    }

    func testNoCalibrationOrNoWindowMeansNothingIsRead() {
        let screen = FakeScreen()
        let uncal = ScreenSensors(screen: screen, window: { self.win }, config: HudConfig())
        XCTAssertNil(uncal.backpackRaw()); XCTAssertFalse(uncal.healthGrey())
        XCTAssertNil(uncal.hivePromptVisible()); XCTAssertNil(uncal.hiveViewVisible())
        let noWin = ScreenSensors(screen: screen, window: { nil }, config: HudConfig())
        XCTAssertFalse(noWin.robloxPresent())
        let tiny = ScreenSensors(screen: screen, window: { WindowBounds(left: 0, top: 0, width: 50, height: 50) }, config: HudConfig())
        XCTAssertFalse(tiny.robloxPresent())
    }

    func testHealthGreyBand() {
        let screen = FakeScreen()
        let s = make(screen)
        let p = RelPoint(fx: 0.9, fy: 0.05).absolute(in: win)
        screen.colours["\(p.x),\(p.y)"] = (0x70, 0x70, 0x70); XCTAssertTrue(s.healthGrey())
        screen.colours["\(p.x),\(p.y)"] = (0xF0, 0x20, 0x20); XCTAssertFalse(s.healthGrey())
        screen.unreadable = true; XCTAssertFalse(s.healthGrey())
    }

    func testTemplateChecksReturnNilWithoutTemplateElseFindOrMiss() {
        let screen = FakeScreen()
        var tpl = RGBImage(width: 3, height: 3, fill: (250, 250, 250)); tpl.set(1, 1, (20, 20, 200))
        var img = RGBImage(width: 40, height: 20, fill: (30, 30, 30))
        for y in 0..<3 { for x in 0..<3 { img.set(10 + x, 5 + y, (UInt8(tpl.pixel(x, y).r), UInt8(tpl.pixel(x, y).g), UInt8(tpl.pixel(x, y).b))) } }
        screen.image = img
        XCTAssertNil(make(screen).hivePromptVisible())                 // no template: "unknown", not false
        let s = make(screen) { $0.hivePromptTemplate = tpl }
        XCTAssertEqual(s.hivePromptVisible(), true)
        XCTAssertEqual(screen.grabs.last, RelRegion(fx: 0.4, fy: 0.0, fw: 0.2, fh: 0.1).absolute(in: win))
        screen.image = RGBImage(width: 40, height: 20, fill: (30, 30, 30))
        XCTAssertEqual(s.hivePromptVisible(), false)
        screen.unreadable = true
        XCTAssertEqual(s.hivePromptVisible(), false)                   // configured but unreadable counts as not seen
    }

    func testHiveStripColourFallback() {
        let screen = FakeScreen()
        screen.image = RGBImage(width: 20, height: 5, fill: (255, 255, 255))     // lots of white
        let on = make(screen) { $0.hiveStripRegion = RelRegion(fx: 0.4, fy: 0.9, fw: 0.2, fh: 0.1); $0.hiveStripEnabled = true; $0.hiveStripMinPixels = 40 }
        XCTAssertEqual(on.hiveViewVisible(), true)
        screen.image = RGBImage(width: 20, height: 5, fill: (0, 0, 0))
        XCTAssertEqual(on.hiveViewVisible(), false)
        let off = make(screen) { $0.hiveStripRegion = RelRegion(fx: 0.4, fy: 0.9, fw: 0.2, fh: 0.1); $0.hiveStripEnabled = false }
        XCTAssertNil(off.hiveViewVisible())
    }

    func testHudConfigReadsStoreAndLoadsTemplatesByName() {
        let defaults: [String: Any] = ["hud": [
            "backpack_pixel": ["fx": 0.5, "fy": 0.1], "health_pixel": NSNull(),
            "hive_prompt_region": ["fx": 0.1, "fy": 0.2, "fw": 0.3, "fh": 0.4], "hive_prompt_template": "hive_prompt.png",
            "hive_view_template": "", "template_tolerance": 7, "backpack_filter_size": 4, "hive_strip_enabled": true]]
        let store = ConfigStore(defaults: defaults, url: nil)
        var asked: [String] = []
        let cfg = HudConfig(store: store) { name in asked.append(name); return RGBImage(width: 1, height: 1, fill: (1, 2, 3)) }
        XCTAssertEqual(cfg.backpackPixel, RelPoint(fx: 0.5, fy: 0.1))
        XCTAssertNil(cfg.healthPixel)
        XCTAssertEqual(cfg.hivePromptRegion, RelRegion(fx: 0.1, fy: 0.2, fw: 0.3, fh: 0.4))
        XCTAssertEqual(cfg.tolerance, 7); XCTAssertEqual(cfg.filterSize, 4); XCTAssertTrue(cfg.hiveStripEnabled)
        XCTAssertEqual(asked, ["hive_prompt.png"])                     // empty and missing names are never loaded
        XCTAssertNotNil(cfg.hivePromptTemplate); XCTAssertNil(cfg.hiveViewTemplate)
    }
}

final class HiveMessageTests: XCTestCase {
    private func sensors(reading text: String?) -> ScreenSensors {
        let screen = FakeScreen()
        screen.image = RGBImage(width: 10, height: 10, fill: (0, 0, 0))
        let s = ScreenSensors(screen: screen, window: { WindowBounds(left: 0, top: 0, width: 1600, height: 900) }, config: HudConfig())
        s.textReader = { _ in text }
        return s
    }

    func testAllThreeHiveMessagesCountAsAtTheHive() {
        for t in ["Make Honey", "Stop Making Honey", "To Make Honey, Collect Pollen From Flower Fields"] {
            XCTAssertEqual(sensors(reading: t).hivePromptVisible(), true, t)
        }
    }

    func testOnlyStopMakingHoneyMeansHoneyIsRunning() {
        XCTAssertEqual(sensors(reading: "E Stop Making Honey").honeyRunning(), true)
        XCTAssertEqual(sensors(reading: "E Make Honey").honeyRunning(), false)
        XCTAssertEqual(sensors(reading: "To Make Honey, Collect Pollen From Flower Fields").honeyRunning(), false)
    }

    func testNoHiveMessageMeansNotAtTheHive() {
        XCTAssertEqual(sensors(reading: "").hivePromptVisible(), false)
        XCTAssertEqual(sensors(reading: "Mantis: 15:38").hivePromptVisible(), false)
    }
}

final class CannonPromptTests: XCTestCase {
    private func sensors(reading text: String) -> ScreenSensors {
        let screen = FakeScreen()
        screen.image = RGBImage(width: 10, height: 10, fill: (0, 0, 0))
        let s = ScreenSensors(screen: screen, window: { WindowBounds(left: 0, top: 0, width: 1600, height: 900) }, config: HudConfig())
        s.textReader = { _ in text }
        return s
    }

    func testReadsTheRedCannonPrompt() {
        XCTAssertEqual(sensors(reading: "Fire the Red Cannon").cannonPromptVisible(), true)
        XCTAssertEqual(sensors(reading: "To Make Honey, Collect Pollen From Flower Fields").cannonPromptVisible(), false)
        XCTAssertEqual(sensors(reading: "").cannonPromptVisible(), false)
    }
}

/// The Roblox HUD is a fixed pixel size, so the spots must follow the window and not stay at the shares they had when set.
final class WindowFollowingTests: XCTestCase {
    private func grabs(in window: WindowBounds, stale: Bool, customBar: Bool = false) -> [WindowBounds] {
        let screen = FakeScreen()
        screen.image = RGBImage(width: 8, height: 8, pixels: [UInt8](repeating: 0, count: 8 * 8 * 3))
        var cfg = HudConfig()
        cfg.followWindow = true
        cfg.backpackBarCustom = customBar
        // Shares saved while the window was 1429 x 885 (the numbers of a real settings.json).
        if stale {
            cfg.backpackBar = RelRegion(fx: 0.5353, fy: 0.0282, fw: 0.1617, fh: 0.0384)
            cfg.hiveMessageRegion = RelRegion(fx: 0.3181, fy: 0.0689, fw: 0.3639, fh: 0.1469)
        }
        let s = ScreenSensors(screen: screen, window: { window }, config: cfg)
        s.textReader = { _ in "" }
        _ = s.backpackRaw()
        _ = s.hivePromptVisible()
        return screen.grabs
    }

    func testSpotsFollowTheWindowEvenWithSavedSharesFromAnotherSize() {
        let big = WindowBounds(left: 0, top: 0, width: 2560, height: 1298)
        let g = grabs(in: big, stale: true)
        // Pollen bar in the real 2560 wide window: x 1340 to 1560, y about 30 to 58.
        let bar = g[0]
        XCTAssertLessThanOrEqual(bar.left, 1340); XCTAssertGreaterThanOrEqual(bar.left + bar.width, 1560)
        XCTAssertLessThanOrEqual(bar.top, 36); XCTAssertGreaterThanOrEqual(bar.top + bar.height, 52)      // the digits
        XCTAssertLessThan(bar.top + bar.height, 68, "it must stay above the banner")
        // The banner "To Make Honey, Collect Pollen From Flower Fields": x 1105 to 1455, y 68 to 125.
        let msg = g[1]
        XCTAssertLessThanOrEqual(msg.left, 1105); XCTAssertGreaterThanOrEqual(msg.left + msg.width, 1455)
        XCTAssertLessThanOrEqual(msg.top, 68); XCTAssertGreaterThanOrEqual(msg.top + msg.height, 125)
    }

    func testTheSameSpotsWorkInASmallerWindow() {
        let small = WindowBounds(left: 40, top: 30, width: 1429, height: 885)
        let g = grabs(in: small, stale: false)
        XCTAssertEqual(g[0].left, 40 + 1429 / 2 + 59, "the bar starts 59 px right of the window centre")
        XCTAssertEqual(g[1].top, 30 + 36 + 25)
    }

    func testABarPickedByHandStaysWhereItWasPicked() {
        let big = WindowBounds(left: 0, top: 0, width: 2560, height: 1298)
        let g = grabs(in: big, stale: true, customBar: true)
        XCTAssertEqual(g[0].left, Int((0.5353 * 2560).rounded()))
    }
}
