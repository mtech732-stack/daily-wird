// يحوّل كل PNG في مجلّد إلى نسخة رمادية بجانبه (name-gray.png) لفحص 8.3.
// الاستعمال: swift scripts/gray.swift <dir>
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
let ctx = CIContext()
let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "png" && !$0.lastPathComponent.hasSuffix("-gray.png") }
for url in files {
    guard let input = CIImage(contentsOf: url),
          let filter = CIFilter(name: "CIPhotoEffectMono") else { fatalError("تعذّر: \(url.path)") }
    filter.setValue(input, forKey: kCIInputImageKey)
    guard let output = filter.outputImage,
          let cg = ctx.createCGImage(output, from: input.extent) else { fatalError("تعذّر: \(url.path)") }
    let out = url.deletingPathExtension().appendingPathExtension("png")
        .deletingLastPathComponent()
        .appendingPathComponent(url.deletingPathExtension().lastPathComponent + "-gray.png")
    let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cg, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("تعذّر الحفظ: \(out.path)") }
    print("رمادي: \(out.lastPathComponent)")
}
