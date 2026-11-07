import Foundation

/// Practice mode: stands in for the keyboard and mouse and only writes what it would have done.
/// The sensors stay real, so you can watch the macro read the game while you move by hand.
public final class LoggingActuator: Actuator {
    private let log: (String) -> Void
    private var held: [String: TimeInterval] = [:]
    private var mouse = false
    private let clock: () -> TimeInterval

    public init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }, log: @escaping (String) -> Void) {
        self.clock = clock; self.log = log
    }

    public func keyDown(_ key: String) {
        guard held[key] == nil else { return }
        held[key] = clock()
    }

    public func keyUp(_ key: String) {
        guard let t = held.removeValue(forKey: key) else { return }
        log("Practice: would hold \(key) for \(String(format: "%.1f", clock() - t)) s")
    }

    public func tap(_ key: String, holdS: Double) { log("Practice: would press \(key)") }
    public func mouseDown() { if !mouse { mouse = true; log("Practice: would hold the mouse button down") } }
    public func mouseUp() { if mouse { mouse = false; log("Practice: would let the mouse button go") } }
    public func releaseAll() { held.removeAll(); mouse = false }
}
