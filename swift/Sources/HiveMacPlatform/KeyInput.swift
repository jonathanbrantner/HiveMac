import Foundation
import CoreGraphics
import HiveMacCore

/// Key and mouse output through Quartz events, the same route Roblox accepts from Natro and
/// the Python app. Needs the Accessibility permission. Everything held is tracked so
/// `releaseAll` always knows what to let go of.
public final class KeyInput: Actuator {
    private let source = CGEventSource(stateID: .combinedSessionState)
    private let lock = NSLock()
    private var held = Set<String>()
    private var mouseIsDown = false
    private static let movementKeys = ["w", "a", "s", "d", "space", "shift"]

    public init() {}

    private func post(_ code: UInt16, down: Bool) {
        CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: down)?.post(tap: .cghidEventTap)
    }

    public func keyDown(_ key: String) {
        guard let code = KeyCodes.code(for: key) else { return }
        lock.lock(); held.insert(key.lowercased()); lock.unlock()
        post(code, down: true)
    }

    public func keyUp(_ key: String) {
        guard let code = KeyCodes.code(for: key) else { return }
        lock.lock(); held.remove(key.lowercased()); lock.unlock()
        post(code, down: false)
    }

    public func tap(_ key: String, holdS: Double = 0.03) {
        keyDown(key)
        Thread.sleep(forTimeInterval: holdS)
        keyUp(key)
    }

    private func mouseEvent(_ type: CGEventType) {
        let pos = CGEvent(source: nil)?.location ?? .zero
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: pos, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    public func mouseDown() { lock.lock(); mouseIsDown = true; lock.unlock(); mouseEvent(.leftMouseDown) }
    public func mouseUp() { lock.lock(); mouseIsDown = false; lock.unlock(); mouseEvent(.leftMouseUp) }

    public func moveMouse(_ x: Int, _ y: Int) {
        CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    public func click(_ x: Int, _ y: Int) {
        moveMouse(x, y)
        Thread.sleep(forTimeInterval: 0.08)
        mouseEvent(.leftMouseDown)
        Thread.sleep(forTimeInterval: 0.06)
        mouseEvent(.leftMouseUp)
    }

    public func drag(fromX: Int, fromY: Int, toX: Int, toY: Int) {
        moveMouse(fromX, fromY)
        Thread.sleep(forTimeInterval: 0.1)
        lock.lock(); mouseIsDown = true; lock.unlock()
        mouseEvent(.leftMouseDown)
        let steps = 12
        for i in 1...steps {
            let x = fromX + (toX - fromX) * i / steps, y = fromY + (toY - fromY) * i / steps
            CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
            let pos = CGPoint(x: x, y: y)
            CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: pos, mouseButton: .left)?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.02)
        }
        Thread.sleep(forTimeInterval: 0.1)
        lock.lock(); mouseIsDown = false; lock.unlock()
        mouseEvent(.leftMouseUp)
    }

    public func scroll(_ ticks: Int) {
        CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1, wheel1: Int32(ticks), wheel2: 0, wheel3: 0)?
            .post(tap: .cghidEventTap)
    }

    /// Lets go of everything the macro might have held, plus the movement keys, then the mouse.
    public func releaseAll() {
        lock.lock()
        let keys = held.union(Self.movementKeys)
        held.removeAll()
        lock.unlock()
        for k in keys { if let c = KeyCodes.code(for: k) { post(c, down: false) } }
        mouseEvent(.leftMouseUp)
    }

}
