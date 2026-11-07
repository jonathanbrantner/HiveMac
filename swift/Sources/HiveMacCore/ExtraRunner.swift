import Foundation

/// Does the between-field steps of a run (bug runs, planters, clock and dispensers).
/// The loop asks `due` first and only calls `perform` when something is back, so a mob or planter
/// that is not ready yet is skipped.
public protocol ExtraRunner: AnyObject {
    /// Names that are due right now: mobs, pickups, or "slot 1" style planter slots.
    func due(_ step: ExtraStep, now: TimeInterval) -> [String]
    /// Carries out the step for the due names and records what it finished.
    func perform(_ step: ExtraStep, due: [String], game: Game)
}

/// The runner HiveMac ships today: it knows what is due but the game actions are not built yet,
/// so it says so in the log and leaves every timer untouched (nothing is marked done).
public final class PendingExtraRunner: ExtraRunner {
    public var timers: MobTimers
    public init(timers: MobTimers = MobTimers()) { self.timers = timers }

    public func due(_ step: ExtraStep, now: TimeInterval) -> [String] {
        if step.kind == "planters" { return step.planterSlotsReady(now: now).map { "slot \($0 + 1)" } }
        return timers.due(step.bugs, now: now)
    }

    public func perform(_ step: ExtraStep, due: [String], game: Game) {
        game.status("warning", "\(due.joined(separator: ", ")) due, but \(step.kind.replacingOccurrences(of: "_", with: " ")) is not built yet")
    }
}
