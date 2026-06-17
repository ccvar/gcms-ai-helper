import AppKit

// 把 SVG 渲染成 PNG，验证 macOS 能否正确读取该 SVG
let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: render_svg <in.svg> <out.png> [px]"); exit(1) }
let px = args.count >= 4 ? Int(args[3]) ?? 128 : 128
guard let img = NSImage(contentsOfFile: args[1]) else { print("FAILED to load SVG"); exit(1) }
print("loaded size: \(img.size)")
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2])")
