import Foundation
import IOKit.pwr_mgt

/// Keeps the Mac and its display awake while a run is going, so the screen never dims or locks and the game keeps getting
/// frames (the display sleeps after 20 minutes by default). It tells macOS "the user is active" like a video player does,
/// so the pointer is never moved and the game is not touched. Released when the run ends or the app quits.
final class SleepBlocker {
    private var displayAssertion = IOPMAssertionID(0)
    private var systemAssertion = IOPMAssertionID(0)
    private(set) var active = false

    func start() {
        guard !active else { return }
        let reason = "HiveMac is running a farming session" as CFString
        let d = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                                            IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &displayAssertion)
        let s = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,
                                            IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &systemAssertion)
        active = d == kIOReturnSuccess || s == kIOReturnSuccess
    }

    func stop() {
        guard active else { return }
        if displayAssertion != 0 { IOPMAssertionRelease(displayAssertion); displayAssertion = 0 }
        if systemAssertion != 0 { IOPMAssertionRelease(systemAssertion); systemAssertion = 0 }
        active = false
    }

    deinit { stop() }
}
