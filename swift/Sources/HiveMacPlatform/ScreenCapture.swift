import Foundation
import CoreGraphics
import ScreenCaptureKit
import ImageIO
import HiveMacCore

private final class Box<T>: @unchecked Sendable { var value: T?; init() {} }

/// Reads small screen regions with ScreenCaptureKit (needs the Screen Recording permission).
/// Rectangles are in points, the unit the window finder and the key output share. Each read
/// asks for exactly the pixels needed, never the whole screen.
/// Remembers the display list for a while. Plain synchronous locking, called from async code.
private final class DisplayCache: @unchecked Sendable {
    private var displays: [SCDisplay] = []
    private var ownApps: [SCRunningApplication] = []
    private var gameWindows: [SCWindow] = []
    private var fetchedAt = 0.0
    private let lock = NSLock()

    func isStale(now: Double) -> Bool { lock.lock(); defer { lock.unlock() }; return displays.isEmpty || now - fetchedAt > 2 }
    func store(_ d: [SCDisplay], own: [SCRunningApplication], game: [SCWindow], now: Double) { lock.lock(); displays = d; ownApps = own; gameWindows = game; fetchedAt = now; lock.unlock() }
    /// The Roblox window that contains the point, if any.
    func gameWindow(containing p: CGPoint) -> SCWindow? { lock.lock(); defer { lock.unlock() }; return gameWindows.first { $0.frame.contains(p) } }
    func own() -> [SCRunningApplication] { lock.lock(); defer { lock.unlock() }; return ownApps }
    func display(containing p: CGPoint) -> SCDisplay? {
        lock.lock(); defer { lock.unlock() }
        return displays.first { $0.frame.contains(p) } ?? displays.first
    }
}

public final class ScreenCapture: ScreenReading {
    private let cache = DisplayCache()
    public private(set) var lastCaptureSeconds = 0.0
    /// The reason the last picture could not be taken, for the log. nil when it worked.
    public private(set) var lastError: String?

    public init() {}

    /// Runs async work to completion from a plain background thread. Never call from the main thread.
    private func blocking<T>(_ body: @escaping @Sendable () async -> T?) -> T? {
        let sem = DispatchSemaphore(value: 0)
        let box = Box<T>()
        Task.detached { box.value = await body(); sem.signal() }
        sem.wait()
        return box.value
    }

    private func display(containing p: CGPoint) async -> SCDisplay? {
        let now = ProcessInfo.processInfo.systemUptime
        if cache.isStale(now: now),
           let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) {
            let me = Bundle.main.bundleIdentifier
            let game = content.windows.filter { $0.isOnScreen && $0.windowLayer == 0 && ($0.owningApplication?.bundleIdentifier ?? "").lowercased().contains("roblox") }
            cache.store(content.displays, own: content.applications.filter { $0.bundleIdentifier == me }, game: game, now: now)
        }
        return cache.display(containing: p)
    }

    private func capture(_ rect: CGRect) async -> CGImage? {
        guard let display = await display(containing: CGPoint(x: rect.midX, y: rect.midY)) else { lastError = "no display found for \(rect)"; return nil }
        let scale = max(1, CGFloat(display.width) / display.frame.width)       // pixels per point
        let config = SCStreamConfiguration()
        config.sourceRect = CGRect(x: rect.minX - display.frame.minX, y: rect.minY - display.frame.minY,
                                   width: rect.width, height: rect.height)
        config.width = max(1, Int((rect.width * scale).rounded()))
        config.height = max(1, Int((rect.height * scale).rounded()))
        config.showsCursor = false
        config.colorSpaceName = CGColorSpace.sRGB
        // Prefer the Roblox window itself: other windows (HiveMac, a terminal) can sit on top of the game,
        // and a window capture ignores them.
        if let win = cache.gameWindow(containing: CGPoint(x: rect.midX, y: rect.midY)) {
            let wc = SCStreamConfiguration()
            wc.sourceRect = CGRect(x: rect.minX - win.frame.minX, y: rect.minY - win.frame.minY, width: rect.width, height: rect.height)
            wc.width = max(1, Int((rect.width * scale).rounded()))
            wc.height = max(1, Int((rect.height * scale).rounded()))
            wc.showsCursor = false
            wc.colorSpaceName = CGColorSpace.sRGB
            do {
                let img = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: win), configuration: wc)
                lastError = nil
                return img
            } catch { lastError = "window capture: \(error)" }   // fall through to the screen capture below
        }
        // HiveMac's own window often sits on top of the game, so leave it out of the picture.
        let filter = SCContentFilter(display: display, excludingApplications: cache.own(), exceptingWindows: [])
        do {
            let img = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            lastError = nil
            return img
        } catch {
            lastError = "\(error)"
            return nil
        }
    }

    public static func rgb(from image: CGImage) -> RGBImage? {
        let w = image.width, h = image.height
        guard w > 0, h > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let ok = rgba.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        var rgb = [UInt8](); rgb.reserveCapacity(w * h * 3)
        for i in stride(from: 0, to: rgba.count, by: 4) { rgb.append(rgba[i]); rgb.append(rgba[i + 1]); rgb.append(rgba[i + 2]) }
        return RGBImage(width: w, height: h, pixels: rgb)
    }

    public func grab(_ region: WindowBounds) -> RGBImage? {
        let t0 = ProcessInfo.processInfo.systemUptime
        let rect = CGRect(x: region.left, y: region.top, width: region.width, height: region.height)
        let image = blocking { [self] in await capture(rect) }
        lastCaptureSeconds = ProcessInfo.processInfo.systemUptime - t0
        return image.flatMap(Self.rgb(from:))
    }

    public func pixel(x: Int, y: Int) -> (r: Int, g: Int, b: Int)? {
        guard let img = grab(WindowBounds(left: x, top: y, width: 1, height: 1)), img.width > 0 else { return nil }
        return img.pixel(img.width / 2, img.height / 2)
    }

    /// Loads a template PNG from disk as RGB.
    public static func loadPNG(_ url: URL) -> RGBImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return rgb(from: img)
    }

    /// Writes an RGB image as a PNG file.
    public static func savePNG(_ image: RGBImage, to url: URL) -> Bool {
        var rgba = [UInt8](); rgba.reserveCapacity(image.width * image.height * 4)
        for i in stride(from: 0, to: image.pixels.count, by: 3) { rgba += [image.pixels[i], image.pixels[i + 1], image.pixels[i + 2], 255] }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cg = CGImage(width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 32,
                               bytesPerRow: image.width * 4, space: space,
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        CGImageDestinationAddImage(dest, cg, nil)
        return CGImageDestinationFinalize(dest)
    }
}
