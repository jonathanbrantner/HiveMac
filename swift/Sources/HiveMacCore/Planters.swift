import Foundation

/// Placing and harvesting planters, the way Natro does it: open the item menu, find the planter in the
/// inventory, drag it onto the field, answer the Yes dialog. Every click and drag happens only after the
/// picture it is aimed at has been found on screen, so a wrong guess stops the step instead of clicking.
public enum PlanterFiles {
    /// Planter name in the app -> picture file name (Natro's inventory pictures).
    public static let image: [String: String] = [
        "paper": "PaperPlanter", "ticket": "TicketPlanter", "festive": "FestivePlanter", "plastic": "PlasticPlanter",
        "candy": "CandyPlanter", "red clay": "RedClayPlanter", "blue clay": "BlueClayPlanter", "tacky": "TackyPlanter",
        "pesticide": "PesticidePlanter", "heat-treated": "HeatTreatedPlanter", "hydroponic": "HydroponicPlanter",
        "petal": "PetalPlanter", "planter of plenty": "PlanterOfPlenty",
    ]
}

public enum PlanterResult: Equatable { case done, missing(String), failed(String) }

extension Game {
    /// A point in the window using Natro's pixel spots (scaled by the UI scale), below the Roblox top bar.
    func windowPoint(_ dx: Int, _ dy: Int) -> (x: Int, y: Int)? {
        guard let ws = windowSize() else { return nil }
        let k = settings.uiScale
        return (ws.left + Int(Double(dx) * k), ws.top + Int(Double(settings.uiOffsetY + dy) * k))
    }

    private func region(_ fx: Double, _ fy: Double, _ fw: Double, _ fh: Double) -> RelRegion { RelRegion(fx: fx, fy: fy, fw: fw, fh: fh) }

    /// Waits up to `seconds` for a picture to show; returns where.
    func waitFor(_ template: String, in r: RelRegion?, seconds: Double, tolerance: Int = 5) -> (x: Int, y: Int)? {
        let t0 = clock.now()
        repeat {
            if let p = sensors.find(template, in: r, tolerance: tolerance) { return p }
            if stopped { return nil }
            wait(0.2)
        } while clock.now() - t0 < seconds
        return nil
    }

    /// Clicks the item menu button at the top left and checks the inventory opened.
    public func openItemMenu() -> Bool {
        guard let p = windowPoint(30, 120) else { return false }
        actuator.click(p.x, p.y)
        wait(0.6)
        return waitFor("item", in: region(0, 0.1, 0.25, 0.9), seconds: 3, tolerance: 2) != nil
    }

    /// Scrolls the inventory list and looks for a planter's picture. nil when it is not in the inventory.
    public func findInInventory(_ file: String, maxScrolls: Int = 45) -> (x: Int, y: Int)? {
        let strip = region(0, 0.12, 0.25, 0.88)
        if let p = sensors.find(file, in: strip, tolerance: 5) { return p }
        guard let anchor = windowPoint(30, 200) else { return nil }
        actuator.moveMouse(anchor.x, anchor.y)
        for _ in 0..<60 { actuator.scroll(-3); wait(0.02) }             // to the bottom of the list
        for _ in 0..<maxScrolls {
            if stopped { return nil }
            wait(0.5)
            if let p = sensors.find(file, in: strip, tolerance: 5) { return p }
            actuator.scroll(1)
        }
        return nil
    }

    private func clickYes(seconds: Double) -> Bool {
        guard let p = waitFor("yes", in: region(0.3, 0.3, 0.4, 0.3), seconds: seconds, tolerance: 2) else { return false }
        actuator.click(p.x, p.y)
        wait(0.3)
        return true
    }

    /// Puts a planter on a field. From the hive when `atField` is false, or right where you stand.
    public func placePlanter(_ planter: String, field: String, atField: Bool) -> PlanterResult {
        guard let file = PlanterFiles.image[planter] else { return .failed("unknown planter \(planter)") }
        status("traveling", "planter \(planter) (\(field))")
        if !atField && !resetToHive() { return .failed("could not reach the hive") }
        guard openItemMenu() else { return .failed("the inventory did not open (check the UI scale in the settings file)") }
        guard findInInventory(file) != nil else { return .missing(planter) }
        if !atField {
            guard let route = pathLookup("to_planter", field, settings.travel) ?? pathLookup("to_planter", field, "walk") else {
                return .failed("no route to the \(field) planter spot")
            }
            if !walkPath(route) { return .failed("stopped on the way") }
        }
        status("converting", "placing \(planter)")
        guard let centre = windowSize().map({ ($0.left + $0.width / 2, $0.top + $0.height / 2) }) else { return .failed("no window") }
        let gripX = windowPoint(30, 0)?.x ?? centre.0
        for _ in 0..<10 {
            if stopped { return .failed("stopped") }
            // The planter is gone from the list once it is placed, or the Yes dialog is already up.
            guard let spot = sensors.find(file, in: region(0, 0.12, 0.25, 0.88), tolerance: 5) else { break }
            if sensors.find("yes", in: region(0.3, 0.3, 0.4, 0.3), tolerance: 2) != nil { break }
            actuator.drag(fromX: gripX, fromY: spot.y, toX: centre.0, toY: centre.1)
            wait(0.4)
        }
        guard clickYes(seconds: 6) else { return .failed("the Yes button did not appear") }
        wait(0.6)
        return .done
    }

    /// Walks to a planter and collects it.
    public func harvestPlanter(field: String) -> PlanterResult {
        status("traveling", "harvest planter (\(field))")
        if !resetToHive() { return .failed("could not reach the hive") }
        guard let route = pathLookup("to_planter", field, settings.travel) ?? pathLookup("to_planter", field, "walk") else {
            return .failed("no route to the \(field) planter spot")
        }
        if !walkPath(route) { return .failed("stopped on the way") }
        guard waitFor("e_button", in: region(0.3, 0.05, 0.4, 0.25), seconds: 1.5, tolerance: 6) != nil else {
            return .failed("no planter prompt at the spot")
        }
        actuator.tap("e", holdS: 0.1)
        wait(0.5)
        guard clickYes(seconds: 5) else { return .failed("the Yes button did not appear") }
        wait(0.8)
        return .done
    }
}
