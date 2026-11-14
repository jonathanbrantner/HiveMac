import Foundation
import CoreGraphics
import Vision
import HiveMacCore

/// Reads the text printed in the Pollen bar ("23,763/140,827,431") with macOS's own text recognition,
/// so the backpack percent is an exact division instead of a guess from colours.
public enum BarText {
    public static func read(_ image: RGBImage) -> String? {
        guard image.width > 0, image.height > 0 else { return nil }
        // The grab is RGB; CoreGraphics wants a pixel stride of 4.
        var rgba = [UInt8](); rgba.reserveCapacity(image.width * image.height * 4)
        for i in stride(from: 0, to: image.pixels.count, by: 3) { rgba += [image.pixels[i], image.pixels[i + 1], image.pixels[i + 2], 255] }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cg = CGImage(width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 32,
                               bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        do { try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request]) } catch { return nil }
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    /// Every recognised line with its box (x, y, width, height as shares of the picture, y from the top).
    public static func readLines(_ image: RGBImage) -> [(text: String, box: CGRect)] {
        guard image.width > 0, image.height > 0 else { return [] }
        var rgba = [UInt8](); rgba.reserveCapacity(image.width * image.height * 4)
        for i in stride(from: 0, to: image.pixels.count, by: 3) { rgba += [image.pixels[i], image.pixels[i + 1], image.pixels[i + 2], 255] }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cg = CGImage(width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 32,
                               bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        do { try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request]) } catch { return [] }
        return (request.results ?? []).compactMap { o in
            guard let t = o.topCandidates(1).first?.string else { return nil }
            let b = o.boundingBox                                   // Vision: origin bottom left
            return (t, CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height))
        }
    }
}
