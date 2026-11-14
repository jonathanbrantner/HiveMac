import Foundation
import HiveMacCore
import HiveMacPlatform

/// Saves a picture of the Roblox window at the start, after every step and at the end of each walking route, so a route
/// that goes wrong can be followed frame by frame: traces/<time>-<route>/NN-<step>.png. Only the newest folders are kept.
enum RouteTrace {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var folder: URL?

    static func hook(root: URL, grab: @escaping () -> RGBImage?) -> (String, Int, Int, String) -> Void {
        return { route, index, total, desc in
            lock.lock(); defer { lock.unlock() }
            let fm = FileManager.default
            if index == 0 || folder == nil {
                let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"
                let dir = root.appendingPathComponent("\(f.string(from: Date()))-\(route)")
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                folder = dir
                let old = ((try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
                for u in old.dropLast(8) { try? fm.removeItem(at: u) }
            }
            guard let dir = folder, let shot = grab() else { return }
            _ = ScreenCapture.savePNG(shot, to: dir.appendingPathComponent(String(format: "%02d-%@.png", index, desc)))
        }
    }
}
