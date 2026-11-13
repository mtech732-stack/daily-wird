// يحوّل تسجيل المحاكي (mp4) إلى GIF صغير يُعرض في صفحة طلب الدمج على الهاتف (القرار 11)،
// لأن GitHub يعرض GIF داخل الصفحة ولا يعرض الفيديو.
// الاستعمال: swift scripts/video-to-gif.swift <in.mp4> <out.gif> [العرض=320] [الإطارات في الثانية=15]
import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else { print("الاستعمال: video-to-gif.swift in.mp4 out.gif [width] [fps]"); exit(2) }
let input = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2])
let width = args.count > 3 ? Double(args[3]) ?? 320 : 320
let fps = args.count > 4 ? Double(args[4]) ?? 15 : 15

let asset = AVURLAsset(url: input)
let sem = DispatchSemaphore(value: 0)
var duration = 0.0
Task {
    duration = (try? await asset.load(.duration).seconds) ?? 0
    sem.signal()
}
sem.wait()
guard duration > 0 else { print("مدّة الفيديو صفر: \(input.path)"); exit(1) }

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: width, height: width * 4)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

let count = Int(duration * fps)
guard let dest = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, count, nil) else { exit(1) }
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / fps]] as CFDictionary
var written = 0
for i in 0..<count {
    let time = CMTime(seconds: Double(i) / fps, preferredTimescale: 600)
    if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
        CGImageDestinationAddImage(dest, image, frameProps)
        written += 1
    }
}
guard CGImageDestinationFinalize(dest) else { print("تعذّر كتابة GIF"); exit(1) }
print("GIF: \(written) إطاراً من \(String(format: "%.1f", duration)) ث → \(output.path)")
